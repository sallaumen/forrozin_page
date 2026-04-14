defmodule Forrozin.Engagement do
  @moduledoc """
  Context for user engagement features: likes, feedback, page visits.
  """

  import Ecto.Query
  alias Forrozin.Repo
  alias Forrozin.Engagement.Like

  # ---------------------------------------------------------------------------
  # Likes
  # ---------------------------------------------------------------------------

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
    Repo.exists?(
      from l in Like,
        where:
          l.user_id == ^user_id and
            l.likeable_type == ^likeable_type and
            l.likeable_id == ^likeable_id
    )
  end

  @doc "Returns the total like count for a single entity."
  def count_likes(likeable_type, likeable_id) do
    Repo.aggregate(
      from(l in Like,
        where: l.likeable_type == ^likeable_type and l.likeable_id == ^likeable_id
      ),
      :count
    )
  end

  @doc """
  Returns a map with `:liked_ids` (MapSet) and `:counts` (map of id => count)
  for a batch of likeable_ids of the same type, for a given user.

  Useful for rendering like state on list pages without N+1 queries.
  """
  def likes_map(user_id, likeable_type, likeable_ids) do
    liked_ids =
      from(l in Like,
        where:
          l.user_id == ^user_id and
            l.likeable_type == ^likeable_type and
            l.likeable_id in ^likeable_ids,
        select: l.likeable_id
      )
      |> Repo.all()
      |> MapSet.new()

    counts =
      from(l in Like,
        where: l.likeable_type == ^likeable_type and l.likeable_id in ^likeable_ids,
        group_by: l.likeable_id,
        select: {l.likeable_id, count(l.id)}
      )
      |> Repo.all()
      |> Map.new()

    %{liked_ids: liked_ids, counts: counts}
  end
end
