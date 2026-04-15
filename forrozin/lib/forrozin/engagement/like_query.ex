defmodule Forrozin.Engagement.LikeQuery do
  @moduledoc """
  Query module for the Like schema.

  Provides query helpers used by the Engagement context for checking and
  counting likes. All DB access in the Engagement context is delegated here.
  """

  import Ecto.Query

  alias Forrozin.Repo
  alias Forrozin.Engagement.Like

  @doc "Returns `true` if the user has liked the given entity."
  def exists?(user_id, likeable_type, likeable_id) do
    Repo.exists?(
      from l in Like,
        where:
          l.user_id == ^user_id and
            l.likeable_type == ^likeable_type and
            l.likeable_id == ^likeable_id
    )
  end

  @doc "Returns the total like count for a single entity."
  def count(likeable_type, likeable_id) do
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
  def batch_map(user_id, likeable_type, likeable_ids) do
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
