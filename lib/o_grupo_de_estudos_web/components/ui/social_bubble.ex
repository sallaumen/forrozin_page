defmodule OGrupoDeEstudosWeb.UI.SocialBubble do
  @moduledoc """
  Floating social bubble (mobile only).

  Shows a persistent FAB in the bottom-right corner. When tapped, opens a
  popover with people suggestions. Closes on outside tap.

  Rendered on all authenticated pages via each LiveView template,
  positioned above the bottom nav.
  """

  use Phoenix.Component
  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.UI.InlineFollowButton

  attr :current_user, :map, required: true
  attr :suggested_users, :list, default: []
  attr :following_user_ids, :any, default: MapSet.new()
  attr :bubble_open, :boolean, default: false

  def social_bubble(assigns) do
    ~H"""
    <div data-ui="social-bubble" class="md:hidden" phx-click-away="close_bubble">
      <%!-- Popover --%>
      <div
        :if={@bubble_open}
        class="fixed bottom-[88px] right-4 z-50 bg-ink-50 rounded-xl shadow-xl border border-ink-200 w-56 overflow-hidden"
        style="animation: fadeSlideUp 0.15s ease-out;"
      >
        <%!-- Arrow --%>
        <div class="absolute -bottom-1.5 right-5 w-3 h-3 bg-ink-50 border-r border-b border-ink-200 rotate-45" />

        <div class="p-3">
          <p class="text-xs font-bold text-ink-700 mb-2.5">Seguir alguem?</p>

          <%= if @suggested_users == [] do %>
            <p class="text-xs text-ink-400 italic py-3 text-center">
              Voce ja segue todo mundo!
            </p>
          <% else %>
            <div class="space-y-2">
              <%= for person <- Enum.take(@suggested_users, 3) do %>
                <div class="flex items-center gap-2">
                  <.link
                    navigate={~p"/users/#{person.username}"}
                    class="no-underline flex items-center gap-2 flex-1 min-w-0"
                  >
                    <span class="inline-flex items-center justify-center w-7 h-7 rounded-full bg-ink-800 text-ink-200 text-[10px] font-bold flex-shrink-0">
                      {person.username |> String.upcase() |> String.first()}
                    </span>
                    <div class="flex-1 min-w-0">
                      <p class="text-xs font-semibold text-ink-800 truncate">
                        @{person.username}
                      </p>
                      <p :if={person.city} class="text-[10px] text-ink-400 truncate">
                        {person.city}
                      </p>
                    </div>
                  </.link>
                  <.inline_follow_button
                    target_user_id={person.id}
                    current_user_id={@current_user.id}
                    following_user_ids={@following_user_ids}
                  />
                </div>
              <% end %>
            </div>
          <% end %>

          <div class="border-t border-ink-200 mt-2.5 pt-2 text-center">
            <.link
              navigate={~p"/users/#{@current_user.username}"}
              class="text-xs text-accent-orange font-semibold no-underline"
            >
              Ver meu perfil
            </.link>
          </div>
        </div>
      </div>

      <%!-- Bubble FAB --%>
      <button
        phx-click="toggle_bubble"
        class={[
          "fixed bottom-20 right-4 z-40 w-12 h-12 rounded-full flex items-center justify-center cursor-pointer border-0 shadow-lg transition-all",
          @bubble_open && "bg-ink-700 shadow-xl scale-95",
          !@bubble_open && "bg-gradient-to-br from-accent-orange to-[#d35400] shadow-accent-orange/30"
        ]}
        style={if !@bubble_open, do: "animation: bubble-pulse 3s ease-in-out infinite;", else: ""}
      >
        <span class="text-lg">
          {if @bubble_open, do: "✕", else: "👥"}
        </span>
        <%= if !@bubble_open && length(@suggested_users) > 0 do %>
          <span class="absolute -top-0.5 -right-0.5 min-w-[16px] h-4 px-0.5 flex items-center justify-center bg-accent-red text-white text-[9px] font-bold rounded-full">
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
end
