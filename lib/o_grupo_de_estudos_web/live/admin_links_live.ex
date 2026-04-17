defmodule OGrupoDeEstudosWeb.AdminLinksLive do
  @moduledoc "Admin page to review, approve and delete step links."

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Admin}
  alias OGrupoDeEstudos.Encyclopedia.StepLinkQuery

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Navigation, :detail}

  import OGrupoDeEstudosWeb.UI.TopNav

  @impl true
  def mount(_params, _session, socket) do
    unless Accounts.admin?(socket.assigns.current_user) do
      {:ok, redirect(socket, to: ~p"/collection")}
    else
      {:ok,
       socket
       |> assign(:page_title, "Admin · Links")
       |> assign(:is_admin, true)
       |> load_links()}
    end
  end

  @impl true
  def handle_event("approve_link", %{"id" => id}, socket) do
    if not Accounts.admin?(socket.assigns.current_user) do
      {:noreply, socket}
    else
      link = StepLinkQuery.get_by(id: id, include_deleted: false)

      if link do
        {:ok, _} = Admin.approve_step_link(link)
        {:noreply, socket |> put_flash(:info, "Link aprovado.") |> load_links()}
      else
        {:noreply, put_flash(socket, :error, "Link não encontrado.")}
      end
    end
  end

  def handle_event("delete_link", %{"id" => id}, socket) do
    if not Accounts.admin?(socket.assigns.current_user) do
      {:noreply, socket}
    else
      link = StepLinkQuery.get_by(id: id, include_deleted: false)

      if link do
        {:ok, _} = Admin.delete_step_link(link)
        {:noreply, socket |> put_flash(:info, "Link removido.") |> load_links()}
      else
        {:noreply, put_flash(socket, :error, "Link não encontrado.")}
      end
    end
  end

  defp load_links(socket) do
    pending =
      StepLinkQuery.list_by(
        pending: true,
        preload: [:step, :submitted_by]
      )

    approved =
      StepLinkQuery.list_by(
        approved: true,
        preload: [:step, :submitted_by]
      )

    socket
    |> assign(:pending_links, pending)
    |> assign(:approved_links, approved)
  end
end
