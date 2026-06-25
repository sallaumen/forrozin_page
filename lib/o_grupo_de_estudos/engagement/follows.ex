defmodule OGrupoDeEstudos.Engagement.Follows do
  @moduledoc """
  Follow relationships: toggling (rate-limited, with notification + activity
  broadcast), follow suggestions (friends-of-friends ranked by mutual
  connections, with a city/state/activity fallback), and follower/following
  listings, counts, and ID sets.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Engagement.{ActivityBroadcaster, Follow, SafeDispatch}
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.RateLimiter
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Search

  @doc """
  Toggles a follow relationship between two users.

  Returns `{:ok, :followed}` when a new follow is created,
  `{:ok, :unfollowed}` when an existing follow is removed,
  or `{:error, changeset}` when validation fails (e.g. self-follow).
  """
  def toggle_follow(follower_id, followed_id) do
    with :ok <- RateLimiter.check("follow", follower_id, limit: 5, window_seconds: 10) do
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
            safe_broadcast_follow_activity(follower_id, followed_id)
            {:ok, :followed}

          {:error, changeset} ->
            {:error, changeset}
        end

      follow ->
        Repo.delete(follow)
        {:ok, :unfollowed}
    end
  end

  defp safe_dispatch_follow(follower_id, followed_id) do
    SafeDispatch.run(fn -> Dispatcher.notify_follow(follower_id, followed_id) end)
  end

  defp safe_broadcast_follow_activity(follower_id, followed_id) do
    SafeDispatch.run(fn ->
      followed_user = Repo.get!(User, followed_id)
      follower_user = Repo.get!(User, follower_id)

      ActivityBroadcaster.broadcast_activity(
        follower_user,
        :followed_user,
        %{target_username: followed_user.username}
      )
    end)
  end

  @doc """
  Returns a list of suggested users to follow.
  Excludes self and already-followed users.
  Prioritizes friends-of-friends, then same city/state.
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

    from(u in User,
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

    from(u in User,
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

  @doc "Returns a list of user IDs that follow the given user (followers)."
  def following_ids_reverse(user_id) do
    from(f in Follow, where: f.followed_id == ^user_id, select: f.follower_id)
    |> Repo.all()
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
    term = "%#{Search.escape_like(String.downcase(search))}%"
    where(query, [u], ilike(u.username, ^term) or ilike(u.name, ^term))
  end
end
