defmodule OGrupoDeEstudosWeb.UI.UserAvatar do
  @moduledoc """
  Reusable avatar component. Shows the user's uploaded photo when available,
  falls back to a letter initial circle.

  ## Sizes

  - `:xs` — 20x20 (inline with small text, e.g. sidebar items)
  - `:sm` — 28x28 (comment replies, compact lists)
  - `:md` — 36x36 (comment roots, cards, standard lists)
  - `:lg` — 48x48 (profile headers in cards, shared diary counterpart)
  - `:xl` — 72x72 (main profile page header)

  ## Usage

      <.user_avatar user={@user} size={:md} />
      <.user_avatar user={@user} size={:sm} />
  """

  use Phoenix.Component

  attr :user, :map, required: true
  attr :size, :atom, default: :md, values: [:xs, :sm, :md, :lg, :xl]

  def user_avatar(assigns) do
    assigns = assign(assigns, :dimensions, dimensions(assigns.size))

    ~H"""
    <%= if @user && Map.get(@user, :avatar_path) do %>
      <img
        src={@user.avatar_path}
        alt={Map.get(@user, :name) || Map.get(@user, :username, "?")}
        loading="lazy"
        class={[
          "rounded-full object-cover shrink-0 border border-ink-200/40",
          @dimensions.class
        ]}
      />
    <% else %>
      <div class={[
        "rounded-full bg-ink-900 flex items-center justify-center text-ink-200 font-bold shrink-0",
        @dimensions.class,
        @dimensions.text
      ]}>
        {initial(@user)}
      </div>
    <% end %>
    """
  end

  defp dimensions(:xs), do: %{class: "w-5 h-5", text: "text-[8px]"}
  defp dimensions(:sm), do: %{class: "w-7 h-7", text: "text-[10px]"}
  defp dimensions(:md), do: %{class: "w-9 h-9", text: "text-xs"}
  defp dimensions(:lg), do: %{class: "w-12 h-12", text: "text-sm"}
  defp dimensions(:xl), do: %{class: "w-[72px] h-[72px]", text: "text-xl"}

  defp initial(nil), do: "?"

  defp initial(user) do
    name = Map.get(user, :name) || Map.get(user, :username, "?")
    name |> String.first() |> String.upcase()
  end
end
