defmodule OGrupoDeEstudos.Media.Storage do
  @moduledoc """
  Media service: naming policy plus image processing.

  The bytes live behind the `Media.ObjectStorage` port (swapping providers happens
  there). What lives here is what does NOT change when the provider changes:

  - an avatar carries the id in the name (with a timestamp to bust caches) and
    replacing it deletes the previous version;
  - a flyer is resized and gets a random key, nothing predictable in the name;
  - a private file gets an opaque key and never becomes a public URL.

  Mogrify (ImageMagick) processes the image BEFORE storing, with a raw copy as
  fallback when the binary is missing.
  """

  alias OGrupoDeEstudos.Media.ObjectStorage

  @avatar_size 400
  @flyer_max_width 1200
  @key_random_bytes 16

  @doc """
  Stores the square avatar (#{@avatar_size}px) and returns the public URL.

  Each person has their own folder (`avatars/<user_id>/`); the name carries a
  timestamp so the browser does not show a stale cached avatar, and the previous
  versions of that person go away with it.
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
  Stores a resized image under a random key and returns the URL.

  Nothing predictable in the name: a flyer is public, and a guessable name would
  let someone scan what others published.
  """
  @spec save_image(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def save_image(subdir, tmp_path, ext) do
    chave = Path.join(subdir, "#{random_key()}#{ext}")

    with :ok <- processado(tmp_path, &limitado/2, fn tmp -> ObjectStorage.put(chave, tmp) end) do
      {:ok, ObjectStorage.public_url(chave)}
    end
  end

  @doc "Deletes an image by public URL. Silent when it is already gone."
  @spec delete_image(String.t()) :: :ok | {:error, term()}
  def delete_image("/uploads/" <> chave), do: ObjectStorage.delete(chave)
  def delete_image(_url_de_fora), do: :ok

  @doc """
  Stores a raw file in the private area and returns the opaque key.

  It does not return a URL on purpose: what serves it is a controller that checks
  permission, through `serve_private/1`.
  """
  @spec put_private(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def put_private(subdir, tmp_path, ext) do
    chave = Path.join(subdir, "#{random_key()}#{ext}")

    case ObjectStorage.put(chave, tmp_path) do
      :ok -> {:ok, chave}
      erro -> erro
    end
  end

  @doc "How to serve a private file: `{:file, path}` or `{:redirect, url}`."
  @spec serve_private(String.t()) ::
          {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}
  def serve_private(chave), do: ObjectStorage.serve(chave)

  @doc "Runs `fun` with a local path of the private file (input for ffmpeg)."
  @spec with_private_file(String.t(), (String.t() -> result)) :: {:ok, result} | {:error, term()}
        when result: term()
  def with_private_file(chave, fun), do: ObjectStorage.with_local_file(chave, fun)

  @doc "Deletes a private file. Silent when it is already gone."
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
