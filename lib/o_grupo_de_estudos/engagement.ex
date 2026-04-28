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
  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Encyclopedia.Step

  alias OGrupoDeEstudos.Engagement.{
    Badges,
    Favorite,
    Follow,
    Like,
    LikeQuery,
    ProfileComment,
    ProfileCommentQuery
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
  # Likes (unchanged signatures)
  # ══════════════════════════════════════════════════════════════════════

  @doc """
  Toggles a like for the given user on a likeable entity.

  Returns `{:ok, :liked}` when a new like is created,
  or `{:ok, :unliked}` when an existing like is removed.
  """
  def toggle_like(user_id, likeable_type, likeable_id) do
    with :ok <- OGrupoDeEstudos.RateLimiter.check("like", user_id, limit: 20, window_seconds: 10) do
      do_toggle_like(user_id, likeable_type, likeable_id)
    end
  end

  defp do_toggle_like(user_id, likeable_type, likeable_id) do
    case Repo.get_by(Like,
           user_id: user_id,
           likeable_type: likeable_type,
           likeable_id: likeable_id
         ) do
      nil ->
        %Like{}
        |> Like.changeset(%{
          user_id: user_id,
          likeable_type: likeable_type,
          likeable_id: likeable_id
        })
        |> Repo.insert()
        |> case do
          {:ok, _} ->
            safe_dispatch_like(user_id, likeable_type, likeable_id)
            {:ok, :liked}

          error ->
            error
        end

      like ->
        Repo.delete(like)
        {:ok, :unliked}
    end
  end

  @doc "Returns `true` if the user has liked the given entity."
  def liked?(user_id, likeable_type, likeable_id) do
    LikeQuery.exists?(user_id, likeable_type, likeable_id)
  end

  @doc "Returns the total like count for a single entity."
  def count_likes(likeable_type, likeable_id) do
    LikeQuery.count(likeable_type, likeable_id)
  end

  @doc """
  Returns a map with `:liked_ids` (MapSet) and `:counts` (map of id => count)
  for a batch of likeable_ids of the same type, for a given user.

  Useful for rendering like state on list pages without N+1 queries.
  """
  def likes_map(user_id, likeable_type, likeable_ids) do
    LikeQuery.batch_map(user_id, likeable_type, likeable_ids)
  end

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
    Dispatcher.notify(action, comment, actor, query_mod)
  rescue
    _error -> :ok
  end

  defp safe_dispatch_like(_user_id, _likeable_type, _likeable_id) do
    # Likes/favorites do not generate notifications
    :ok
  end

  defp safe_dispatch_follow(follower_id, followed_id) do
    Dispatcher.notify_follow(follower_id, followed_id)
  rescue
    _error -> :ok
  end

  defp schema_and_field_for("step"), do: {StepComment, :step_id}
  defp schema_and_field_for("sequence"), do: {SequenceComment, :sequence_id}
  defp schema_and_field_for("profile"), do: {ProfileComment, :profile_id}

  # ══════════════════════════════════════════════════════════════════════
  # Follows
  # ══════════════════════════════════════════════════════════════════════

  @doc """
  Toggles a follow relationship between two users.

  Returns `{:ok, :followed}` when a new follow is created,
  `{:ok, :unfollowed}` when an existing follow is removed,
  or `{:error, changeset}` when validation fails (e.g. self-follow).
  """
  def toggle_follow(follower_id, followed_id) do
    with :ok <-
           OGrupoDeEstudos.RateLimiter.check("follow", follower_id, limit: 5, window_seconds: 10) do
      do_toggle_follow(follower_id, followed_id)
    end
  end

  defp do_toggle_follow(follower_id, followed_id) do
    case Repo.get_by(Follow, follower_id: follower_id, followed_id: followed_id) do
      nil ->
        %Follow{}
        |> Follow.changeset(%{follower_id: follower_id, followed_id: followed_id})
        |> Repo.insert()
        |> case do
          {:ok, _} ->
            safe_dispatch_follow(follower_id, followed_id)
            {:ok, :followed}

          {:error, changeset} ->
            {:error, changeset}
        end

      follow ->
        Repo.delete(follow)
        {:ok, :unfollowed}
    end
  end

  @doc """
  Returns a list of suggested users to follow.
  Excludes self and already-followed users.
  Prioritizes users in the same city, then same state.
  """
  def suggest_users(%User{} = current_user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    my_followed_ids =
      from(f in Follow, where: f.follower_id == ^current_user.id, select: f.followed_id)

    # Friends of friends: people followed by users I follow, ranked by how
    # many mutual connections recommend them.
    fof_query =
      from(f2 in Follow,
        where: f2.follower_id in subquery(my_followed_ids),
        where: f2.followed_id != ^current_user.id,
        where: f2.followed_id not in subquery(my_followed_ids),
        group_by: f2.followed_id,
        select: {f2.followed_id, count(f2.id)},
        order_by: [desc: count(f2.id)],
        limit: ^limit
      )

    fof_results = Repo.all(fof_query)
    fof_ids = Enum.map(fof_results, &elem(&1, 0))

    if length(fof_ids) >= limit do
      from(u in User, where: u.id in ^fof_ids)
      |> Repo.all()
      |> sort_by_fof_rank(fof_results)
    else
      # Not enough friends-of-friends — fill with city/activity fallback
      already_excluded = [current_user.id | fof_ids]
      remaining = limit - length(fof_ids)

      fallback =
        from(u in User,
          where: u.id != ^current_user.id,
          where: u.id not in ^already_excluded,
          where: u.id not in subquery(my_followed_ids),
          order_by: [
            desc:
              fragment(
                "CASE WHEN ? = ? THEN 2 WHEN ? = ? THEN 1 ELSE 0 END",
                u.city,
                ^(current_user.city || ""),
                u.state,
                ^(current_user.state || "")
              ),
            desc: u.last_seen_at
          ],
          limit: ^remaining
        )
        |> Repo.all()

      fof_users =
        if fof_ids != [] do
          from(u in User, where: u.id in ^fof_ids)
          |> Repo.all()
          |> sort_by_fof_rank(fof_results)
        else
          []
        end

      fof_users ++ fallback
    end
  end

  defp sort_by_fof_rank(users, fof_results) do
    rank_map = Map.new(fof_results, fn {id, count} -> {id, count} end)
    Enum.sort_by(users, fn u -> -Map.get(rank_map, u.id, 0) end)
  end

  @doc "Returns `true` if follower_id is currently following followed_id."
  def following?(follower_id, followed_id) do
    Repo.exists?(
      from(f in Follow,
        where: f.follower_id == ^follower_id and f.followed_id == ^followed_id
      )
    )
  end

  @doc """
  Returns the list of users followed by the given user, ordered newest first.

  Supports optional `search:` keyword to filter by username or name (case-insensitive).
  """
  def list_following(user_id, opts \\ []) do
    search = Keyword.get(opts, :search, "")

    from(u in OGrupoDeEstudos.Accounts.User,
      join: f in Follow,
      on: f.followed_id == u.id,
      where: f.follower_id == ^user_id,
      order_by: [desc: f.inserted_at],
      limit: 200
    )
    |> maybe_search_users(search)
    |> Repo.all()
  end

  @doc """
  Returns the list of users following the given user, ordered newest first.

  Supports optional `search:` keyword to filter by username or name (case-insensitive).
  """
  def list_followers(user_id, opts \\ []) do
    search = Keyword.get(opts, :search, "")

    from(u in OGrupoDeEstudos.Accounts.User,
      join: f in Follow,
      on: f.follower_id == u.id,
      where: f.followed_id == ^user_id,
      order_by: [desc: f.inserted_at],
      limit: 200
    )
    |> maybe_search_users(search)
    |> Repo.all()
  end

  @doc "Returns the number of users the given user is following."
  def count_following(user_id) do
    Repo.aggregate(from(f in Follow, where: f.follower_id == ^user_id), :count)
  end

  @doc "Returns the number of followers of the given user."
  def count_followers(user_id) do
    Repo.aggregate(from(f in Follow, where: f.followed_id == ^user_id), :count)
  end

  @doc "Returns a MapSet of all user IDs the given user is following."
  def following_ids(user_id) do
    from(f in Follow, where: f.follower_id == ^user_id, select: f.followed_id)
    |> Repo.all()
    |> MapSet.new()
  end

  @doc "Returns a MapSet of followed IDs, scoped to the given list of target user IDs."
  def following_ids_for(user_id, target_ids) when is_list(target_ids) do
    from(f in Follow,
      where: f.follower_id == ^user_id and f.followed_id in ^target_ids,
      select: f.followed_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  defp maybe_search_users(query, ""), do: query
  defp maybe_search_users(query, nil), do: query

  defp maybe_search_users(query, search) do
    term = "%#{String.downcase(search)}%"
    where(query, [u], ilike(u.username, ^term) or ilike(u.name, ^term))
  end

  # ══════════════════════════════════════════════════════════════════════
  # Favorites
  # ══════════════════════════════════════════════════════════════════════

  @doc """
  Toggles a favorite for the given user on a favoritable entity.

  When favoriting, also ensures a like exists (auto-like).
  When unfavoriting, the like is preserved.

  Returns `{:ok, :favorited}` or `{:ok, :unfavorited}`.
  """
  def toggle_favorite(user_id, favoritable_type, favoritable_id) do
    case Repo.get_by(Favorite,
           user_id: user_id,
           favoritable_type: favoritable_type,
           favoritable_id: favoritable_id
         ) do
      nil ->
        create_favorite_with_like(user_id, favoritable_type, favoritable_id)

      favorite ->
        Repo.delete(favorite)
        {:ok, :unfavorited}
    end
  end

  defp create_favorite_with_like(user_id, favoritable_type, favoritable_id) do
    result =
      Multi.new()
      |> Multi.insert(
        :favorite,
        Favorite.changeset(%Favorite{}, %{
          user_id: user_id,
          favoritable_type: favoritable_type,
          favoritable_id: favoritable_id
        })
      )
      |> Multi.run(:like, fn _repo, _changes ->
        ensure_like_exists(user_id, favoritable_type, favoritable_id)
      end)
      |> Repo.transaction()

    case result do
      {:ok, _} -> {:ok, :favorited}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  defp ensure_like_exists(user_id, likeable_type, likeable_id) do
    if LikeQuery.exists?(user_id, likeable_type, likeable_id) do
      {:ok, :already_liked}
    else
      %Like{}
      |> Like.changeset(%{
        user_id: user_id,
        likeable_type: likeable_type,
        likeable_id: likeable_id
      })
      |> Repo.insert()
    end
  end

  @doc "Returns `true` if the user has favorited the given entity."
  def favorited?(user_id, favoritable_type, favoritable_id) do
    Repo.exists?(
      from f in Favorite,
        where:
          f.user_id == ^user_id and
            f.favoritable_type == ^favoritable_type and
            f.favoritable_id == ^favoritable_id
    )
  end

  @doc """
  Returns a MapSet of favorited IDs for the given user, type, and batch of IDs.

  Useful for rendering favorite state on list pages without N+1 queries.
  """
  def favorites_map(user_id, favoritable_type, favoritable_ids) do
    from(f in Favorite,
      where:
        f.user_id == ^user_id and
          f.favoritable_type == ^favoritable_type and
          f.favoritable_id in ^favoritable_ids,
      select: f.favoritable_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Returns the favorited entities for the given user and type.

  Supports `"step"` and `"sequence"` — returns the full records.
  """
  def list_user_favorites(user_id, "step") do
    from(s in Step,
      join: f in Favorite,
      on: f.favoritable_id == s.id and f.favoritable_type == "step",
      where: f.user_id == ^user_id and is_nil(s.deleted_at),
      order_by: [desc: f.inserted_at]
    )
    |> Repo.all()
  end

  def list_user_favorites(user_id, "sequence") do
    from(s in Sequence,
      join: f in Favorite,
      on: f.favoritable_id == s.id and f.favoritable_type == "sequence",
      where: f.user_id == ^user_id and is_nil(s.deleted_at),
      order_by: [desc: f.inserted_at],
      preload: [:user, sequence_steps: [step: :category]]
    )
    |> Repo.all()
  end

  @doc "Returns the total count of favorites for the given user across all types."
  def count_user_favorites(user_id) do
    Repo.aggregate(
      from(f in Favorite, where: f.user_id == ^user_id),
      :count
    )
  end

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

    badges = Map.new(user_ids, fn uid -> {uid, Badges.primary(uid)} end)

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
  # Metrics
  # ══════════════════════════════════════════════════════════════════════

  @doc "Returns a MapSet of step IDs that the given user has liked."
  def liked_step_ids(user_id) do
    from(l in Like,
      where: l.user_id == ^user_id and l.likeable_type == "step",
      select: l.likeable_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  @doc "Returns a list of step codes that the given user has liked."
  def liked_step_codes(user_id) do
    from(l in Like,
      where: l.user_id == ^user_id and l.likeable_type == "step",
      join: s in Step,
      on: s.id == l.likeable_id,
      select: s.code
    )
    |> Repo.all()
  end

  @doc "Returns the count of likes given by a user for a specific likeable_type."
  def count_likes_given(user_id, likeable_type) do
    Repo.aggregate(
      from(l in Like,
        where: l.user_id == ^user_id and l.likeable_type == ^likeable_type
      ),
      :count
    )
  end

  @doc """
  Returns the total number of comments authored by the user across all comment types.

  StepComment and SequenceComment use `user_id`.
  ProfileComment uses `author_id`.
  """
  def count_comments_authored(user_id) do
    step_count =
      Repo.aggregate(
        from(c in StepComment, where: c.user_id == ^user_id and is_nil(c.deleted_at)),
        :count
      )

    sequence_count =
      Repo.aggregate(
        from(c in SequenceComment, where: c.user_id == ^user_id and is_nil(c.deleted_at)),
        :count
      )

    profile_count =
      Repo.aggregate(
        from(c in ProfileComment, where: c.author_id == ^user_id and is_nil(c.deleted_at)),
        :count
      )

    step_count + sequence_count + profile_count
  end

  @doc """
  Returns the total number of likes received on all comments authored by the user.

  Sums likes on step_comments (user_id), sequence_comments (user_id),
  and profile_comments (author_id).
  """
  def total_likes_received(user_id) do
    step_likes =
      from(l in Like,
        join: c in StepComment,
        on: l.likeable_id == c.id and l.likeable_type == "step_comment",
        where: c.user_id == ^user_id,
        select: count(l.id)
      )
      |> Repo.one()
      |> Kernel.||(0)

    sequence_likes =
      from(l in Like,
        join: c in SequenceComment,
        on: l.likeable_id == c.id and l.likeable_type == "sequence_comment",
        where: c.user_id == ^user_id,
        select: count(l.id)
      )
      |> Repo.one()
      |> Kernel.||(0)

    profile_likes =
      from(l in Like,
        join: c in ProfileComment,
        on: l.likeable_id == c.id and l.likeable_type == "profile_comment",
        where: c.author_id == ^user_id,
        select: count(l.id)
      )
      |> Repo.one()
      |> Kernel.||(0)

    step_likes + sequence_likes + profile_likes
  end
end
