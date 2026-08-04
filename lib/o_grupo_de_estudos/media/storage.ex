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
  # The square the link preview points at. Same width as the flyer cap, so the
  # crop never upscales.
  @og_size 1200
  @key_random_bytes 16

  @doc """
  Stores the square avatar (#{@avatar_size}px) and returns the public URL.

  Each person has their own folder (`avatars/<user_id>/`); the name carries a
  timestamp so the browser does not show a stale cached avatar, and the previous
  versions of that person go away with it.
  """
  @spec save_avatar(term(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def save_avatar(user_id, tmp_path, ext) do
    key = "avatars/#{user_id}/#{System.system_time(:second)}#{ext}"

    with :ok <-
           processado(tmp_path, &quadrado(&1, &2, @avatar_size), fn tmp ->
             ObjectStorage.put(key, tmp)
           end) do
      delete_old_avatars(user_id, key)
      {:ok, ObjectStorage.public_url(key)}
    end
  end

  defp delete_old_avatars(user_id, current_key) do
    "avatars/#{user_id}/"
    |> ObjectStorage.list()
    |> Enum.reject(&(&1 == current_key))
    |> Enum.each(&ObjectStorage.delete/1)
  end

  @doc """
  Stores a resized image under a random key and returns the URL.

  Nothing predictable in the name: a flyer is public, and a guessable name would
  let someone scan what others published.
  """
  @spec save_image(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def save_image(subdir, tmp_path, ext) do
    key = Path.join(subdir, "#{random_key()}#{ext}")

    with :ok <- processado(tmp_path, &limitado/2, fn tmp -> ObjectStorage.put(key, tmp) end) do
      {:ok, ObjectStorage.public_url(key)}
    end
  end

  @doc "Deletes an image by public URL, and the square derivative that shadows it."
  @spec delete_image(String.t()) :: :ok | {:error, term()}
  def delete_image("/uploads/" <> key) do
    if String.starts_with?(key, "flyers/"), do: ObjectStorage.delete(og_key(key))
    ObjectStorage.delete(key)
  end

  def delete_image(_url_de_fora), do: :ok

  @doc """
  Serves the square #{@og_size}px cut of a stored image, for the link preview.

  The derivative is cut once and cached in the storage under a deterministic key,
  so the messenger crawler pays the crop on the first share only. When the cut
  cannot be made (original gone, ImageMagick missing), the original answers: a
  rectangular preview beats a broken one.
  """
  @spec serve_og_square(String.t()) ::
          {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}
  def serve_og_square("/uploads/" <> key) do
    og = og_key(key)

    case ensure_og_square(key, og) do
      :ok -> ObjectStorage.serve(og)
      _generation_failed -> ObjectStorage.serve(key)
    end
  end

  def serve_og_square(_url_de_fora), do: {:error, :not_found}

  defp ensure_og_square(key, og) do
    if ObjectStorage.exists?(og), do: :ok, else: cut_og_square(key, og)
  end

  defp cut_og_square(key, og) do
    case ObjectStorage.with_local_file(key, &store_og_square(&1, og)) do
      {:ok, :ok} -> :ok
      other -> other
    end
  end

  defp store_og_square(source, og) do
    processado(source, &quadrado(&1, &2, @og_size), fn tmp -> ObjectStorage.put(og, tmp) end)
  end

  # Deterministic and flat: the flyer key is already random, so the derivative
  # inherits the unguessability, and replacing the flyer changes both keys.
  defp og_key(key) do
    "flyers/og/" <> (key |> String.replace_prefix("flyers/", "") |> String.replace("/", "-"))
  end

  @doc """
  Stores a raw file in the private area and returns the opaque key.

  It does not return a URL on purpose: what serves it is a controller that checks
  permission, through `serve_private/1`.
  """
  @spec put_private(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def put_private(subdir, tmp_path, ext) do
    key = Path.join(subdir, "#{random_key()}#{ext}")

    case ObjectStorage.put(key, tmp_path) do
      :ok -> {:ok, key}
      error -> error
    end
  end

  @doc "How to serve a private file: `{:file, path}` or `{:redirect, url}`."
  @spec serve_private(String.t()) ::
          {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}
  def serve_private(key), do: ObjectStorage.serve(key)

  @doc "Runs `fun` with a local path of the private file (input for ffmpeg)."
  @spec with_private_file(String.t(), (String.t() -> result)) :: {:ok, result} | {:error, term()}
        when result: term()
  def with_private_file(key, fun), do: ObjectStorage.with_local_file(key, fun)

  @doc "Deletes a private file. Silent when it is already gone."
  @spec delete_private(String.t()) :: :ok | {:error, term()}
  def delete_private(key), do: ObjectStorage.delete(key)

  @doc "Bytes livres no storage, ou `:unknown`."
  @spec free_bytes() :: non_neg_integer() | :unknown
  def free_bytes, do: ObjectStorage.free_bytes()

  # Processes into its own temporary file and hands it to `store`, cleaning up
  # afterwards: ObjectStorage only ever sees a finished file.
  defp processado(source, transformar, store) do
    tmp = Path.join(System.tmp_dir!(), "media_#{System.unique_integer([:positive])}")

    try do
      case transformar.(source, tmp) do
        :ok -> store.(tmp)
        error -> error
      end
    after
      File.rm(tmp)
    end
  end

  defp quadrado(source, dest, size) do
    source
    |> Mogrify.open()
    |> Mogrify.resize_to_fill("#{size}x#{size}")
    |> Mogrify.gravity("Center")
    |> Mogrify.save(path: dest)

    :ok
  rescue
    # Without ImageMagick, storing the raw image beats failing the upload.
    _e -> File.cp(source, dest)
  end

  # A flyer is a poster: keep the aspect ratio and cap the width only. Without
  # this, a 4 MB phone photo stays 4 MB on the volume.
  defp limitado(source, dest) do
    source
    |> Mogrify.open()
    |> Mogrify.resize_to_limit("#{@flyer_max_width}x#{@flyer_max_width * 3}")
    |> Mogrify.save(path: dest)

    :ok
  rescue
    _e -> File.cp(source, dest)
  end

  defp random_key do
    @key_random_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> String.replace(~r/[^A-Za-z0-9]/, "")
  end
end
