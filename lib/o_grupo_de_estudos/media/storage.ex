defmodule OGrupoDeEstudos.Media.Storage do
  @moduledoc """
  Serviço de mídia: política de nomes + processamento de imagem.

  Os bytes moram atrás da porta `Media.ObjectStorage` (troca de provider
  acontece lá). Aqui mora o que NÃO muda quando o provider muda:

  - avatar tem o id no nome (com timestamp para furar cache) e a troca apaga
    a versão anterior;
  - flyer é redimensionado e ganha chave aleatória, nada previsível no nome;
  - arquivo privado ganha chave opaca e nunca vira URL pública.

  Mogrify (ImageMagick) processa imagem ANTES de guardar, com cópia crua como
  fallback quando o binário falta.
  """

  alias OGrupoDeEstudos.Media.ObjectStorage

  @avatar_size 400
  @flyer_max_width 1200
  @key_random_bytes 16

  @doc """
  Guarda o avatar quadrado (#{@avatar_size}px) e devolve a URL pública.

  Cada pessoa tem sua pasta (`avatars/<user_id>/`); o nome leva timestamp
  para o navegador não mostrar avatar velho de cache, e as versões
  anteriores da mesma pessoa vão embora junto.
  """
  @spec save_avatar(term(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def save_avatar(user_id, tmp_path, ext) do
    chave = "avatars/#{user_id}/#{System.system_time(:second)}#{ext}"

    with :ok <- processado(tmp_path, &quadrado/2, fn tmp -> ObjectStorage.put(chave, tmp) end) do
      limpar_avatares_antigos(user_id, chave)
      {:ok, ObjectStorage.public_url(chave)}
    end
  end

  defp limpar_avatares_antigos(user_id, chave_atual) do
    "avatars/#{user_id}/"
    |> ObjectStorage.list()
    |> Enum.reject(&(&1 == chave_atual))
    |> Enum.each(&ObjectStorage.delete/1)
  end

  @doc """
  Guarda uma imagem redimensionada com chave aleatória e devolve a URL.

  Nada previsível no nome: flyer é público, e nome adivinhável deixaria
  varrer o que os outros publicaram.
  """
  @spec save_image(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def save_image(subdir, tmp_path, ext) do
    chave = Path.join(subdir, "#{random_key()}#{ext}")

    with :ok <- processado(tmp_path, &limitado/2, fn tmp -> ObjectStorage.put(chave, tmp) end) do
      {:ok, ObjectStorage.public_url(chave)}
    end
  end

  @doc "Apaga uma imagem pela URL pública. Silencioso se já não existe."
  @spec delete_image(String.t()) :: :ok | {:error, term()}
  def delete_image("/uploads/" <> chave), do: ObjectStorage.delete(chave)
  def delete_image(_url_de_fora), do: :ok

  @doc """
  Guarda um arquivo cru em área privada e devolve a chave opaca.

  Não devolve URL de propósito: quem serve é um controller que confere
  permissão, via `serve_private/1`.
  """
  @spec put_private(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def put_private(subdir, tmp_path, ext) do
    chave = Path.join(subdir, "#{random_key()}#{ext}")

    case ObjectStorage.put(chave, tmp_path) do
      :ok -> {:ok, chave}
      erro -> erro
    end
  end

  @doc "Como servir um arquivo privado: `{:file, caminho}` ou `{:redirect, url}`."
  @spec serve_private(String.t()) ::
          {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}
  def serve_private(chave), do: ObjectStorage.serve(chave)

  @doc "Roda `fun` com um caminho local do arquivo privado (entrada de ffmpeg)."
  @spec with_private_file(String.t(), (String.t() -> result)) :: {:ok, result} | {:error, term()}
        when result: term()
  def with_private_file(chave, fun), do: ObjectStorage.with_local_file(chave, fun)

  @doc "Apaga um arquivo privado. Silencioso se já não existe."
  @spec delete_private(String.t()) :: :ok | {:error, term()}
  def delete_private(chave), do: ObjectStorage.delete(chave)

  @doc "Bytes livres no storage, ou `:unknown`."
  @spec free_bytes() :: non_neg_integer() | :unknown
  def free_bytes, do: ObjectStorage.free_bytes()

  # Processes into its own temporary file and hands it to `guardar`, cleaning up
  # afterwards: ObjectStorage only ever sees a finished file.
  defp processado(origem, transformar, guardar) do
    tmp = Path.join(System.tmp_dir!(), "media_#{System.unique_integer([:positive])}")

    try do
      case transformar.(origem, tmp) do
        :ok -> guardar.(tmp)
        erro -> erro
      end
    after
      File.rm(tmp)
    end
  end

  defp quadrado(origem, destino) do
    origem
    |> Mogrify.open()
    |> Mogrify.resize_to_fill("#{@avatar_size}x#{@avatar_size}")
    |> Mogrify.gravity("Center")
    |> Mogrify.save(path: destino)

    :ok
  rescue
    # Without ImageMagick, storing the raw image beats failing the upload.
    _e -> File.cp(origem, destino)
  end

  # A flyer is a poster: keep the aspect ratio and cap the width only. Without
  # this, a 4 MB phone photo stays 4 MB on the volume.
  defp limitado(origem, destino) do
    origem
    |> Mogrify.open()
    |> Mogrify.resize_to_limit("#{@flyer_max_width}x#{@flyer_max_width * 3}")
    |> Mogrify.save(path: destino)

    :ok
  rescue
    _e -> File.cp(origem, destino)
  end

  defp random_key do
    @key_random_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> String.replace(~r/[^A-Za-z0-9]/, "")
  end
end
