defmodule OGrupoDeEstudos.Media.Storage do
  @moduledoc """
  Centralized file storage for user-uploaded media.

  Abstracts the filesystem so callers never deal with paths directly.
  In production, files live on a Fly.io persistent volume (`/app/uploads`).
  In development, files live at `priv/static/uploads`.

  ## Usage

      Storage.save_avatar(user_id, tmp_path, ".jpg")
      #=> {:ok, "/uploads/avatars/abc123.jpg"}

      Storage.delete_avatar(user_id, ".jpg")
      #=> :ok

      Storage.avatar_exists?(user_id, ".jpg")
      #=> true
  """

  @avatar_size 400

  # ── Public API ─────────────────────────────────────────────────────────

  @doc """
  Saves an avatar image, cropping it to a square and resizing to #{@avatar_size}x#{@avatar_size}.
  Returns `{:ok, public_url}` or `{:error, reason}`.
  """
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
  def delete_avatar(user_id, ext) do
    path = Path.join(dir("avatars"), "#{user_id}#{ext}")

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      error -> error
    end
  end

  @doc "Returns true if the avatar file exists on disk."
  def avatar_exists?(user_id, ext) do
    Path.join(dir("avatars"), "#{user_id}#{ext}")
    |> File.exists?()
  end

  @doc "Returns the base uploads directory for a given subdirectory."
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
    e -> {:error, Exception.message(e)}
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
