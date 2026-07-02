defmodule OGrupoDeEstudos.Engagement do
  @moduledoc """
  Facade for user engagement features: likes, comments, follows, favorites,
  notifications, and batch stats.

  Each concern lives in its own module under `Engagement.*` and is exposed here
  via `defdelegate`, so existing callers keep a single entry point while the
  implementation stays cohesive and independently testable. Only notifications
  and `user_stats_batch/1` retain logic in this module.

  Backward compatibility: the original `list_profile_comments/1`,
  `create_profile_comment/1`, and `delete_profile_comment/1` signatures are
  preserved (now via `Engagement.Comments`) for existing LiveView callers.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Encyclopedia.Step

  alias OGrupoDeEstudos.Engagement.{
    Badges,
    Comments,
    Favorites,
    Follows,
    Learnings,
    Likes,
    Metrics
  }

  alias OGrupoDeEstudos.Engagement.DeviceSession
  alias OGrupoDeEstudos.Engagement.Notifications.{Notification, NotificationQuery}
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Sequences.Sequence

  # ══════════════════════════════════════════════════════════════════════
  # Likes (delegated to Engagement.Likes)
  # ══════════════════════════════════════════════════════════════════════

  defdelegate toggle_like(user_id, likeable_type, likeable_id), to: Likes
  defdelegate liked?(user_id, likeable_type, likeable_id), to: Likes
  defdelegate count_likes(likeable_type, likeable_id), to: Likes
  defdelegate likes_map(user_id, likeable_type, likeable_ids), to: Likes

  # ══════════════════════════════════════════════════════════════════════
  # Comments (delegated to Engagement.Comments)
  # ══════════════════════════════════════════════════════════════════════

  # Profile comments — backward-compatible 1-arity signatures
  defdelegate list_profile_comments(opts), to: Comments
  defdelegate create_profile_comment(attrs), to: Comments
  defdelegate delete_profile_comment(comment), to: Comments

  # Step comments
  defdelegate list_step_comments(step_id, opts \\ []), to: Comments
  defdelegate create_step_comment(user, step_id, attrs), to: Comments
  defdelegate delete_step_comment(user, comment), to: Comments
  defdelegate get_step_comment(id), to: Comments

  # Sequence comments
  defdelegate list_sequence_comments(sequence_id, opts \\ []), to: Comments
  defdelegate create_sequence_comment(user, sequence_id, attrs), to: Comments
  defdelegate delete_sequence_comment(user, comment), to: Comments
  defdelegate get_sequence_comment(id), to: Comments

  # Profile comments — new typed API (2+arity)
  defdelegate list_profile_comments(profile_id, opts), to: Comments
  defdelegate create_profile_comment(user, profile_id, attrs), to: Comments
  defdelegate delete_profile_comment(user, comment), to: Comments

  # Replies and batch counts
  defdelegate list_replies(query_mod, comment_id, opts \\ []), to: Comments
  defdelegate comment_counts_for(type, parent_ids), to: Comments

  # ══════════════════════════════════════════════════════════════════════
  # Notifications
  # ══════════════════════════════════════════════════════════════════════

  @doc "Lists notifications for the given user (unread first, then newest)."
  def list_notifications(user_id, opts \\ []) do
    NotificationQuery.list_for_user(user_id, opts)
  end

  @doc "Returns the count of unread notifications, optionally filtered by `action:`."
  def unread_count(user_id, opts \\ []) do
    NotificationQuery.unread_count(user_id, opts)
  end

  @doc """
  Batch-resolves the step and profile targets referenced by a list of
  notifications (raw or grouped), so render layers never query per item.

  Returns `%{steps: %{id => %{code, name}}, users: %{id => summary}}`.
  """
  def notification_targets(notifications) do
    %{
      steps: notifications |> parent_ids("step") |> Encyclopedia.step_summaries_by_ids(),
      users: notifications |> parent_ids("profile") |> user_summaries_by_ids()
    }
  end

  defp parent_ids(notifications, parent_type) do
    notifications
    |> Enum.filter(&(&1.parent_type == parent_type and not is_nil(&1.parent_id)))
    |> Enum.map(& &1.parent_id)
    |> Enum.uniq()
  end

  defp user_summaries_by_ids(ids) do
    ids
    |> Accounts.list_user_summaries()
    |> Map.new(&{&1.id, &1})
  end

  @doc "Marks a single notification as read."
  def mark_as_read(user, notification_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    from(n in Notification,
      where: n.id == ^notification_id and n.user_id == ^user.id and is_nil(n.read_at)
    )
    |> Repo.update_all(set: [read_at: now])
    |> case do
      {1, _} -> {:ok, :marked}
      {0, _} -> {:ok, :already_read}
    end
  end

  @doc "Marks all unread notifications as read for the given user."
  def mark_all_read(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    {count, _} =
      from(n in Notification,
        where: n.user_id == ^user.id and is_nil(n.read_at)
      )
      |> Repo.update_all(set: [read_at: now])

    {:ok, count}
  end

  # ══════════════════════════════════════════════════════════════════════
  # Follows (delegated to Engagement.Follows)
  # ══════════════════════════════════════════════════════════════════════

  defdelegate toggle_follow(follower_id, followed_id), to: Follows
  defdelegate suggest_users(current_user, opts \\ []), to: Follows
  defdelegate following?(follower_id, followed_id), to: Follows
  defdelegate list_following(user_id, opts \\ []), to: Follows
  defdelegate list_followers(user_id, opts \\ []), to: Follows
  defdelegate count_following(user_id), to: Follows
  defdelegate count_followers(user_id), to: Follows
  defdelegate following_ids(user_id), to: Follows
  defdelegate following_ids_reverse(user_id), to: Follows
  defdelegate following_ids_for(user_id, target_ids), to: Follows

  # ══════════════════════════════════════════════════════════════════════
  # Favorites (delegated to Engagement.Favorites)
  # ══════════════════════════════════════════════════════════════════════

  defdelegate toggle_favorite(user_id, favoritable_type, favoritable_id), to: Favorites
  defdelegate favorited?(user_id, favoritable_type, favoritable_id), to: Favorites
  defdelegate favorites_map(user_id, favoritable_type, favoritable_ids), to: Favorites
  defdelegate list_user_favorites(user_id, type), to: Favorites
  defdelegate count_user_favorites(user_id), to: Favorites
  defdelegate favorited_step_codes(user_id), to: Favorites, as: :step_codes_for

  # ══════════════════════════════════════════════════════════════════════
  # Learnings (jornada de estudos — delegated to Engagement.Learnings)
  # ══════════════════════════════════════════════════════════════════════

  defdelegate toggle_learned(user_id, step_id), to: Learnings
  defdelegate learned?(user_id, step_id), to: Learnings
  defdelegate learned_step_codes(user_id), to: Learnings
  defdelegate list_learned_steps(user_id), to: Learnings
  defdelegate count_user_learned(user_id), to: Learnings
  defdelegate reset_learned(user_id), to: Learnings

  # ══════════════════════════════════════════════════════════════════════
  # Batch stats
  # ══════════════════════════════════════════════════════════════════════

  @doc """
  Batch-loads step count, sequence count, and primary badge for a list of user IDs.
  Returns `%{user_id => %{steps_count: int, sequences_count: int, badge: badge | nil}}`.
  """
  def user_stats_batch([]), do: %{}

  def user_stats_batch(user_ids) when is_list(user_ids) do
    steps_counts =
      from(s in Step,
        where: s.suggested_by_id in ^user_ids and is_nil(s.deleted_at),
        group_by: s.suggested_by_id,
        select: {s.suggested_by_id, count(s.id)}
      )
      |> Repo.all()
      |> Map.new()

    seq_counts =
      from(s in Sequence,
        where: s.user_id in ^user_ids and s.public == true,
        group_by: s.user_id,
        select: {s.user_id, count(s.id)}
      )
      |> Repo.all()
      |> Map.new()

    badges = Badges.primary_batch(user_ids)

    Map.new(user_ids, fn uid ->
      {uid,
       %{
         steps_count: Map.get(steps_counts, uid, 0),
         sequences_count: Map.get(seq_counts, uid, 0),
         badge: Map.get(badges, uid)
       }}
    end)
  end

  # ══════════════════════════════════════════════════════════════════════
  # Metrics (read-only; delegated to Engagement.Metrics)
  # ══════════════════════════════════════════════════════════════════════

  defdelegate liked_step_ids(user_id), to: Metrics
  defdelegate liked_step_codes(user_id), to: Metrics
  defdelegate count_likes_given(user_id, likeable_type), to: Metrics
  defdelegate count_comments_authored(user_id), to: Metrics
  defdelegate total_likes_received(user_id), to: Metrics
  defdelegate count_likes_given_batch(user_ids, likeable_type), to: Metrics
  defdelegate count_comments_authored_batch(user_ids), to: Metrics
  defdelegate total_likes_received_batch(user_ids), to: Metrics

  # ══════════════════════════════════════════════════════════════════════
  # Device sessions
  # ══════════════════════════════════════════════════════════════════════

  @doc "Persists a device session captured at the web boundary."
  def track_device_session(attrs) do
    %DeviceSession{}
    |> DeviceSession.changeset(attrs)
    |> Repo.insert()
  end
end
