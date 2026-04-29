defmodule OGrupoDeEstudosWeb.AboutLive do
  @moduledoc false
  use OGrupoDeEstudosWeb, :live_view

  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  on_mount {OGrupoDeEstudosWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    total = OGrupoDeEstudos.Encyclopedia.count_public_steps()

    {:ok,
     assign(socket,
       page_title: "Quem somos",
       total_steps: total
     )}
  end
end
