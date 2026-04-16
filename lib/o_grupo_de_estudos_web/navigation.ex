defmodule OGrupoDeEstudosWeb.Navigation do
  @moduledoc """
  LiveView `on_mount` hooks that classify pages as `:primary` or `:detail`
  and set `@nav_mode` accordingly.

  Primary pages are top-level destinations (Acervo, Mapa, Comunidade,
  Perfil próprio) — they show the bottom nav on mobile.

  Detail pages are drill-downs (step detail, settings, admin) — they hide
  the bottom nav and show a back button in the top nav on mobile.

  Usage:

      defmodule MyLive do
        use OGrupoDeEstudosWeb, :live_view
        on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
        # or
        on_mount {OGrupoDeEstudosWeb.Navigation, :detail}
      end

  For pages whose classification depends on params (e.g. user profile),
  set `@nav_mode` manually in `mount/3` — this on_mount is optional.
  """

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:primary, _params, _session, socket) do
    {:cont, assign(socket, :nav_mode, :primary)}
  end

  def on_mount(:detail, _params, _session, socket) do
    {:cont, assign(socket, :nav_mode, :detail)}
  end
end
