defmodule OGrupoDeEstudosWeb.UI.SocialBubble do
  @moduledoc """
  Floating social panel.

  A persistent FAB that opens a rich social panel with:
  - Quick search to find people
  - List of users you follow (quick-access to profiles)
  - Smart suggestions (friends-of-friends, then city/activity fallback)

  Rendered on all authenticated pages. Mobile: above bottom nav.
  Desktop: bottom-right corner.
  """

  use Phoenix.Component
  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]
  import OGrupoDeEstudosWeb.UI.InlineFollowButton

  attr :current_user, :map, required: true
  attr :suggested_users, :list, default: []
  attr :following_user_ids, :any, default: MapSet.new()
  attr :bubble_open, :boolean, default: false
  attr :bubble_following_list, :list, default: []
  attr :bubble_search, :string, default: ""
  attr :bubble_search_results, :list, default: []
  attr :following_count, :integer, default: 0
  attr :followers_count, :integer, default: 0

  def social_bubble(assigns) do
    ~H"""
    <div data-ui="social-bubble" phx-click-away="close_bubble" class="fixed inset-0 z-[39] pointer-events-none">
      <%!-- Panel --%>
      <div
        :if={@bubble_open}
        class="absolute bottom-[88px] md:bottom-[72px] right-3 z-50 bg-ink-50 rounded-2xl shadow-2xl border border-ink-200 w-72 max-h-[70vh] flex flex-col overflow-hidden pointer-events-auto"
        style="animation: fadeSlideUp 0.15s ease-out;"
      >
        <%!-- Header --%>
        <div class="px-4 pt-3 pb-2 border-b border-ink-200/60 flex-shrink-0">
          <div class="flex items-center justify-between mb-2">
            <h3 class="text-sm font-bold text-ink-900 font-serif">Pessoas</h3>
            <div class="flex items-center gap-3 text-xs text-ink-500">
              <span><span class="font-bold text-ink-700">{@following_count}</span> seguindo</span>
              <span><span class="font-bold text-ink-700">{@followers_count}</span> seguidores</span>
            </div>
          </div>
          <%!-- Search --%>
          <div class="relative">
            <.icon
              name="hero-magnifying-glass"
              class="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-ink-400"
            />
            <input
              type="text"
              phx-keyup="bubble_search"
              phx-debounce="300"
              name="term"
              value={@bubble_search}
              placeholder="Buscar pessoas..."
              class="w-full pl-8 pr-3 py-1.5 bg-ink-100 border border-ink-200/60 rounded-lg text-xs text-ink-700 focus:outline-none focus:ring-2 focus:ring-accent-orange/30"
            />
          </div>
        </div>

        <%!-- Scrollable content --%>
        <div class="flex-1 overflow-y-auto overscroll-contain">
          <%!-- Search results (when searching) --%>
          <%= if @bubble_search != "" do %>
            <div class="px-3 py-2">
              <%= if @bubble_search_results == [] do %>
                <p class="text-xs text-ink-400 italic text-center py-4">
                  Ninguem encontrado
                </p>
              <% else %>
                <div class="space-y-1">
                  <%= for person <- @bubble_search_results do %>
                    <.person_row
                      person={person}
                      current_user={@current_user}
                      following_user_ids={@following_user_ids}
                    />
                  <% end %>
                </div>
              <% end %>
            </div>
          <% else %>
            <%!-- Following list --%>
            <%= if @bubble_following_list != [] do %>
              <div class="px-3 pt-2 pb-1">
                <p class="text-[10px] font-bold text-ink-400 uppercase tracking-wider mb-1.5">
                  Seguindo
                </p>
                <div class="space-y-0.5">
                  <%= for person <- @bubble_following_list do %>
                    <.person_row
                      person={person}
                      current_user={@current_user}
                      following_user_ids={@following_user_ids}
                      compact={true}
                    />
                  <% end %>
                </div>
              </div>
            <% end %>

            <%!-- Suggestions --%>
            <%= if @suggested_users != [] do %>
              <div class="px-3 pt-2 pb-2 border-t border-ink-200/40">
                <p class="text-[10px] font-bold text-ink-400 uppercase tracking-wider mb-1.5">
                  Sugestoes para voce
                </p>
                <div class="space-y-1">
                  <%= for person <- Enum.take(@suggested_users, 3) do %>
                    <.person_row
                      person={person}
                      current_user={@current_user}
                      following_user_ids={@following_user_ids}
                    />
                  <% end %>
                </div>
              </div>
            <% end %>

            <%!-- Empty state --%>
            <%= if @bubble_following_list == [] && @suggested_users == [] do %>
              <div class="text-center py-6 px-4">
                <p class="text-xs text-ink-400 italic">
                  Comece seguindo alguem!
                </p>
              </div>
            <% end %>
          <% end %>
        </div>

        <%!-- Footer --%>
        <div class="px-3 py-2 border-t border-ink-200/60 flex-shrink-0 bg-ink-100/50">
          <.link
            navigate={~p"/users/#{@current_user.username}"}
            class="flex items-center justify-center gap-1.5 text-xs text-accent-orange font-semibold no-underline hover:text-accent-orange/80"
          >
            <.icon name="hero-user-circle" class="w-3.5 h-3.5" />
            Meu perfil
          </.link>
        </div>
      </div>

      <%!-- Bubble FAB --%>
      <button
        phx-click="toggle_bubble"
        class={[
          "absolute bottom-20 md:bottom-6 right-4 w-12 h-12 rounded-full flex items-center justify-center cursor-pointer border-0 shadow-lg transition-all pointer-events-auto",
          @bubble_open && "bg-ink-700 shadow-xl scale-95",
          !@bubble_open && "bg-gradient-to-br from-accent-orange to-[#d35400] shadow-accent-orange/30"
        ]}
        style={if !@bubble_open, do: "animation: bubble-pulse 3s ease-in-out infinite;", else: ""}
      >
        <span class="text-lg">
          {if @bubble_open, do: "✕", else: "👥"}
        </span>
        <%= if !@bubble_open && length(@suggested_users) > 0 do %>
          <span class="absolute top-0 right-0 translate-x-1 -translate-y-1 min-w-[16px] h-4 px-0.5 flex items-center justify-center bg-accent-red text-white text-[9px] font-bold rounded-full pointer-events-none">
            {length(@suggested_users)}
          </span>
        <% end %>
      </button>

      <style>
        @keyframes bubble-pulse {
          0%, 100% { transform: scale(1); }
          50% { transform: scale(1.06); }
        }
        @keyframes fadeSlideUp {
          from { opacity: 0; transform: translateY(8px); }
          to { opacity: 1; transform: translateY(0); }
        }
      </style>
    </div>
    """
  end

  attr :person, :map, required: true
  attr :current_user, :map, required: true
  attr :following_user_ids, :any, required: true
  attr :compact, :boolean, default: false

  defp person_row(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-2 rounded-lg transition-colors hover:bg-ink-100",
      @compact && "py-1 px-1.5",
      !@compact && "py-1.5 px-1.5"
    ]}>
      <.link
        navigate={~p"/users/#{@person.username}"}
        class="no-underline flex items-center gap-2 flex-1 min-w-0"
      >
        <span class={[
          "inline-flex items-center justify-center rounded-full bg-ink-800 text-ink-200 font-bold flex-shrink-0",
          @compact && "w-6 h-6 text-[9px]",
          !@compact && "w-7 h-7 text-[10px]"
        ]}>
          {String.first(@person.username) |> String.upcase()}
        </span>
        <div class="flex-1 min-w-0">
          <p class={[
            "font-semibold text-ink-800 truncate",
            @compact && "text-[11px]",
            !@compact && "text-xs"
          ]}>
            @{@person.username}
          </p>
          <p :if={@person.city && !@compact} class="text-[10px] text-ink-400 truncate">
            {@person.city}
          </p>
        </div>
      </.link>
      <.inline_follow_button
        target_user_id={@person.id}
        current_user_id={@current_user.id}
        following_user_ids={@following_user_ids}
      />
    </div>
    """
  end
end
