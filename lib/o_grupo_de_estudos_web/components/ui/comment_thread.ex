defmodule OGrupoDeEstudosWeb.UI.CommentThread do
  @moduledoc """
  Instagram-style comment thread component.

  Renders a list of root comments with optional replies indented below each
  parent. Handles soft-deleted comments (tombstone), inline reply forms, and a
  new-comment form at the bottom.

  All interactive events are delegated to the parent LiveView — the component
  only emits phx-click / phx-submit bindings; it owns no state.

  ## Comment ownership
  StepComment and SequenceComment associate via `:user` / `user_id`.
  ProfileComment associates via `:author` / `author_id`.
  The helpers `get_user/1` and `get_user_id/1` abstract this difference.
  """

  use Phoenix.Component

  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  # ---------------------------------------------------------------------------
  # Attrs
  # ---------------------------------------------------------------------------

  attr :comments, :list, required: true
  attr :current_user, :map, required: true
  attr :likes_map, :map, required: true
  attr :comment_type, :string, required: true
  attr :parent_id, :string, required: true
  attr :replying_to, :string, default: nil
  attr :replies_map, :map, default: %{}
  attr :is_admin, :boolean, default: false

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def comment_thread(assigns) do
    ~H"""
    <div data-ui="comment-thread" class="space-y-4">
      <%= for comment <- @comments do %>
        <.root_comment
          comment={comment}
          current_user={@current_user}
          likes_map={@likes_map}
          comment_type={@comment_type}
          replying_to={@replying_to}
          replies={Map.get(@replies_map, comment.id, [])}
          is_admin={@is_admin}
        />
      <% end %>

      <.new_comment_form />
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Private sub-components
  # ---------------------------------------------------------------------------

  attr :comment, :map, required: true
  attr :current_user, :map, required: true
  attr :likes_map, :map, required: true
  attr :comment_type, :string, required: true
  attr :replying_to, :string, required: true
  attr :replies, :list, required: true
  attr :is_admin, :boolean, required: true

  defp root_comment(assigns) do
    ~H"""
    <div class="space-y-2">
      <.comment_row
        comment={@comment}
        current_user={@current_user}
        likes_map={@likes_map}
        comment_type={@comment_type}
        is_admin={@is_admin}
        size={:root}
      />

      <%!-- Inline reply form — shown when this comment is being replied to --%>
      <div :if={@replying_to == to_string(@comment.id)} class="ml-10">
        <.reply_form parent_id={to_string(@comment.id)} />
      </div>

      <%!-- Replies indented below the root comment --%>
      <div :if={@replies != []} class="ml-10 border-l-2 border-ink-100 pl-3 space-y-2">
        <%= for reply <- @replies do %>
          <.comment_row
            comment={reply}
            current_user={@current_user}
            likes_map={@likes_map}
            comment_type={@comment_type}
            is_admin={@is_admin}
            size={:reply}
          />
        <% end %>
      </div>

      <%!-- Toggle replies link — show/hide --%>
      <button
        :if={@comment.reply_count > 0}
        phx-click="toggle_replies"
        phx-value-id={@comment.id}
        class="ml-10 text-xs text-ink-500 hover:text-ink-700 cursor-pointer flex items-center gap-1"
        type="button"
      >
        <%= if @replies != [] do %>
          <.icon name="hero-chevron-up-mini" class="size-3.5" />
          <span>Fechar {if @comment.reply_count == 1, do: "resposta", else: "respostas"}</span>
        <% else %>
          <.icon name="hero-chevron-down-mini" class="size-3.5" />
          <span>
            Ver {@comment.reply_count} {if @comment.reply_count == 1,
              do: "resposta",
              else: "respostas"}
          </span>
        <% end %>
      </button>
    </div>
    """
  end

  attr :comment, :map, required: true
  attr :current_user, :map, required: true
  attr :likes_map, :map, required: true
  attr :comment_type, :string, required: true
  attr :is_admin, :boolean, required: true
  attr :size, :atom, required: true

  defp comment_row(%{comment: %{deleted_at: deleted_at}} = assigns) when not is_nil(deleted_at) do
    ~H"""
    <div class="flex items-start gap-2">
      <.avatar size={@size} initial={nil} />
      <p class="text-xs text-ink-400 italic pt-1">Comentário removido</p>
    </div>
    """
  end

  defp comment_row(assigns) do
    user = get_user(assigns.comment)

    badge =
      if user do
        try do
          OGrupoDeEstudos.Engagement.Badges.primary(get_user_id(assigns.comment))
        rescue
          _ -> nil
        end
      else
        nil
      end

    assigns =
      assigns
      |> assign(:user, user)
      |> assign(:liked?, liked?(assigns.likes_map, assigns.comment.id))
      |> assign(
        :can_delete?,
        can_delete?(assigns.comment, assigns.current_user, assigns.is_admin)
      )
      |> assign(:initial, if(user, do: String.upcase(String.first(user.username)), else: "?"))
      |> assign(:badge, badge)

    ~H"""
    <div class="flex items-start gap-2">
      <.avatar size={@size} initial={@initial} />

      <div class="flex-1 min-w-0">
        <div class="flex items-baseline gap-1.5">
          <.link
            :if={@user}
            navigate={"/users/#{@user.username}"}
            class="text-xs font-semibold text-ink-800 hover:underline"
          >
            {@user.username}
          </.link>
          <span :if={@badge} class="text-xs" title={@badge.name}>{@badge.icon}</span>
          <span :if={!@user} class="text-xs font-semibold text-ink-400">—</span>
          <span class="text-xs text-ink-400">{time_ago(@comment.inserted_at)}</span>
        </div>

        <p class="text-sm text-ink-800 mt-0.5 break-words">{@comment.body}</p>

        <div class="flex items-center gap-3 mt-1">
          <%!-- Like button --%>
          <button
            phx-click="toggle_comment_like"
            phx-value-type={@comment_type}
            phx-value-id={@comment.id}
            type="button"
            class="flex items-center gap-1 text-xs cursor-pointer"
            aria-label={if @liked?, do: "Remover curtida", else: "Curtir comentário"}
          >
            <.icon
              name={if @liked?, do: "hero-heart-solid", else: "hero-heart"}
              class={["size-4", if(@liked?, do: "text-accent-red", else: "text-ink-400")]}
            />
            <span class={if @liked?, do: "text-accent-red", else: "text-ink-400"}>
              {@comment.like_count}
            </span>
          </button>

          <%!-- Reply button — only for root comments --%>
          <button
            :if={@size == :root}
            phx-click="start_reply"
            phx-value-id={@comment.id}
            type="button"
            class="text-xs text-ink-400 hover:text-ink-700 cursor-pointer"
          >
            Responder
          </button>

          <%!-- Delete button — owner or admin only --%>
          <button
            :if={@can_delete?}
            phx-click="delete_comment"
            phx-value-id={@comment.id}
            phx-value-type={@comment_type}
            data-confirm="Apagar este comentário?"
            type="button"
            class="text-xs text-ink-400 hover:text-accent-red cursor-pointer"
            aria-label="Apagar comentário"
          >
            <.icon name="hero-trash" class="size-3.5" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :size, :atom, required: true
  attr :initial, :any, default: nil

  defp avatar(%{size: :root} = assigns) do
    ~H"""
    <div class="w-8 h-8 rounded-full bg-ink-200 flex items-center justify-center text-xs font-bold text-ink-500 shrink-0">
      {if @initial, do: @initial, else: "?"}
    </div>
    """
  end

  defp avatar(%{size: :reply} = assigns) do
    ~H"""
    <div class="w-6 h-6 rounded-full bg-ink-200 flex items-center justify-center text-xs font-bold text-ink-500 shrink-0">
      {if @initial, do: @initial, else: "?"}
    </div>
    """
  end

  attr :parent_id, :string, required: true

  defp reply_form(assigns) do
    ~H"""
    <form phx-submit="create_reply" phx-value-parent-id={@parent_id} class="flex items-center gap-2">
      <input
        type="text"
        name="body"
        placeholder="Escrever resposta…"
        autocomplete="off"
        required
        class="flex-1 bg-ink-50 rounded-full px-3 py-1.5 text-sm text-ink-800 border border-ink-200 focus:outline-none focus:ring-2 focus:ring-ink-400"
      />
      <button
        type="submit"
        class="text-sm font-medium text-accent-orange hover:opacity-80 cursor-pointer whitespace-nowrap"
      >
        Enviar
      </button>
    </form>
    """
  end

  defp new_comment_form(assigns) do
    ~H"""
    <div class="border-t border-ink-100 pt-3 mt-2">
      <form phx-submit="create_comment" class="flex items-center gap-2">
        <input
          type="text"
          name="body"
          placeholder="Escrever comentário…"
          autocomplete="off"
          required
          class="flex-1 bg-ink-50 rounded-full px-3 py-1.5 text-sm text-ink-800 border border-ink-200 focus:outline-none focus:ring-2 focus:ring-ink-400"
        />
        <button
          type="submit"
          class="text-sm font-medium text-accent-orange hover:opacity-80 cursor-pointer whitespace-nowrap"
        >
          Enviar
        </button>
      </form>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp get_user(comment) do
    cond do
      Map.has_key?(comment, :user) && comment.user -> comment.user
      Map.has_key?(comment, :author) && comment.author -> comment.author
      true -> nil
    end
  end

  defp get_user_id(comment) do
    Map.get(comment, :user_id) || Map.get(comment, :author_id)
  end

  defp liked?(%{liked_ids: liked_ids}, comment_id) do
    MapSet.member?(liked_ids, comment_id)
  end

  defp liked?(_likes_map, _comment_id), do: false

  defp can_delete?(comment, current_user, is_admin) do
    is_admin || current_user.id == get_user_id(comment)
  end

  defp time_ago(datetime) do
    diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "agora"
      diff < 3600 -> "#{div(diff, 60)}min"
      diff < 86_400 -> "#{div(diff, 3600)}h"
      diff < 604_800 -> "#{div(diff, 86_400)}d"
      true -> "#{div(diff, 604_800)}sem"
    end
  end
end
