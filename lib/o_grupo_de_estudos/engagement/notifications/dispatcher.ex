defmodule OGrupoDeEstudos.Engagement.Notifications.Dispatcher do
  @moduledoc """
  Creates notification records and broadcasts via PubSub.

  Called from Engagement context OUTSIDE Ecto.Multi transactions,
  wrapped in try/rescue so notification failures never break CRUD.

  Admin users receive a copy of ALL notifications.
  """

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Engagement.Comments
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Sequences
  alias Phoenix.PubSub

  @pubsub OGrupoDeEstudos.PubSub

  # ── Comment notifications ──────────────────────────────

  @doc "Dispatches notification when a comment reply is created."
  def notify(:new_comment, comment, actor, query_mod) do
    recipients = determine_comment_recipients(comment, actor, query_mod)
    parent_field = query_mod.parent_field()
    parent_id = Map.get(comment, parent_field)

    builder = fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: actor.id,
        action: :replied_comment,
        group_key: "comment:#{query_mod.likeable_type()}:#{root_comment_id(comment, query_mod)}",
        target_type: query_mod.likeable_type(),
        target_id: comment.id,
        parent_type: parent_type_from(query_mod),
        parent_id: parent_id,
        inserted_at: now()
      }
    end

    all_recipients = add_admin_recipients(recipients, actor.id)
    insert_and_broadcast(all_recipients, builder)
  end

  # ── Like notifications ─────────────────────────────────

  @doc """
  Dispatches notification when a like is created.

  Recipients:
  - Like on comment → comment author
  - Like on step (community) → step's suggested_by user
  - Like on sequence → sequence owner
  - Admin always gets a copy
  """
  def notify_like(actor_id, likeable_type, likeable_id) do
    {recipients, action, target_type, parent_type, parent_id} =
      determine_like_context(actor_id, likeable_type, likeable_id)

    builder = fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: actor_id,
        action: action,
        group_key: "like:#{likeable_type}:#{likeable_id}",
        target_type: target_type,
        target_id: likeable_id,
        parent_type: parent_type,
        parent_id: parent_id,
        inserted_at: now()
      }
    end

    all_recipients = add_admin_recipients(recipients, actor_id)
    insert_and_broadcast(all_recipients, builder)
  end

  @doc "Dispatches a notification when one user starts following another."
  def notify_follow(follower_id, followed_id) when follower_id != followed_id do
    insert_and_broadcast([followed_id], fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: follower_id,
        action: :followed_user,
        group_key: "follow:#{followed_id}",
        target_type: "profile",
        target_id: follower_id,
        parent_type: "profile",
        parent_id: follower_id,
        inserted_at: now()
      }
    end)
  end

  def notify_follow(_follower_id, _followed_id), do: :ok

  # ── Study request notifications ────────────────────────

  @doc "Notifies the recipient that someone wants to study with them."
  def notify_study_request(initiator_id, recipient_id, link_id) do
    insert_and_broadcast([recipient_id], fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: initiator_id,
        action: :study_request,
        group_key: "study_request:#{link_id}",
        target_type: "study_link",
        target_id: link_id,
        parent_type: "study_link",
        parent_id: link_id,
        inserted_at: now()
      }
    end)
  end

  @doc "Notifies student that teacher accepted their study request."
  def notify_study_accepted(teacher_id, student_id, link_id) do
    insert_and_broadcast([student_id], fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: teacher_id,
        action: :study_accepted,
        group_key: "study_accepted:#{link_id}",
        target_type: "study_link",
        target_id: link_id,
        parent_type: "study_link",
        parent_id: link_id,
        inserted_at: now()
      }
    end)
  end

  @doc "Teacher sends a gentle reminder to an inactive student."
  def notify_nudge(teacher, student_id, link_id) do
    insert_and_broadcast([student_id], fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: teacher.id,
        action: :study_nudge,
        group_key: "nudge:#{link_id}:#{Date.utc_today()}",
        target_type: "study_link",
        target_id: link_id,
        parent_type: "study_link",
        parent_id: link_id,
        inserted_at: now()
      }
    end)
  end

  @doc "Notifies the student when their teacher writes in the shared diary."
  def notify_shared_note(teacher, student_id, link_id) do
    insert_and_broadcast([student_id], fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: teacher.id,
        action: :shared_note_updated,
        group_key: "shared_note:#{link_id}:#{Date.utc_today()}",
        target_type: "study_link",
        target_id: link_id,
        parent_type: "study_link",
        parent_id: link_id,
        inserted_at: now()
      }
    end)
  end

  # ── Private: recipient determination ───────────────────

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

  defp determine_like_context(actor_id, "step_comment", comment_id) do
    comment = Comments.get_step_comment(comment_id)
    recipients = comment_author_recipients(comment, :user_id, actor_id)
    {recipients, :liked_comment, "step_comment", "step", comment && comment.step_id}
  end

  defp determine_like_context(actor_id, "sequence_comment", comment_id) do
    comment = Comments.get_sequence_comment(comment_id)
    recipients = comment_author_recipients(comment, :user_id, actor_id)
    {recipients, :liked_comment, "sequence_comment", "sequence", comment && comment.sequence_id}
  end

  defp determine_like_context(actor_id, "profile_comment", comment_id) do
    comment = Comments.get_profile_comment(comment_id)
    recipients = comment_author_recipients(comment, :author_id, actor_id)
    {recipients, :liked_comment, "profile_comment", "profile", comment && comment.profile_id}
  end

  defp determine_like_context(actor_id, "step", step_id) do
    # Notify step creator if it's a community step
    recipients =
      case Encyclopedia.steps_by_ids([step_id]) do
        %{^step_id => %{suggested_by_id: suggester_id}}
        when not is_nil(suggester_id) and suggester_id != actor_id ->
          [suggester_id]

        _ ->
          []
      end

    {recipients, :liked_step, "step", "step", step_id}
  end

  defp determine_like_context(actor_id, "sequence", sequence_id) do
    recipients =
      case Sequences.sequence_owner_id(sequence_id) do
        nil -> []
        ^actor_id -> []
        owner_id -> [owner_id]
      end

    {recipients, :liked_sequence, "sequence", "sequence", sequence_id}
  end

  defp determine_like_context(_actor_id, _type, _id) do
    {[], :liked_comment, "step_comment", "step", nil}
  end

  # ── Private: admin broadcast ───────────────────────────

  defp add_admin_recipients(recipients, actor_id) do
    # Add admins that aren't already recipients and aren't the actor
    extra_admins =
      Accounts.list_admin_ids()
      |> Enum.reject(fn id -> id == actor_id || id in recipients end)

    Enum.uniq(recipients ++ extra_admins)
  end

  defp comment_author_recipients(nil, _author_field, _actor_id), do: []

  defp comment_author_recipients(comment, author_field, actor_id) do
    author_id = Map.get(comment, author_field)

    if author_id != actor_id and is_nil(comment.deleted_at), do: [author_id], else: []
  end

  # ── Private: insert + broadcast ────────────────────────

  defp insert_and_broadcast([], _builder), do: :ok

  defp insert_and_broadcast(recipients, builder) do
    notifications = Enum.map(recipients, builder)
    Repo.insert_all(Notification, notifications)

    Enum.each(recipients, fn user_id ->
      PubSub.broadcast(@pubsub, "notifications:#{user_id}", {:new_notification, 1})
    end)
  end

  # ── Helpers ────────────────────────────────────────────

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

  # ── Suggestion notifications ───────────────────────────────

  @doc """
  Notifies all admins that a new suggestion was submitted.
  The suggestion author is excluded from receiving the notification.
  """
  def notify_suggestion(:suggestion_created, suggestion) do
    recipients = Accounts.list_admin_ids() -- [suggestion.user_id]

    insert_and_broadcast(recipients, fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: suggestion.user_id,
        action: :suggestion_created,
        group_key: "suggestion:#{suggestion.id}",
        target_type: "suggestion",
        target_id: suggestion.id,
        parent_type: Atom.to_string(suggestion.target_type),
        parent_id: suggestion.target_id,
        inserted_at: now()
      }
    end)
  end

  @doc """
  Dispatches a notification to the suggestion author when an admin reviews it.

  Sends `suggestion_approved` or `suggestion_rejected` based on `suggestion.status`.
  The admin never receives their own notification (excluded from recipients).
  """
  def notify_suggestion(:suggestion_reviewed, suggestion, admin) do
    action =
      case suggestion.status do
        :approved -> :suggestion_approved
        :rejected -> :suggestion_rejected
        _ -> nil
      end

    if action do
      recipients = [suggestion.user_id] -- [admin.id]

      insert_and_broadcast(recipients, fn user_id ->
        %{
          id: Ecto.UUID.generate(),
          user_id: user_id,
          actor_id: admin.id,
          action: action,
          group_key: "suggestion:#{suggestion.id}",
          target_type: "suggestion",
          target_id: suggestion.id,
          parent_type: Atom.to_string(suggestion.target_type),
          parent_id: suggestion.target_id,
          inserted_at: now()
        }
      end)
    else
      :ok
    end
  end

  defp now, do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
end
