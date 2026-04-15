defmodule OGrupoDeEstudosWeb.BackupController do
  @moduledoc """
  Controller for serving backup file downloads.

  Security: only `.json` files from the configured backup directory are served.
  Admin-only access is enforced by the router pipeline (`:ensure_admin` plug).
  """

  use OGrupoDeEstudosWeb, :controller

  alias OGrupoDeEstudos.Accounts

  @doc """
  Streams a backup file to the browser as a download.

  Rejects requests for files that do not exist or do not end with `.json`.
  """
  def download(conn, %{"filename" => filename}) do
    user = conn.assigns[:current_user]

    unless Accounts.admin?(user) do
      conn
      |> put_flash(:error, "Acesso negado.")
      |> redirect(to: ~p"/collection")
    else
      path = backup_path(filename)

      if valid_download?(path, filename) do
        send_download(conn, {:file, path}, filename: filename)
      else
        conn
        |> put_flash(:error, "Backup não encontrado.")
        |> redirect(to: ~p"/admin/backups")
      end
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
