defmodule Forrozin.Engagement do
  @moduledoc """
  Context for user engagement features: likes, feedback, page visits.
  """

  alias Forrozin.Repo
  alias Forrozin.Engagement.{Like, LikeQuery, ProfileComment, ProfileCommentQuery}

  @doc """
  Toggles a like for the given user on a likeable entity.

  Returns `{:ok, :liked}` when a new like is created,
  or `{:ok, :unliked}` when an existing like is removed.
  """
  def toggle_like(user_id, likeable_type, likeable_id) do
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
          {:ok, _} -> {:ok, :liked}
          error -> error
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

  @doc """
  Returns active (non-deleted) comments on a user's profile, newest first.

  Accepts the same options as `ProfileCommentQuery.list_by/1`.
  """
  def list_profile_comments(opts \\ []) do
    ProfileCommentQuery.list_by(opts)
  end

  @doc """
  Posts a new comment on a user's profile.

  Returns `{:ok, comment}` or `{:error, changeset}`.
  """
  def create_profile_comment(attrs) do
    %ProfileComment{}
    |> ProfileComment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Soft-deletes a profile comment by setting `deleted_at` to now.

  Returns `{:ok, comment}` or `{:error, changeset}`.
  """
  def delete_profile_comment(comment) do
    utc_now = NaiveDateTime.utc_now()
    now = NaiveDateTime.truncate(utc_now, :second)

    comment
    |> Ecto.Changeset.change(deleted_at: now)
    |> Repo.update()
  end
end
