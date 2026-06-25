defmodule OGrupoDeEstudos.Engagement.Likes do
  @moduledoc """
  Likes: toggling (rate-limited; emits an ephemeral activity toast for step
  likes and persists a notification for the content owner), existence checks,
  counts, and batch lookups for list pages.
  """

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Encyclopedia.Step
  alias OGrupoDeEstudos.Engagement.{ActivityBroadcaster, Like, LikeQuery, SafeDispatch}
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.RateLimiter
  alias OGrupoDeEstudos.Repo

  @doc """
  Toggles a like for the given user on a likeable entity.

  Returns `{:ok, :liked}` when a new like is created,
  or `{:ok, :unliked}` when an existing like is removed.
  """
  def toggle_like(user_id, likeable_type, likeable_id) do
    with :ok <- RateLimiter.check("like", user_id, limit: 20, window_seconds: 10) do
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
            safe_notify_like(user_id, likeable_type, likeable_id)
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

  # Emits the ephemeral activity toast (step likes only).
  defp safe_dispatch_like(user_id, "step", likeable_id) do
    SafeDispatch.run(fn ->
      case Repo.get(Step, likeable_id) do
        nil ->
          :ok

        step ->
          user = Repo.get!(User, user_id)
          ActivityBroadcaster.broadcast_activity(user, :liked_step, %{step_name: step.name})
      end
    end)
  end

  defp safe_dispatch_like(_user_id, _likeable_type, _likeable_id) do
    # Non-step likes do not broadcast activity toasts
    :ok
  end

  # Persists a notification for the like recipient (step/sequence/comment owner).
  defp safe_notify_like(user_id, likeable_type, likeable_id) do
    SafeDispatch.run(fn -> Dispatcher.notify_like(user_id, likeable_type, likeable_id) end)
  end
end
