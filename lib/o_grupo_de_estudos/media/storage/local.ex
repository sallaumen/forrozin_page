defmodule OGrupoDeEstudos.Media.Storage.Local do
  @moduledoc """
  Local filesystem adapter for `OGrupoDeEstudos.Media.Storage.Behaviour`.

  In production, files live on a Fly.io persistent volume (`/app/uploads`).
  In development, files live at `priv/static/uploads`. Avatars are cropped to a
  square and resized via Mogrify (ImageMagick), with a raw-copy fallback.
  """

  @behaviour OGrupoDeEstudos.Media.Storage.Behaviour

  @avatar_size 400

  @doc """
  Saves an avatar image, cropping it to a square and resizing to #{@avatar_size}x#{@avatar_size}.
  Returns `{:ok, public_url}` or `{:error, reason}`.
  """
  @impl true
  def save_avatar(user_id, tmp_path, ext) do
    dest_dir = dir("avatars")
    File.mkdir_p!(dest_dir)
    # Include timestamp to bust browser cache when avatar changes
    ts = System.system_time(:second)
    filename = "#{user_id}_#{ts}#{ext}"
    dest = Path.join(dest_dir, filename)

    with :ok <- crop_square_and_resize(tmp_path, dest) do
      # Clean up old avatars for this user (different timestamps)
      cleanup_old_avatars(dest_dir, user_id, filename)
      {:ok, "/uploads/avatars/#{filename}"}
    end
  end

  defp cleanup_old_avatars(dir, user_id, current_filename) do
    case File.ls(dir) do
      {:ok, files} ->
        prefix = "#{user_id}_"

        files
        |> Enum.filter(&(String.starts_with?(&1, prefix) and &1 != current_filename))
        |> Enum.each(&File.rm(Path.join(dir, &1)))

      _ ->
        :ok
    end
  end

  @doc "Deletes an avatar file if it exists."
  @impl true
  def delete_avatar(user_id, ext) do
    path = Path.join(dir("avatars"), "#{user_id}#{ext}")

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      error -> error
    end
  end

  @doc "Returns true if the avatar file exists on disk."
  @impl true
  def avatar_exists?(user_id, ext) do
    Path.join(dir("avatars"), "#{user_id}#{ext}")
    |> File.exists?()
  end

  @flyer_max_width 1200
  @key_random_bytes 16

  @doc """
  Guarda uma imagem redimensionada, com nome aleatorio.

  Diferente do avatar, a chave nao carrega id nenhum: um flyer e publico, e
  nome previsivel deixaria varrer o que os outros publicaram.
  """
  @impl true
  def save_image(subdir, tmp_path, ext) do
    dest_dir = dir(subdir)
    File.mkdir_p!(dest_dir)
    filename = "#{random_key()}#{ext}"
    dest = Path.join(dest_dir, filename)

    with :ok <- resize_to_width(tmp_path, dest) do
      {:ok, "/uploads/#{subdir}/#{filename}"}
    end
  end

  @doc "Apaga uma imagem pela URL publica."
  @impl true
  def delete_image("/uploads/" <> relative) do
    caminho = Path.join(base_path(), relative)

    case File.rm(caminho) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      error -> error
    end
  end

  def delete_image(_outra_coisa), do: :ok

  defp random_key do
    @key_random_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> String.replace(~r/[^A-Za-z0-9]/, "")
  end

  # Flyer e cartaz: mantem a proporcao e so limita a largura. Sem isso, uma
  # foto de celular de 4 MB vira 4 MB no volume.
  defp resize_to_width(source, dest) do
    source
    |> Mogrify.open()
    |> Mogrify.resize_to_limit("#{@flyer_max_width}x#{@flyer_max_width * 3}")
    |> Mogrify.save(path: dest)

    :ok
  rescue
    _e ->
      case File.cp(source, dest) do
        :ok -> :ok
        error -> error
      end
  end

  @doc "Returns the base uploads directory for a given subdirectory."
  @impl true
  def dir(subdir) do
    Path.join(base_path(), subdir)
  end

  # ── Image Processing ───────────────────────────────────────────────────

  defp crop_square_and_resize(source, dest) do
    source
    |> Mogrify.open()
    |> Mogrify.resize_to_fill("#{@avatar_size}x#{@avatar_size}")
    |> Mogrify.gravity("Center")
    |> Mogrify.save(path: dest)

    :ok
  rescue
    _e ->
      # Mogrify/ImageMagick failed — fallback to raw copy (no resize)
      case File.cp(source, dest) do
        :ok -> :ok
        error -> error
      end
  end

  # ── Path Resolution ────────────────────────────────────────────────────

  defp base_path do
    Application.get_env(:o_grupo_de_estudos, :uploads_path, default_path())
  end

  defp default_path do
    if File.dir?("/app/uploads"),
      do: "/app/uploads",
      else: Path.join(:code.priv_dir(:o_grupo_de_estudos), "static/uploads")
  end
end
