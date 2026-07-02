defmodule OGrupoDeEstudosWeb.Hooks.NotificationSubscriber do
  @moduledoc "on_mount hook: subscribes to notification PubSub + loads unread count."
  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Study
  alias OGrupoDeEstudos.Suggestions
  alias OGrupoDeEstudosWeb.Presence

  def on_mount(:default, _params, _session, socket) do
    socket =
      assign(socket,
        notification_dropdown_open: false,
        notification_preview_groups: [],
        notification_targets: %{steps: %{}, users: %{}}
      )

    case connected_user(socket) do
      nil ->
        {:cont, assign(socket, disconnected_assigns())}

      user ->
        socket =
          socket
          |> assign(connected_assigns(user))
          |> push_event("set-dark-mode", %{dark: user.dark_mode})

        {:cont, socket}
    end
  end

  defp connected_user(socket) do
    if Phoenix.LiveView.connected?(socket), do: socket.assigns[:current_user], else: nil
  end

  defp connected_assigns(user) do
    subscribe_to_topics(user)
    track_presence(user)

    %{
      notification_count: Engagement.unread_count(user.id),
      pending_suggestions_count: pending_suggestions_count(user),
      pending_study_count: pending_study_count(user),
      online_users: online_users(user),
      online_count: online_count(),
      activity_toast: nil
    }
  end

  defp disconnected_assigns do
    %{
      notification_count: 0,
      pending_suggestions_count: 0,
      pending_study_count: 0,
      online_users: [],
      online_count: 0,
      activity_toast: nil
    }
  end

  defp subscribe_to_topics(user) do
    Phoenix.PubSub.subscribe(OGrupoDeEstudos.PubSub, "notifications:#{user.id}")
    Phoenix.PubSub.subscribe(OGrupoDeEstudos.PubSub, "activity:#{user.id}")
  end

  defp track_presence(user) do
    Presence.track(
      self(),
      "users:online",
      user.id,
      %{
        username: user.username,
        name: user.name,
        joined_at: System.system_time(:second)
      }
    )
  end

  defp online_users(user) do
    ids =
      "users:online"
      |> Presence.list()
      |> Map.keys()
      |> Enum.reject(&(&1 == user.id))
      |> Enum.take(5)

    batch_user_summaries(ids)
  end

  defp batch_user_summaries(ids), do: Accounts.list_user_summaries(ids)

  defp online_count do
    "users:online"
    |> Presence.list()
    |> map_size()
  end

  defp pending_suggestions_count(user) do
    if Accounts.admin?(user), do: Suggestions.count_pending(), else: 0
  end

  defp pending_study_count(%{is_teacher: true, id: user_id}) do
    user_id
    |> Study.list_pending_requests_for_teacher()
    |> length()
  end

  defp pending_study_count(%{id: user_id}) do
    Engagement.unread_count(user_id, action: :shared_note_updated)
  end
end
