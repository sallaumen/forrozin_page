defmodule OGrupoDeEstudosWeb.UI.InlineFollowButton do
  @moduledoc """
  Inline follow/following button. Renders next to usernames across the app.

  Renders nothing if target_user_id == current_user_id or target_user_id is nil.
  Emits `phx-click="toggle_follow"` with `phx-value-user-id`.
  """

  use Phoenix.Component

  attr :target_user_id, :string, required: true
  attr :current_user_id, :string, required: true
  attr :following_user_ids, :any, required: true

  def inline_follow_button(assigns) do
    ~H"""
    <%= if @target_user_id && @target_user_id != @current_user_id do %>
      <% is_following = MapSet.member?(@following_user_ids, @target_user_id) %>
      <button
        phx-click="toggle_follow"
        phx-value-user-id={@target_user_id}
        class={[
          "text-xs py-1 px-3 rounded-full border font-medium transition-colors cursor-pointer flex-shrink-0",
          is_following && "border-accent-orange bg-accent-orange/10 text-accent-orange",
          !is_following && "border-accent-orange bg-accent-orange text-white hover:bg-accent-orange/90"
        ]}
      >
        {if is_following, do: "Seguindo \u2713", else: "Seguir"}
      </button>
    <% end %>
    """
  end
end
