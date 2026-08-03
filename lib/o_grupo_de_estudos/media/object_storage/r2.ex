defmodule OGrupoDeEstudos.Media.ObjectStorage.R2 do
  @moduledoc """
  Adapter de `ObjectStorage.Behaviour` no Cloudflare R2 (API S3).

  Dois buckets, roteados pelo prefixo da chave:

  - **público** (`avatars/`, `flyers/`): objetos com URL estável no domínio
    público, que é o que fica gravado no banco;
  - **privado** (todo o resto, hoje `workshop_media/`): servido por URL
    assinada de vida curta, via `serve/1`.

  Upload e download são streaming por URL pré-assinada: vídeo de 200 MB não
  passa pela RAM da VM. `free_bytes/0` é `:unknown` de propósito: R2 não tem
  volume para encher, quem limita custo é a cota por workshop no contexto.

  Config (runtime): `account_id`, `access_key_id`, `secret_access_key`,
  `private_bucket`, `public_bucket`, `public_base_url` e, em teste,
  `req_options` para injetar o plug do Req.Test.
  """

  @behaviour OGrupoDeEstudos.Media.ObjectStorage.Behaviour

  @public_prefixes ["avatars/", "flyers/"]
  # 1 hora: o bastante para assistir um vídeo, curto demais para virar link
  # eterno repassado fora do site.
  @presign_expiry 3600

  @impl true
  def put(key, source_path) do
    if File.exists?(source_path),
      do: enviar(key, source_path),
      else: {:error, :enoent}
  end

  defp enviar(key, source_path) do
    key
    |> presign(:put)
    |> then(
      &Req.put(base_req(),
        url: &1,
        body: File.stream!(source_path, 65_536),
        headers: [
          {"content-type", MIME.from_path(key)},
          # Corpo em streaming sairia chunked, e o R2 recusa com 411: o
          # tamanho vai explícito, e o streaming continua.
          {"content-length", Integer.to_string(File.stat!(source_path).size)}
        ]
      )
    )
    |> como_resultado()
  end

  @impl true
  def delete(key) do
    key
    |> presign(:delete)
    |> then(&Req.delete(base_req(), url: &1))
    |> case do
      # 404 e silencioso como no disco: apagar o que nao existe nao e erro.
      {:ok, %{status: 404}} -> :ok
      outro -> como_resultado(outro)
    end
  end

  @impl true
  def exists?(key) do
    case Req.head(base_req(), url: presign(key, :head)) do
      {:ok, %{status: 200}} -> true
      _ausente_ou_erro -> false
    end
  end

  @impl true
  def list(prefix) do
    base_req()
    |> Req.get(
      url: "#{endpoint()}/#{bucket_for(prefix)}",
      params: ["list-type": 2, prefix: prefix],
      aws_sigv4: sigv4()
    )
    |> case do
      {:ok, %{status: 200, body: xml}} -> chaves_do_xml(xml)
      _erro_ou_vazio -> []
    end
  end

  @impl true
  def public_url(key), do: "#{config!(:public_base_url)}/#{key}"

  @doc """
  Redirect para URL assinada, sempre: conferir existência custaria um HEAD a
  cada visualização, e quem chama já achou a linha no banco.
  """
  @impl true
  def serve(key), do: {:redirect, presign(key, :get)}

  @impl true
  def with_local_file(key, fun) do
    tmp = Path.join(System.tmp_dir!(), "r2_#{System.unique_integer([:positive])}")

    try do
      baixar(key, tmp, fun)
    after
      File.rm(tmp)
    end
  end

  defp baixar(key, tmp, fun) do
    key
    |> presign(:get)
    |> then(&Req.get(base_req(), url: &1, into: File.stream!(tmp)))
    |> case do
      {:ok, %{status: 200}} -> {:ok, fun.(tmp)}
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:ok, %{status: status}} -> {:error, {status, :download}}
      {:error, motivo} -> {:error, motivo}
    end
  end

  @impl true
  def free_bytes, do: :unknown

  # ── Assinatura e configuração ────────────────────────────────────────

  defp presign(key, method) do
    ReqS3.presign_url(
      method: method,
      bucket: bucket_for(key),
      key: key,
      endpoint_url: endpoint(),
      region: "auto",
      access_key_id: config!(:access_key_id),
      secret_access_key: config!(:secret_access_key),
      expires: @presign_expiry
    )
  end

  defp sigv4 do
    [
      service: :s3,
      region: "auto",
      access_key_id: config!(:access_key_id),
      secret_access_key: config!(:secret_access_key)
    ]
  end

  defp bucket_for(key) do
    if String.starts_with?(key, @public_prefixes),
      do: config!(:public_bucket),
      else: config!(:private_bucket)
  end

  defp endpoint, do: "https://#{config!(:account_id)}.r2.cloudflarestorage.com"

  defp base_req do
    :o_grupo_de_estudos
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:req_options, [])
    |> Req.new()
  end

  defp config!(chave) do
    :o_grupo_de_estudos
    |> Application.get_env(__MODULE__, [])
    |> Keyword.fetch!(chave)
  end

  defp como_resultado({:ok, %{status: status}}) when status in 200..299, do: :ok
  defp como_resultado({:ok, %{status: status, body: body}}), do: {:error, {status, corta(body)}}
  defp como_resultado({:error, motivo}), do: {:error, motivo}

  defp corta(body) when is_binary(body), do: String.slice(body, 0, 300)
  defp corta(body), do: body

  # ── XML do ListObjectsV2 ─────────────────────────────────────────────

  # Só as <Key> interessam, e `disallow_entities` fecha a porta de XXE.
  # Parser próprio de propósito: o do req_s3 é @moduledoc false, API privada.
  defp chaves_do_xml(xml) do
    case :xmerl_sax_parser.stream(xml, [
           :disallow_entities,
           event_fun: &evento_sax/3,
           event_state: {:fora, []}
         ]) do
      {:ok, {_modo, chaves}, _resto} -> Enum.reverse(chaves)
      _xml_invalido -> []
    end
  end

  defp evento_sax({:startElement, _uri, ~c"Key", _qname, _attrs}, _loc, {:fora, chaves}),
    do: {{:dentro, []}, chaves}

  defp evento_sax({:characters, texto}, _loc, {{:dentro, acc}, chaves}),
    do: {{:dentro, [acc | texto]}, chaves}

  defp evento_sax({:endElement, _uri, ~c"Key", _qname}, _loc, {{:dentro, acc}, chaves}),
    do: {:fora, [IO.iodata_to_binary(acc) | chaves]}

  defp evento_sax(_evento, _loc, estado), do: estado
end
