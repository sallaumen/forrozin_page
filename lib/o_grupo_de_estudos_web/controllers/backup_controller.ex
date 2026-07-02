defmodule OGrupoDeEstudosWeb.BackupController do
  @moduledoc """
  Controller for serving backup file downloads.

  Security: admin-only access is enforced at the router boundary via the
  `require_admin` pipeline; only `.json` files from the configured backup
  directory are served, and the path is rebuilt with `Path.basename/1` to
  neutralize path traversal.
  """

  use OGrupoDeEstudosWeb, :controller

  @doc """
  Streams a backup file to the browser as a download.

  Rejects requests for files that do not exist or do not end with `.json`.
  """
  def download(conn, %{"filename" => filename}) do
    path = backup_path(filename)

    if valid_download?(path, filename) do
      send_download(conn, {:file, path}, filename: filename)
    else
      conn
      |> put_flash(:error, "Backup não encontrado.")
      |> redirect(to: ~p"/admin/backups")
    end
  end

  defp valid_download?(path, filename) do
    String.ends_with?(filename, ".json") and File.exists?(path)
  end

  defp backup_path(filename) do
    dir = Path.join([Application.app_dir(:o_grupo_de_estudos, "priv"), "backups"])
    Path.join(dir, Path.basename(filename))
  end
end
