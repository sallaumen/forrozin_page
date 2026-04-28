defmodule OGrupoDeEstudosWeb.UI.BottomNav do
  @moduledoc """
  Mobile tab bar — fixed to bottom, 4 primary destinations.

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
      %{
        label: "Gerador",
        path: "/graph/visual?mode=generator",
        icon: "hero-sparkles",
        accent: true
      },
      %{label: "Sequências", path: "/community", icon: "hero-queue-list"},
      %{label: "Alertas", path: "/notifications", icon: "hero-bell"},
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
      <ul class="flex items-stretch h-14">
        <li :for={tab <- @tabs} class="flex-1 relative">
          <.link
            navigate={tab.path}
            data-active={active?(@current_path, tab.path)}
            class={[
              "flex flex-col items-center justify-center gap-0.5 h-full w-full no-underline font-sans",
              Map.get(tab, :accent) &&
                "text-accent-orange data-[active=true]:text-accent-orange",
              !Map.get(tab, :accent) && "text-ink-500 data-[active=true]:text-ink-900"
            ]}
          >
            <.icon name={tab.icon} class="size-6" />
            <span class="text-[10px] leading-none">{tab.label}</span>
          </.link>
          <span
            :if={tab.path == "/notifications" && @notification_count > 0}
            class={[
              "absolute top-1 right-1/4 min-w-[16px] h-4 px-0.5",
              "flex items-center justify-center",
              "bg-accent-red text-white text-[9px] font-bold rounded-full",
              "animate-notification-pop pointer-events-none"
            ]}
          >
            {if @notification_count > 99, do: "99+", else: @notification_count}
          </span>
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

  defp active?(current_path, tab_path) do
    to_string(current_path == tab_path or String.starts_with?(current_path, tab_path <> "/"))
  end
end
