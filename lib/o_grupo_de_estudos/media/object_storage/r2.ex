defmodule OGrupoDeEstudos.Media.ObjectStorage.R2 do
  @moduledoc """
  `ObjectStorage.Behaviour` adapter on Cloudflare R2 (S3 API).

  Two buckets, routed by the key prefix:

  - **public** (`avatars/`, `flyers/`): objects with a stable URL on the public
    domain, which is what gets stored in the database;
  - **private** (everything else, today `workshop_media/`): served through a
    short-lived signed URL, via `serve/1`.

  Upload and download stream through a presigned URL: a 200 MB video does not go
  through the VM memory. `free_bytes/0` is `:unknown` on purpose: R2 has no volume
  to fill, and what limits cost is the per-workshop quota in the context.

  Runtime config: `account_id`, `access_key_id`, `secret_access_key`,
  `private_bucket`, `public_bucket`, `public_base_url` and, in test,
  `req_options` to inject the Req.Test plug.
  """

  @behaviour OGrupoDeEstudos.Media.ObjectStorage.Behaviour

  @public_prefixes ["avatars/", "flyers/"]
  # One hour: enough to watch a video, short enough not to become an eternal
  # link passed around outside the site.
  @presign_expiry 3600

  @impl true
  def put(key, source_path) do
    if File.exists?(source_path),
      do: upload(key, source_path),
      else: {:error, :enoent}
  end

  defp upload(key, source_path) do
    key
    |> presign(:put)
    |> then(
      &Req.put(base_req(),
        url: &1,
        body: File.stream!(source_path, 65_536),
        headers: [
          {"content-type", MIME.from_path(key)},
          # A streamed body would go out chunked and R2 rejects that with 411, so the
          # size goes explicit while the streaming stays.
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
      # 404 is silent as on disk: deleting what is not there is not an error.
      {:ok, %{status: 404}} -> :ok
      other -> como_resultado(other)
    end
  end

  @impl true
  def exists?(key) do
    case Req.head(base_req(), url: presign(key, :head)) do
      {:ok, %{status: 200}} -> true
      _missing_or_error -> false
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
      {:ok, %{status: 200, body: xml}} -> keys_from_xml(xml)
      _error_or_empty -> []
    end
  end

  @impl true
  def public_url(key), do: "#{config!(:public_base_url)}/#{key}"

  @doc """
  Redirect to a signed URL, always: checking existence would cost a HEAD on every
  view, and the caller already found the row in the database.
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
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def free_bytes, do: :unknown

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

  defp config!(key) do
    :o_grupo_de_estudos
    |> Application.get_env(__MODULE__, [])
    |> Keyword.fetch!(key)
  end

  defp como_resultado({:ok, %{status: status}}) when status in 200..299, do: :ok
  defp como_resultado({:ok, %{status: status, body: body}}), do: {:error, {status, corta(body)}}
  defp como_resultado({:error, reason}), do: {:error, reason}

  defp corta(body) when is_binary(body), do: String.slice(body, 0, 300)
  defp corta(body), do: body

  # Only the <Key> entries matter, and `disallow_entities` closes the XXE door.
  # Own parser on purpose: the req_s3 one is @moduledoc false, a private API.
  defp keys_from_xml(xml) do
    case :xmerl_sax_parser.stream(xml, [
           :disallow_entities,
           event_fun: &sax_event/3,
           event_state: {:fora, []}
         ]) do
      {:ok, {_modo, keys}, _resto} -> Enum.reverse(keys)
      _invalid_xml -> []
    end
  end

  defp sax_event({:startElement, _uri, ~c"Key", _qname, _attrs}, _loc, {:fora, keys}),
    do: {{:dentro, []}, keys}

  defp sax_event({:characters, text}, _loc, {{:dentro, acc}, keys}),
    do: {{:dentro, [acc | text]}, keys}

  defp sax_event({:endElement, _uri, ~c"Key", _qname}, _loc, {{:dentro, acc}, keys}),
    do: {:fora, [IO.iodata_to_binary(acc) | keys]}

  defp sax_event(_event, _loc, estado), do: estado
end
