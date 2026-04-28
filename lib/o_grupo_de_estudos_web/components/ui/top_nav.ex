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
  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  attr :current_user, :map, required: true
  attr :is_admin, :boolean, default: false
  attr :nav_mode, :atom, values: [:primary, :detail], default: :primary
  attr :title, :string, default: nil
  attr :notification_count, :integer, default: 0
  attr :notification_dropdown_enabled, :boolean, default: false
  attr :notification_dropdown_open, :boolean, default: false
  attr :notification_preview_groups, :list, default: []
  attr :pending_suggestions_count, :integer, default: 0
  attr :pending_study_count, :integer, default: 0
  attr :edit_action_enabled, :boolean, default: false
  attr :edit_action_event, :string, default: "toggle_edit_mode"
  attr :edit_mode, :boolean, default: false

  def top_nav(assigns) do
    ~H"""
    <header
      data-ui="top-nav"
      data-mode={@nav_mode}
      class="bg-ink-900 text-ink-100 sticky top-0 z-40 font-serif"
    >
      <%!-- Desktop layout (>=md): three-zone shell --%>
      <div
        id="top-nav-desktop-shell"
        class="hidden md:grid mx-auto w-full max-w-[1680px] grid-cols-[1fr_auto_1fr] items-center gap-6 px-6 py-3 lg:px-8 xl:px-10"
      >
        <nav id="top-nav-desktop-primary-nav" class="flex items-center gap-1.5 justify-self-start">
          <.link
            navigate={~p"/collection"}
            class="inline-flex min-h-9 items-center gap-1.5 rounded-full px-3 py-1.5 text-[13px] font-semibold text-ink-300 transition hover:bg-ink-100/5 hover:text-ink-50 no-underline"
          >
            <.icon name="hero-rectangle-stack" class="size-4" /> Acervo
          </.link>
          <.link
            navigate={~p"/graph/visual"}
            class="inline-flex min-h-9 items-center gap-1.5 rounded-full px-3 py-1.5 text-[13px] font-semibold text-ink-300 transition hover:bg-ink-100/5 hover:text-ink-50 no-underline"
          >
            <.icon name="hero-map" class="size-4" /> Mapa
          </.link>
          <div class="relative">
            <.link
              navigate={~p"/study"}
              class="inline-flex min-h-9 items-center gap-1.5 rounded-full px-3 py-1.5 text-[13px] font-semibold text-ink-300 transition hover:bg-ink-100/5 hover:text-ink-50 no-underline"
            >
              <.icon name="hero-book-open" class="size-4" /> Estudos
            </.link>
            <span
              :if={@pending_study_count > 0}
              class="absolute -top-1 -right-1 min-w-[16px] h-4 px-0.5 flex items-center justify-center bg-accent-red text-white text-[9px] font-bold rounded-full pointer-events-none"
            >
              {@pending_study_count}
            </span>
          </div>
          <.link
            navigate={~p"/community"}
            class="inline-flex min-h-9 items-center gap-1.5 rounded-full px-3 py-1.5 text-[13px] font-semibold text-ink-300 transition hover:bg-ink-100/5 hover:text-ink-50 no-underline"
          >
            <.icon name="hero-users" class="size-4" /> Comunidade
          </.link>
        </nav>

        <div id="top-nav-desktop-brand" class="justify-self-center">
          <.link
            navigate={~p"/collection"}
            class="text-sm font-bold tracking-[2.8px] uppercase text-ink-50 hover:text-ink-100 no-underline"
          >
            O Grupo de Estudos
          </.link>
        </div>

        <nav id="top-nav-desktop-actions" class="flex items-center gap-2 justify-self-end">
          <%= if @is_admin do %>
            <details id="top-nav-admin-menu" class="group relative">
              <summary
                id="top-nav-admin-trigger"
                class="flex min-h-9 cursor-pointer list-none items-center gap-1.5 rounded-full border border-ink-100/10 px-3 py-1.5 text-[12px] font-semibold text-ink-300 transition hover:border-ink-100/20 hover:bg-ink-100/5 hover:text-ink-50 [&::-webkit-details-marker]:hidden"
              >
                <span>Admin</span>
                <span
                  :if={@pending_suggestions_count > 0}
                  class="inline-flex min-w-[16px] items-center justify-center rounded-full bg-accent-orange px-1 py-0.5 text-[9px] font-bold text-white"
                >
                  {@pending_suggestions_count}
                </span>
                <.icon
                  name="hero-chevron-down"
                  class="size-3.5 transition group-open:rotate-180"
                />
              </summary>

              <div class="absolute right-0 top-[calc(100%+12px)] z-50 w-56 overflow-hidden rounded-md border border-ink-900/10 bg-ink-50 p-1.5 text-ink-900 shadow-[0_18px_45px_rgba(30,22,16,0.24)]">
                <.link
                  navigate={~p"/graph"}
                  class="flex items-center rounded px-3 py-2 text-sm font-medium text-ink-700 transition hover:bg-ink-100 no-underline"
                >
                  Conexões
                </.link>
                <.link
                  navigate={~p"/admin/links"}
                  class="flex items-center rounded px-3 py-2 text-sm font-medium text-ink-700 transition hover:bg-ink-100 no-underline"
                >
                  Links
                </.link>
                <.link
                  navigate={~p"/admin/backups"}
                  class="flex items-center rounded px-3 py-2 text-sm font-medium text-ink-700 transition hover:bg-ink-100 no-underline"
                >
                  Backups
                </.link>
                <.link
                  navigate={~p"/admin/suggestions"}
                  class="flex items-center justify-between rounded px-3 py-2 text-sm font-medium text-ink-700 transition hover:bg-ink-100 no-underline"
                >
                  <span>Sugestões</span>
                  <span
                    :if={@pending_suggestions_count > 0}
                    class="inline-flex min-w-[20px] items-center justify-center rounded-full bg-accent-orange px-1.5 py-0.5 text-[10px] font-bold text-white"
                  >
                    {@pending_suggestions_count}
                  </span>
                </.link>
                <.link
                  navigate={~p"/admin/errors"}
                  class="flex items-center rounded px-3 py-2 text-sm font-medium text-ink-700 transition hover:bg-ink-100 no-underline"
                >
                  Erros
                </.link>
              </div>
            </details>
          <% end %>

          <button
            :if={@edit_action_enabled}
            id="top-nav-edit-button"
            type="button"
            phx-click={@edit_action_event}
            aria-pressed={to_string(@edit_mode)}
            class={[
              "inline-flex min-h-9 items-center gap-1.5 rounded-full border px-3 py-1.5 font-serif text-[11px] font-semibold tracking-[0.5px] transition-colors",
              @edit_mode &&
                "border-accent-red/50 bg-accent-red/15 text-accent-red hover:bg-accent-red/20",
              !@edit_mode &&
                "border-ink-100/10 bg-transparent text-ink-400 hover:border-accent-orange/40 hover:text-ink-100"
            ]}
          >
            <.icon
              name={if @edit_mode, do: "hero-x-mark", else: "hero-pencil-square"}
              class="size-3.5"
            />
            <span>{if @edit_mode, do: "Sair edição", else: "Editar"}</span>
          </button>

          <span class="h-5 w-px bg-ink-100/10" />

          <%= if @notification_dropdown_enabled do %>
            <div class="relative">
              <button
                type="button"
                id="top-nav-notifications-button"
                phx-click="toggle_notifications_dropdown"
                aria-haspopup="dialog"
                aria-expanded={@notification_dropdown_open}
                class="relative group flex h-9 w-9 items-center justify-center rounded-full border border-transparent bg-transparent text-ink-400 transition hover:bg-ink-100/5 hover:text-ink-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent-orange/70"
              >
                <.icon
                  name="hero-bell-solid"
                  class={[
                    "size-5 transition-colors",
                    @notification_count > 0 && "text-accent-orange",
                    @notification_count == 0 && "text-ink-400 group-hover:text-ink-200"
                  ]}
                />
                <span
                  :if={@notification_count > 0}
                  class={[
                    "absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-0.5",
                    "flex items-center justify-center",
                    "bg-accent-red text-white text-[10px] font-bold rounded-full",
                    "animate-notification-pop"
                  ]}
                >
                  {if @notification_count > 99, do: "99+", else: @notification_count}
                </span>
              </button>

              <div
                :if={@notification_dropdown_open}
                id="top-nav-notifications-panel"
                phx-click-away="close_notifications_dropdown"
                class="absolute right-0 top-[calc(100%+10px)] z-50 w-[380px] max-w-[calc(100vw-2rem)] overflow-hidden rounded-md border border-ink-900/10 bg-ink-50 text-ink-900 shadow-[0_18px_45px_rgba(30,22,16,0.24)]"
                role="dialog"
                aria-label="Notificações"
              >
                <div class="flex items-center justify-between border-b border-ink-900/10 px-4 py-3">
                  <div>
                    <div class="text-sm font-bold text-ink-900">Notificações</div>
                    <div class="text-[11px] text-ink-500">Novas aparecem com ponto laranja.</div>
                  </div>
                  <.link
                    navigate={~p"/notifications"}
                    class="text-[11px] font-semibold text-accent-orange no-underline hover:text-accent-orange/80"
                  >
                    Abrir tudo
                  </.link>
                </div>

                <div class="max-h-[420px] overflow-y-auto">
                  <%= if @notification_preview_groups == [] do %>
                    <div class="px-4 py-8 text-center">
                      <.icon name="hero-bell" class="mx-auto mb-3 size-9 text-ink-300" />
                      <p class="m-0 text-sm font-semibold text-ink-700">
                        Nenhuma notificação ainda
                      </p>
                      <p class="mx-auto mt-1 max-w-[230px] text-xs leading-relaxed text-ink-500">
                        Quando alguém interagir com você, aparece aqui.
                      </p>
                    </div>
                  <% else %>
                    <.link
                      :for={notif <- @notification_preview_groups}
                      navigate={notification_path(notif)}
                      class={[
                        "flex items-start gap-3 border-b border-ink-900/[0.06] px-4 py-3 text-left no-underline transition last:border-b-0 hover:bg-accent-orange/[0.06]",
                        !notif.read && "bg-accent-orange/[0.04]"
                      ]}
                    >
                      <div class="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-ink-900 text-xs font-bold text-ink-50">
                        {notification_initial(notif)}
                      </div>
                      <div class="min-w-0 flex-1">
                        <p class="m-0 text-sm leading-snug text-ink-700">
                          <span class="font-bold text-ink-900">{primary_actor_name(notif)}</span>
                          <span :if={notif.count > 1} class="text-ink-500">
                            e mais {notif.count - 1}
                          </span>
                          <span>{action_text(notif)}</span>
                          <span
                            :if={target_name(notif)}
                            class="font-semibold text-accent-orange"
                          >
                            {target_name(notif)}
                          </span>
                        </p>
                        <p class="m-0 mt-1 text-[11px] text-ink-400">
                          {time_ago(notif.latest_at)}
                        </p>
                      </div>
                      <span
                        :if={!notif.read}
                        class="mt-2 h-2.5 w-2.5 shrink-0 rounded-full bg-accent-orange"
                      />
                    </.link>
                  <% end %>
                </div>
              </div>
            </div>
          <% else %>
            <.link navigate={~p"/notifications"} class="relative group no-underline">
              <.icon
                name="hero-bell-solid"
                class={[
                  "size-5 transition-colors",
                  @notification_count > 0 && "text-accent-orange",
                  @notification_count == 0 && "text-ink-400 group-hover:text-ink-200"
                ]}
              />
              <span
                :if={@notification_count > 0}
                class={[
                  "absolute -top-1.5 -right-1.5 min-w-[18px] h-[18px] px-0.5",
                  "flex items-center justify-center",
                  "bg-accent-red text-white text-[10px] font-bold rounded-full",
                  "animate-notification-pop"
                ]}
              >
                {if @notification_count > 99, do: "99+", else: @notification_count}
              </span>
            </.link>
          <% end %>

          <span class="h-5 w-px bg-ink-100/10"></span>

          <.link
            navigate={~p"/users/#{@current_user.username}"}
            class="inline-flex min-h-9 items-center rounded-full px-3 py-1.5 text-xs text-ink-100 tracking-[0.5px] transition hover:bg-ink-100/5 no-underline"
          >
            Olá, <strong>{OGrupoDeEstudos.Accounts.first_name(@current_user)}</strong>
          </.link>
          <.link
            navigate={~p"/settings"}
            class="inline-flex h-9 w-9 items-center justify-center rounded-full text-ink-400 transition hover:bg-ink-100/5 hover:text-ink-100 no-underline"
            title="Configurações"
            aria-label="Configurações"
          >
            <.icon name="hero-cog-6-tooth-solid" class="size-4.5" />
          </.link>
          <form method="post" action={~p"/logout"} class="m-0">
            <input type="hidden" name="_method" value="delete" />
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <button
              type="submit"
              class="inline-flex min-h-9 items-center rounded-full px-3 py-1.5 text-[11px] font-medium text-ink-500 transition hover:bg-ink-100/5 hover:text-ink-100 bg-transparent border-0 cursor-pointer"
            >
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
            O Grupo de Estudos
          </.link>
          <div class="flex items-center gap-2">
            <%= if @is_admin do %>
              <details id="top-nav-mobile-admin-menu" class="group relative">
                <summary class="flex items-center gap-1 cursor-pointer list-none text-xs font-semibold text-ink-400 [&::-webkit-details-marker]:hidden">
                  <span>Admin</span>
                  <span
                    :if={@pending_suggestions_count > 0}
                    class="inline-flex min-w-[16px] items-center justify-center rounded-full bg-accent-orange px-1 py-0.5 text-[9px] font-bold text-white"
                  >
                    {@pending_suggestions_count}
                  </span>
                  <.icon
                    name="hero-chevron-down"
                    class="size-3 transition group-open:rotate-180"
                  />
                </summary>
                <div class="absolute right-0 top-[calc(100%+8px)] z-50 w-48 overflow-hidden rounded-md border border-ink-900/10 bg-ink-50 p-1 text-ink-900 shadow-[0_12px_32px_rgba(30,22,16,0.2)]">
                  <.link
                    navigate={~p"/graph"}
                    class="flex items-center rounded px-3 py-2 text-xs font-medium text-ink-700 no-underline hover:bg-ink-100"
                  >
                    Conexões
                  </.link>
                  <.link
                    navigate={~p"/admin/links"}
                    class="flex items-center rounded px-3 py-2 text-xs font-medium text-ink-700 no-underline hover:bg-ink-100"
                  >
                    Links
                  </.link>
                  <.link
                    navigate={~p"/admin/backups"}
                    class="flex items-center rounded px-3 py-2 text-xs font-medium text-ink-700 no-underline hover:bg-ink-100"
                  >
                    Backups
                  </.link>
                  <.link
                    navigate={~p"/admin/suggestions"}
                    class="flex items-center justify-between rounded px-3 py-2 text-xs font-medium text-ink-700 no-underline hover:bg-ink-100"
                  >
                    <span>Sugestões</span>
                    <span
                      :if={@pending_suggestions_count > 0}
                      class="inline-flex min-w-[18px] items-center justify-center rounded-full bg-accent-orange px-1.5 py-0.5 text-[9px] font-bold text-white"
                    >
                      {@pending_suggestions_count}
                    </span>
                  </.link>
                  <.link
                    navigate={~p"/admin/errors"}
                    class="flex items-center rounded px-3 py-2 text-xs font-medium text-ink-700 no-underline hover:bg-ink-100"
                  >
                    Erros
                  </.link>
                </div>
              </details>
            <% end %>
            <.link
              navigate={~p"/settings"}
              class="inline-flex h-9 w-9 items-center justify-center rounded-full text-ink-400 no-underline"
              title="Configurações"
              aria-label="Configurações"
            >
              <.icon name="hero-cog-6-tooth-solid" class="size-4.5" />
            </.link>
            <form method="post" action={~p"/logout"} class="m-0">
              <input type="hidden" name="_method" value="delete" />
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
              <button
                type="submit"
                class="text-[11px] text-ink-600 bg-transparent border-0 cursor-pointer"
              >
                sair
              </button>
            </form>
          </div>
        <% end %>
      </div>
    </header>
    """
  end

  defp notification_initial(%{actors_data: [actor | _]}) do
    (actor.name || actor.username || "?")
    |> String.first()
    |> String.upcase()
  end

  defp notification_initial(_), do: "?"

  defp primary_actor_name(%{actors_data: [actor | _]}) do
    actor.name || actor.username || "Alguém"
  end

  defp primary_actor_name(_), do: "Alguém"

  defp notification_path(%{action: "followed_user", parent_type: "profile", parent_id: id}) do
    profile_path(id)
  end

  defp notification_path(%{parent_type: "study_link"}) do
    ~p"/study"
  end

  defp notification_path(%{parent_type: "step", parent_id: id}) do
    case OGrupoDeEstudos.Repo.get(OGrupoDeEstudos.Encyclopedia.Step, id) do
      nil -> ~p"/collection"
      step -> ~p"/steps/#{step.code}"
    end
  end

  defp notification_path(%{parent_type: "profile", parent_id: id}) do
    profile_path(id)
  end

  defp notification_path(%{parent_type: "sequence"}), do: ~p"/community"
  defp notification_path(_), do: ~p"/collection"

  defp profile_path(id) do
    case OGrupoDeEstudos.Repo.get(OGrupoDeEstudos.Accounts.User, id) do
      nil -> ~p"/collection"
      user -> ~p"/users/#{user.username}"
    end
  end

  defp target_name(%{parent_type: "step", parent_id: id}) when not is_nil(id) do
    case OGrupoDeEstudos.Repo.get(OGrupoDeEstudos.Encyclopedia.Step, id) do
      nil -> nil
      step -> step.name
    end
  end

  defp target_name(_), do: nil

  defp action_text(%{action: "followed_user"}), do: " começou a te seguir"
  defp action_text(%{action: "liked_comment"}), do: " curtiu seu comentário"
  defp action_text(%{action: "replied_comment"}), do: " respondeu ao seu comentário"
  defp action_text(%{action: "liked_step"}), do: " curtiu o passo "
  defp action_text(%{action: "liked_sequence"}), do: " curtiu a sequência"
  defp action_text(%{action: "suggestion_created"}), do: " enviou uma sugestão"
  defp action_text(%{action: "suggestion_approved"}), do: " aprovou sua sugestão"
  defp action_text(%{action: "suggestion_rejected"}), do: " rejeitou sua sugestão"
  defp action_text(%{action: "study_request"}), do: " quer estudar com você"
  defp action_text(%{action: "study_accepted"}), do: " aceitou seu pedido de estudo"
  defp action_text(_), do: " interagiu"

  defp time_ago(datetime) do
    diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "agora"
      diff < 3_600 -> "#{div(diff, 60)}min"
      diff < 86_400 -> "#{div(diff, 3_600)}h"
      diff < 604_800 -> "#{div(diff, 86_400)}d"
      true -> "#{div(diff, 604_800)}sem"
    end
  end
end
