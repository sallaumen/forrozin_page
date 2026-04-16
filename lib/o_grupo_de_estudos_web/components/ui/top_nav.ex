defmodule OGrupoDeEstudosWeb.UI.TopNav do
  @moduledoc """
  Top navigation bar, responsive with 3 layouts.

  Modes (via `:nav_mode`):
  - `:primary` — logo + horizontal nav links (desktop) / compact menu (mobile)
  - `:detail` — back button + optional title, no main links (mobile-focused)

  Desktop (>=md): always shows the full horizontal nav regardless of
  nav_mode — detail mode's "back button" layout is mobile-only.
  """

  use Phoenix.Component
  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.UI.BackButton, only: [back_button: 1]

  attr :current_user, :map, required: true
  attr :is_admin, :boolean, default: false
  attr :nav_mode, :atom, values: [:primary, :detail], default: :primary
  attr :title, :string, default: nil

  def top_nav(assigns) do
    ~H"""
    <header
      data-ui="top-nav"
      data-mode={@nav_mode}
      class="bg-ink-900 text-ink-100 sticky top-0 z-40 font-serif"
    >
      <%!-- Desktop layout (>=md): always full horizontal nav --%>
      <div class="hidden md:flex items-center justify-between px-6 py-3 max-w-7xl mx-auto">
        <.link
          navigate={~p"/collection"}
          class="text-sm font-bold tracking-[2px] uppercase text-ink-100 hover:text-ink-200 no-underline"
        >
          Forrózin
        </.link>

        <nav class="flex items-center gap-4">
          <.link navigate={~p"/collection"} class="text-xs text-ink-400 hover:text-ink-100 tracking-[0.5px] no-underline">
            Acervo
          </.link>
          <.link navigate={~p"/graph/visual"} class="text-xs text-ink-400 hover:text-ink-100 tracking-[0.5px] no-underline">
            Mapa
          </.link>
          <.link navigate={~p"/community"} class="text-xs text-ink-400 hover:text-ink-100 tracking-[0.5px] no-underline">
            Comunidade
          </.link>

          <%= if @is_admin do %>
            <.link navigate={~p"/graph"} class="text-[11px] text-ink-500 hover:text-ink-100 tracking-[0.5px] no-underline">
              Conexões
            </.link>
            <.link navigate={~p"/admin/links"} class="text-[11px] text-ink-500 hover:text-ink-100 tracking-[0.5px] no-underline">
              Links
            </.link>
            <.link navigate={~p"/admin/backups"} class="text-[11px] text-ink-500 hover:text-ink-100 tracking-[0.5px] no-underline">
              Backups
            </.link>
          <% end %>

          <span class="w-px h-4 bg-ink-100/15"></span>

          <.link
            navigate={~p"/users/#{@current_user.username}"}
            class="text-xs text-ink-100 tracking-[0.5px] no-underline"
          >
            Olá, <strong>{OGrupoDeEstudos.Accounts.first_name(@current_user)}</strong>
          </.link>
          <.link navigate={~p"/settings"} class="text-sm text-ink-400 no-underline" title="Configurações">
            ⚙
          </.link>
          <form method="post" action={~p"/logout"} class="m-0">
            <input type="hidden" name="_method" value="delete" />
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <button type="submit" class="text-[11px] text-ink-600 bg-transparent border-0 cursor-pointer">
              sair
            </button>
          </form>
        </nav>
      </div>

      <%!-- Mobile layout (<md): different based on nav_mode --%>
      <div class="md:hidden flex items-center justify-between px-4 py-2 min-h-[48px]">
        <%= if @nav_mode == :detail do %>
          <%!-- Detail: back button + title --%>
          <.back_button />
          <div class="flex-1 text-center px-2 text-sm font-bold truncate">
            {@title || ""}
          </div>
          <%!-- Spacer to balance the back button width --%>
          <div class="w-11"></div>
        <% else %>
          <%!-- Primary: logo + settings/logout menu --%>
          <.link
            navigate={~p"/collection"}
            class="text-sm font-bold tracking-[2px] uppercase text-ink-100 no-underline"
          >
            Forrózin
          </.link>
          <div class="flex items-center gap-2">
            <%= if @is_admin do %>
              <.link navigate={~p"/admin/links"} class="text-xs text-ink-400 no-underline">
                Links
              </.link>
              <.link navigate={~p"/admin/backups"} class="text-xs text-ink-400 no-underline">
                Backups
              </.link>
            <% end %>
            <.link navigate={~p"/settings"} class="text-base text-ink-400 no-underline" title="Configurações">
              ⚙
            </.link>
            <form method="post" action={~p"/logout"} class="m-0">
              <input type="hidden" name="_method" value="delete" />
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
              <button type="submit" class="text-[11px] text-ink-600 bg-transparent border-0 cursor-pointer">
                sair
              </button>
            </form>
          </div>
        <% end %>
      </div>
    </header>
    """
  end
end
