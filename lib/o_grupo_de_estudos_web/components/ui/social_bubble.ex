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
  import OGrupoDeEstudosWeb.UI.UserAvatar

  attr :current_user, :map, required: true
  attr :suggested_users, :list, default: []
  attr :following_user_ids, :any, default: MapSet.new()
  attr :bubble_open, :boolean, default: false
  attr :bubble_following_list, :list, default: []
  attr :bubble_search, :string, default: ""
  attr :bubble_search_results, :list, default: []
  attr :following_count, :integer, default: 0
  attr :followers_count, :integer, default: 0
  attr :bubble_tab, :string, default: "following"
  attr :bubble_followers_list, :list, default: []

  def social_bubble(assigns) do
    ~H"""
    <div
      data-ui="social-bubble"
      phx-click-away="close_bubble"
      class="fixed inset-0 z-[39] pointer-events-none"
    >
      <%!-- Panel --%>
      <div
        :if={@bubble_open}
        class="absolute bottom-[136px] md:bottom-[72px] right-3 z-50 bg-ink-50 rounded-2xl shadow-2xl border border-ink-300/40 w-72 flex flex-col overflow-hidden pointer-events-auto"
        style="animation: fadeSlideUp 0.15s ease-out; max-height: min(65vh, 420px);"
      >
        <%!-- Header --%>
        <div class="px-4 pt-3.5 pb-2.5 border-b border-ink-300/30 flex-shrink-0 bg-ink-100/60">
          <div class="flex items-center justify-between mb-2.5">
            <h3 class="text-sm font-bold text-ink-900 font-serif tracking-tight">Pessoas</h3>
            <div class="flex items-center gap-2.5 text-[11px] text-ink-500">
              <span><span class="font-bold text-ink-800">{@following_count}</span> seguindo</span>
              <span class="text-ink-300">&middot;</span>
              <span><span class="font-bold text-ink-800">{@followers_count}</span> seguidores</span>
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
              class="w-full pl-8 pr-3 py-1.5 bg-ink-50 border border-ink-200 rounded-lg text-xs text-ink-700 placeholder:text-ink-400 focus:outline-none focus:ring-2 focus:ring-accent-orange/30 font-serif"
            />
          </div>
        </div>

        <%!-- Scrollable content --%>
        <div class="flex-1 overflow-y-auto overscroll-contain min-h-0">
          <%!-- Search results (when searching) --%>
          <%= if @bubble_search != "" do %>
            <div class="px-3 py-2">
              <%= if @bubble_search_results == [] do %>
                <p class="text-xs text-ink-400 italic text-center py-4 font-serif">
                  Ninguem encontrado
                </p>
              <% else %>
                <div class="space-y-0.5">
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
            <%!-- Tab switcher --%>
            <div class="px-3 pt-2 flex gap-1 mb-1">
              <button
                type="button"
                phx-click="bubble_switch_tab"
                phx-value-tab="following"
                class={[
                  "text-[10px] font-bold py-1 px-2.5 rounded-full border cursor-pointer transition-colors",
                  @bubble_tab == "following" && "bg-accent-orange border-accent-orange text-white",
                  @bubble_tab != "following" &&
                    "bg-transparent border-ink-300 text-ink-500 hover:border-accent-orange"
                ]}
              >
                Seguindo
              </button>
              <button
                type="button"
                phx-click="bubble_switch_tab"
                phx-value-tab="followers"
                class={[
                  "text-[10px] font-bold py-1 px-2.5 rounded-full border cursor-pointer transition-colors",
                  @bubble_tab == "followers" && "bg-accent-orange border-accent-orange text-white",
                  @bubble_tab != "followers" &&
                    "bg-transparent border-ink-300 text-ink-500 hover:border-accent-orange"
                ]}
              >
                Seguidores
              </button>
            </div>

            <%!-- Following list --%>
            <%= if @bubble_tab == "following" && @bubble_following_list != [] do %>
              <div class="px-3 pt-1 pb-1">
                <div class="space-y-0">
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

            <%!-- Followers list --%>
            <%= if @bubble_tab == "followers" && @bubble_followers_list != [] do %>
              <div class="px-3 pt-1 pb-1">
                <div class="space-y-0">
                  <%= for person <- @bubble_followers_list do %>
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

            <%!-- Suggestions (following tab only) --%>
            <%= if @bubble_tab == "following" && @suggested_users != [] do %>
              <div class="px-3 pt-2 pb-2.5 border-t border-ink-300/25">
                <p class="text-[10px] font-bold text-ink-400 uppercase tracking-widest mb-1.5 font-sans">
                  Sugestoes para voce
                </p>
                <div class="space-y-0.5">
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

            <%!-- Empty state (following tab) --%>
            <%= if @bubble_tab == "following" && @bubble_following_list == [] && @suggested_users == [] do %>
              <div class="text-center py-8 px-4">
                <.icon name="hero-user-plus" class="w-6 h-6 text-ink-300 mx-auto mb-2" />
                <p class="text-xs text-ink-500 font-serif">
                  Comece seguindo alguem!
                </p>
              </div>
            <% end %>

            <%!-- Empty state (followers tab) --%>
            <%= if @bubble_tab == "followers" && @bubble_followers_list == [] do %>
              <div class="text-center py-8 px-4">
                <.icon name="hero-user-group" class="w-6 h-6 text-ink-300 mx-auto mb-2" />
                <p class="text-xs text-ink-500 font-serif">
                  Ninguem te segue ainda.
                </p>
              </div>
            <% end %>
          <% end %>
        </div>

        <%!-- Footer --%>
        <div class="px-3 py-2 border-t border-ink-300/25 flex-shrink-0 bg-ink-100/40">
          <.link
            navigate={~p"/users/#{@current_user.username}"}
            class="flex items-center justify-center gap-1.5 text-xs text-accent-orange font-semibold no-underline hover:text-accent-orange/80 font-serif"
          >
            <.icon name="hero-user-circle" class="w-3.5 h-3.5" /> Meu perfil
          </.link>
        </div>
      </div>

      <%!-- Bubble FAB --%>
      <button
        phx-click="toggle_bubble"
        class={[
          "absolute bottom-20 md:bottom-6 right-4 w-12 h-12 rounded-full flex items-center justify-center cursor-pointer border-0 shadow-lg transition-all pointer-events-auto",
          @bubble_open && "bg-ink-900 shadow-xl scale-95",
          !@bubble_open && "bg-ink-900 hover:bg-ink-800 shadow-ink-900/30"
        ]}
        style={if !@bubble_open, do: "animation: bubble-pulse 3s ease-in-out infinite;", else: ""}
      >
        <%= if @bubble_open do %>
          <.icon name="hero-x-mark" class="w-5 h-5 text-ink-200" />
        <% else %>
          <.icon name="hero-users" class="w-5 h-5 text-gold-500" />
        <% end %>
      </button>

      <style>
        @keyframes bubble-pulse {
          0%, 100% { transform: scale(1); }
          50% { transform: scale(1.05); }
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
      "flex items-center gap-2 rounded-lg transition-colors hover:bg-ink-100/80",
      @compact && "py-1 px-1.5",
      !@compact && "py-1.5 px-1.5"
    ]}>
      <.link
        navigate={~p"/users/#{@person.username}"}
        class="no-underline flex items-center gap-2 flex-1 min-w-0"
      >
        <.user_avatar user={@person} size={:sm} />
        <div class="flex-1 min-w-0">
          <p class={[
            "font-semibold text-ink-800 truncate font-serif",
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
