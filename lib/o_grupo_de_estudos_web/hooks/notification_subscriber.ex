defmodule OGrupoDeEstudosWeb.Hooks.NotificationSubscriber do
  @moduledoc "on_mount hook: subscribes to notification PubSub + loads unread count."
  import Phoenix.Component, only: [assign: 2]
  import Ecto.Query

  def on_mount(:default, _params, _session, socket) do
    socket =
      assign(socket,
        notification_dropdown_open: false,
        notification_preview_groups: []
      )

    if Phoenix.LiveView.connected?(socket) && socket.assigns[:current_user] do
      user = socket.assigns.current_user
      Phoenix.PubSub.subscribe(OGrupoDeEstudos.PubSub, "notifications:#{user.id}")
      Phoenix.PubSub.subscribe(OGrupoDeEstudos.PubSub, "activity:#{user.id}")

      # Track online presence
      OGrupoDeEstudosWeb.Presence.track(
        self(),
        "users:online",
        user.id,
        %{
          username: user.username,
          name: user.name,
          joined_at: System.system_time(:second)
        }
      )

      online_users =
        OGrupoDeEstudosWeb.Presence.list("users:online")
        |> Map.keys()
        |> Enum.reject(&(&1 == user.id))
        |> Enum.take(5)
        |> Enum.map(fn uid ->
          case OGrupoDeEstudos.Repo.get(OGrupoDeEstudos.Accounts.User, uid) do
            nil -> nil
            u -> %{id: u.id, username: u.username, name: u.name}
          end
        end)
        |> Enum.reject(&is_nil/1)

      online_count =
        OGrupoDeEstudosWeb.Presence.list("users:online")
        |> map_size()

      unread = OGrupoDeEstudos.Engagement.unread_count(user.id)

      pending_suggestions =
        if OGrupoDeEstudos.Accounts.admin?(user),
          do: OGrupoDeEstudos.Suggestions.count_pending(),
          else: 0

      pending_study =
        cond do
          user.is_teacher ->
            length(OGrupoDeEstudos.Study.list_pending_requests_for_teacher(user.id))

          true ->
            from(n in OGrupoDeEstudos.Engagement.Notifications.Notification,
              where:
                n.user_id == ^user.id and n.action == "shared_note_updated" and
                  is_nil(n.read_at)
            )
            |> OGrupoDeEstudos.Repo.aggregate(:count)
        end

      {:cont,
       assign(socket,
         notification_count: unread,
         pending_suggestions_count: pending_suggestions,
         pending_study_count: pending_study,
         online_users: online_users,
         online_count: online_count,
         activity_toast: nil
       )}
    else
      {:cont,
       assign(socket,
         notification_count: 0,
         pending_suggestions_count: 0,
         pending_study_count: 0,
         online_users: [],
         online_count: 0,
         activity_toast: nil
       )}
    end
  end
end
