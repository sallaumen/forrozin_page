defmodule OGrupoDeEstudosWeb.UI.BottomNav do
  @moduledoc """
  Mobile tab bar: fixed to bottom, five primary destinations.

  Five is the ceiling both Apple and Material set, and it is not arbitrary: at
  375px seven tabs give each one 53px with a 10px label, and the label is what
  makes a tab bar learnable. Two of the seven were not places anyway. "Gerador"
  was `/graph/visual?mode=generator`, a mode of the map, and the map's own panel
  already opens on it; notifications are a check-in, so the bell went to the top
  bar, where it already was on desktop.

  Only renders visually on `md` and below (hidden on desktop via CSS).
  Active tab is determined by comparing `@current_path` prefix to each
  tab's base path.

  Height: 56px + env(safe-area-inset-bottom) (respects iPhone home bar).

  Also renders the PWA install banner (above the tab bar on mobile,
  at the very bottom on desktop) so it appears on all authenticated pages
  without duplicating the call in every LiveView template.
  """

  use Phoenix.Component
  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  attr :current_user, :map, required: true
  attr :current_path, :string, required: true
  attr :notification_count, :integer, default: 0
  attr :pending_study_count, :integer, default: 0

  def bottom_nav(assigns) do
    tabs = [
      %{label: "Acervo", path: "/collection", icon: "hero-rectangle-stack"},
      %{label: "Mapa", path: "/graph/visual", icon: "hero-map"},
      %{label: "Estudos", path: "/study", icon: "hero-book-open"},
      %{label: "Sequências", path: "/sequence", icon: "hero-queue-list"},
      %{
        label: "Perfil",
        path: "/users/#{assigns.current_user.username}",
        icon: "hero-user-circle"
      }
    ]

    assigns = assign(assigns, :tabs, tabs)

    ~H"""
    <nav
      data-ui="bottom-nav"
      class={[
        "md:hidden fixed bottom-0 left-0 right-0 z-40",
        "bg-ink-50 border-t border-ink-200",
        "pb-[env(safe-area-inset-bottom)]"
      ]}
    >
      <ul class="flex w-full items-stretch h-14">
        <li :for={tab <- @tabs} class="flex-1 min-w-0 relative">
          <.link
            navigate={tab.path}
            data-active={active?(@current_path, tab.path)}
            class={[
              "flex flex-col items-center justify-center gap-0.5 h-full w-full no-underline font-sans",
              "text-ink-500 data-[active=true]:text-ink-900"
            ]}
          >
            <.icon name={tab.icon} class="size-6" />
            <span class="text-[10px] leading-none">{tab.label}</span>
          </.link>
          <span
            :if={tab.path == "/study" && @pending_study_count > 0}
            class={[
              "absolute top-1 right-1/4 min-w-[16px] h-4 px-0.5",
              "flex items-center justify-center",
              "bg-accent-red text-white text-[9px] font-bold rounded-full",
              "animate-notification-pop pointer-events-none"
            ]}
          >
            {@pending_study_count}
          </span>
        </li>
      </ul>
    </nav>
    """
  end

  # A query string is a mode of a place, not another place: com o gerador aberto
  # a aba do Mapa continua acesa, que é a resposta certa para "onde eu estou?".
  defp active?(current_path, tab_path) do
    path = current_path |> String.split("?") |> hd()

    to_string(path == tab_path or String.starts_with?(path, tab_path <> "/"))
  end
end
