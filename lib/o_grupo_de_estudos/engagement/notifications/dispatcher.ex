defmodule OGrupoDeEstudos.Engagement.Notifications.Dispatcher do
  @moduledoc """
  Creates notification records and broadcasts via PubSub.

  Stub implementation — inserts notifications for reply recipients and broadcasts
  to their PubSub topics. Will be expanded with Grouper logic and like notifications
  in Task 9.

  This module is called from Engagement context functions OUTSIDE the Ecto.Multi
  transaction, wrapped in a try/rescue so notification failures never break CRUD.
  """

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias Phoenix.PubSub

  @pubsub OGrupoDeEstudos.PubSub

  @doc """
  Dispatches notifications for a new comment.

  For replies, notifies the parent comment's author (unless self-reply or parent is deleted).
  Root comments produce no notifications (no follow system yet).
  """
  def notify(:new_comment, comment, actor, query_mod) do
    recipients = determine_comment_recipients(comment, actor, query_mod)
    parent_field = query_mod.parent_field()
    parent_id = Map.get(comment, parent_field)

    insert_and_broadcast(recipients, fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: actor.id,
        action: "replied_comment",
        group_key: "comment:#{query_mod.likeable_type()}:#{root_comment_id(comment, query_mod)}",
        target_type: query_mod.likeable_type(),
        target_id: comment.id,
        parent_type: parent_type_from(query_mod),
        parent_id: parent_id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    end)
  end

  # --- Private ---

  defp determine_comment_recipients(comment, actor, query_mod) do
    parent_comment_field = query_mod.parent_comment_field()
    parent_comment_id = Map.get(comment, parent_comment_field)
    user_field = query_mod.user_field()
    actor_id = Map.get(actor, :id)

    if parent_comment_id do
      parent = Repo.get(query_mod.schema(), parent_comment_id)

      if parent && Map.get(parent, user_field) != actor_id && is_nil(parent.deleted_at) do
        [Map.get(parent, user_field)]
      else
        []
      end
    else
      []
    end
  end

  defp insert_and_broadcast([], _builder), do: :ok

  defp insert_and_broadcast(recipients, builder) do
    notifications = Enum.map(recipients, builder)
    Repo.insert_all(Notification, notifications)

    Enum.each(recipients, fn user_id ->
      PubSub.broadcast(@pubsub, "notifications:#{user_id}", {:new_notification, 1})
    end)
  end

  defp root_comment_id(comment, query_mod) do
    parent_comment_field = query_mod.parent_comment_field()
    Map.get(comment, parent_comment_field) || comment.id
  end

  defp parent_type_from(query_mod) do
    case query_mod.parent_field() do
      :step_id -> "step"
      :sequence_id -> "sequence"
      :profile_id -> "profile"
    end
  end
end
