defmodule ForrozinWeb.AdminBackupsLive do
  @moduledoc "Admin page to list, create, restore, and download database backups."

  use ForrozinWeb, :live_view

  alias Forrozin.Admin.Backup

  on_mount {ForrozinWeb.UserAuth, :ensure_admin}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin · Backups")
     |> assign(:is_admin, true)
     |> load_backups()}
  end

  @impl true
  def handle_event("create_backup", _params, socket) do
    Backup.create_backup!()

    {:noreply,
     socket
     |> put_flash(:info, "Backup criado com sucesso.")
     |> load_backups()}
  end

  def handle_event("restore_backup", %{"path" => path}, socket) do
    filename = Path.basename(path)

    if valid_backup_path?(path) do
      Backup.restore_backup!(path)

      {:noreply,
       socket
       |> put_flash(:info, "Backup \"#{filename}\" restaurado com sucesso.")}
    else
      {:noreply, put_flash(socket, :error, "Backup não encontrado ou caminho inválido.")}
    end
  end

  defp load_backups(socket) do
    backups =
      Backup.list_backups()
      |> Enum.map(&Backup.backup_info/1)
      |> Enum.reject(&is_nil/1)

    assign(socket, :backups, backups)
  end

  defp valid_backup_path?(path) do
    filename = Path.basename(path)
    String.ends_with?(filename, ".json") and File.exists?(path)
  end

  @doc "Formats bytes into a human-readable string (KB or MB)."
  def format_size(bytes) when bytes < 1_024, do: "#{bytes} B"
  def format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1_024, 1)} KB"
  def format_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  @doc "Formats a NaiveDateTime for display, or returns a fallback string."
  def format_timestamp(nil), do: "Data desconhecida"

  def format_timestamp(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y às %H:%M:%S")
  end
end
