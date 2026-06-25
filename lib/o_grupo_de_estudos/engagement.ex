defmodule OGrupoDeEstudos.Engagement do
  @moduledoc """
  Context for user engagement features: likes, comments, notifications.

  Comment CRUD is generic via the Commentable behaviour — each comment type
  (step, sequence, profile) delegates to its own query module while sharing
  creation, deletion, and listing logic here.

  Backward compatibility: the original `list_profile_comments/1`,
  `create_profile_comment/1`, and `delete_profile_comment/1` signatures are
  preserved for existing LiveView callers.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Encyclopedia.Step

  alias OGrupoDeEstudos.Engagement.{
    Badges,
    Favorites,
    Follows,
    Likes,
    Metrics,
    ProfileComment,
    ProfileCommentQuery,
    SafeDispatch
  }

  alias OGrupoDeEstudos.Engagement.Comments.{
    SequenceComment,
    SequenceCommentQuery,
    StepComment,
    StepCommentQuery
  }

  alias OGrupoDeEstudos.Engagement.Notifications.{Dispatcher, Notification, NotificationQuery}
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
  # Profile comments — backward-compatible signatures (1-arity)
  # ══════════════════════════════════════════════════════════════════════

  @doc """
  Returns active (non-deleted) comments on a user's profile, newest first.

  Accepts the same options as `ProfileCommentQuery.list_by/1`.
  This is the legacy signature kept for UserProfileLive compatibility.
  """
  def list_profile_comments(opts) when is_list(opts) do
    ProfileCommentQuery.list_by(opts)
  end

  @doc """
  Posts a new comment on a user's profile.

  Accepts a raw attrs map (legacy signature for UserProfileLive).
  Returns `{:ok, comment}` or `{:error, changeset}`.
  """
  def create_profile_comment(attrs) when is_map(attrs) do
    %ProfileComment{}
    |> ProfileComment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Soft-deletes a profile comment by setting `deleted_at` to now.

  Legacy signature — no authorization check, caller is responsible.
  Returns `{:ok, comment}` or `{:error, changeset}`.
  """
  def delete_profile_comment(%ProfileComment{} = comment) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    comment
    |> Ecto.Changeset.change(deleted_at: now)
    |> Repo.update()
  end

  # ══════════════════════════════════════════════════════════════════════
  # Step comments — typed public API
  # ══════════════════════════════════════════════════════════════════════

  @doc "Lists root step comments for the given step, ordered by engagement."
  def list_step_comments(step_id, opts \\ []),
    do: list_comments(StepCommentQuery, step_id, opts)

  @doc "Creates a step comment (root or reply). Bumps parent reply_count via Multi."
  def create_step_comment(user, step_id, attrs),
    do: create_comment(StepComment, StepCommentQuery, user, step_id, attrs)

  @doc "Deletes a step comment with authorization. Hard-deletes if no replies, tombstones otherwise."
  def delete_step_comment(user, comment),
    do: delete_comment(StepComment, StepCommentQuery, user, comment)

  # ══════════════════════════════════════════════════════════════════════
  # Sequence comments — typed public API
  # ══════════════════════════════════════════════════════════════════════

  @doc "Lists root sequence comments for the given sequence, ordered by engagement."
  def list_sequence_comments(sequence_id, opts \\ []),
    do: list_comments(SequenceCommentQuery, sequence_id, opts)

  @doc "Creates a sequence comment (root or reply). Bumps parent reply_count via Multi."
  def create_sequence_comment(user, sequence_id, attrs),
    do: create_comment(SequenceComment, SequenceCommentQuery, user, sequence_id, attrs)

  @doc "Deletes a sequence comment with authorization."
  def delete_sequence_comment(user, comment),
    do: delete_comment(SequenceComment, SequenceCommentQuery, user, comment)

  # ══════════════════════════════════════════════════════════════════════
  # Profile comments — new typed API (2+arity)
  # ══════════════════════════════════════════════════════════════════════

  @doc "Lists root profile comments for the given profile, ordered by engagement."
  def list_profile_comments(profile_id, opts) when is_binary(profile_id),
    do: list_comments(ProfileCommentQuery, profile_id, opts)

  @doc "Creates a profile comment via the generic pipeline (with notification dispatch)."
  def create_profile_comment(user, profile_id, attrs),
    do: create_comment(ProfileComment, ProfileCommentQuery, user, profile_id, attrs)

  @doc "Deletes a profile comment with authorization (new 2-arity)."
  def delete_profile_comment(user, comment),
    do: delete_comment(ProfileComment, ProfileCommentQuery, user, comment)

  # ══════════════════════════════════════════════════════════════════════
  # Replies — generic for any comment type
  # ══════════════════════════════════════════════════════════════════════

  @doc """
  Lists replies for a given parent comment.

  `query_mod` is the Commentable implementation (e.g. `StepCommentQuery`).
  """
  def list_replies(query_mod, comment_id, opts \\ []) do
    query_mod.base_query()
    |> query_mod.replies_for(comment_id)
    |> query_mod.ordered_by_engagement()
    |> paginate(opts)
    |> Repo.all()
    |> preload_user(query_mod)
  end

  # ══════════════════════════════════════════════════════════════════════
  # Comment counts — batch preload for list pages
  # ══════════════════════════════════════════════════════════════════════

  @doc """
  Returns a map of `%{parent_id => comment_count}` for the given parent type and IDs.

  ## Examples

      Engagement.comment_counts_for("step", [step1.id, step2.id])
      #=> %{"uuid-1" => 3, "uuid-2" => 0}
  """
  def comment_counts_for(type, parent_ids) when is_list(parent_ids) do
    {schema, parent_field} = schema_and_field_for(type)

    counts =
      from(c in schema,
        where: field(c, ^parent_field) in ^parent_ids and is_nil(c.deleted_at),
        group_by: field(c, ^parent_field),
        select: {field(c, ^parent_field), count(c.id)}
      )
      |> Repo.all()
      |> Map.new()

    # Ensure every requested ID is present (default 0)
    Map.new(parent_ids, fn id -> {id, Map.get(counts, id, 0)} end)
  end

  # ══════════════════════════════════════════════════════════════════════
  # Notifications
  # ══════════════════════════════════════════════════════════════════════

  @doc "Lists notifications for the given user (unread first, then newest)."
  def list_notifications(user_id, opts \\ []) do
    NotificationQuery.list_for_user(user_id, opts)
  end

  @doc "Returns the count of unread notifications for the given user."
  def unread_count(user_id) do
    NotificationQuery.unread_count(user_id)
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
  # Generic comment CRUD (private)
  # ══════════════════════════════════════════════════════════════════════

  defp list_comments(query_mod, parent_id, opts) do
    query_mod.base_query()
    |> query_mod.for_parent(parent_id)
    |> query_mod.roots_only()
    |> query_mod.ordered_by_engagement()
    |> paginate(opts)
    |> Repo.all()
    |> preload_user(query_mod)
  end

  defp create_comment(schema_mod, query_mod, user, parent_id, attrs) do
    case OGrupoDeEstudos.RateLimiter.check("comment", user.id, limit: 5, window_seconds: 10) do
      {:error, :rate_limited} -> {:error, :rate_limited}
      :ok -> do_create_comment(schema_mod, query_mod, user, parent_id, attrs)
    end
  end

  defp do_create_comment(schema_mod, query_mod, user, parent_id, attrs) do
    parent_field = query_mod.parent_field()
    user_field = query_mod.user_field()

    changeset =
      struct(schema_mod)
      |> schema_mod.changeset(
        attrs
        |> Map.put(user_field, user.id)
        |> Map.put(parent_field, parent_id)
      )

    # reply_count is handled by Postgres trigger — no Multi.run needed
    Multi.new()
    |> Multi.insert(:comment, changeset)
    |> Repo.transaction()
    |> case do
      {:ok, %{comment: comment}} ->
        safe_dispatch(:new_comment, comment, user, query_mod)
        {:ok, Repo.preload(comment, user_assoc(query_mod))}

      {:error, :comment, changeset, _} ->
        {:error, changeset}
    end
  end

  defp delete_comment(schema_mod, query_mod, user, comment) do
    with :ok <- Policy.authorize(:delete_comment, user, comment) do
      parent_comment_field = query_mod.parent_comment_field()

      if comment.reply_count == 0 do
        hard_delete(schema_mod, comment, parent_comment_field)
      else
        tombstone(comment)
      end
    end
  end

  defp hard_delete(_schema_mod, comment, _parent_comment_field) do
    # reply_count decrement handled by Postgres trigger on DELETE
    case Repo.delete(comment) do
      {:ok, _} -> {:ok, :deleted}
      {:error, reason} -> {:error, reason}
    end
  end

  @tombstone_body "[comentário removido]"

  defp tombstone(comment) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    comment
    |> Ecto.Changeset.change(%{body: @tombstone_body, deleted_at: now})
    |> Repo.update()
  end

  # ══════════════════════════════════════════════════════════════════════
  # Helpers
  # ══════════════════════════════════════════════════════════════════════

  defp paginate(query, opts) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    query
    |> limit(^limit)
    |> offset(^offset)
  end

  defp preload_user(comments, query_mod) do
    assoc = user_assoc(query_mod)
    Repo.preload(comments, assoc)
  end

  defp user_assoc(query_mod) do
    query_mod.user_field()
    |> Atom.to_string()
    |> String.trim_trailing("_id")
    |> String.to_existing_atom()
  end

  defp safe_dispatch(action, comment, actor, query_mod) do
    SafeDispatch.run(fn -> Dispatcher.notify(action, comment, actor, query_mod) end)
  end

  defp schema_and_field_for("step"), do: {StepComment, :step_id}
  defp schema_and_field_for("sequence"), do: {SequenceComment, :sequence_id}
  defp schema_and_field_for("profile"), do: {ProfileComment, :profile_id}

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
end
