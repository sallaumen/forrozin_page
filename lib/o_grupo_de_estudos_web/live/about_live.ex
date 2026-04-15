defmodule OGrupoDeEstudosWeb.AboutLive do
  use OGrupoDeEstudosWeb, :live_view

  on_mount {OGrupoDeEstudosWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Quem somos")}
  end
end
