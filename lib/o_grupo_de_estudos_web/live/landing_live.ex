defmodule OGrupoDeEstudosWeb.LandingLive do
  @moduledoc "Página inicial pública do Grupo de Estudos."

  use OGrupoDeEstudosWeb, :live_view

  import OGrupoDeEstudosWeb.UI.PWAInstallBanner

  alias OGrupoDeEstudos.Encyclopedia

  on_mount {OGrupoDeEstudosWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_user] do
      {:ok, redirect(socket, to: ~p"/collection")}
    else
      total = Encyclopedia.count_public_steps()
      {:ok, assign(socket, page_title: "O grupo de estudos", total_steps: total)}
    end
  end

  @impl true
  def handle_event("pwa_already_installed", %{"message" => message}, socket) do
    {:noreply, put_flash(socket, :info, message)}
  end
end
