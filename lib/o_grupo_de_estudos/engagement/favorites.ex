defmodule OGrupoDeEstudos.Engagement.Favorites do
  @moduledoc """
  Favorites: toggling (with an auto-like on favorite), batch lookups for list
  pages, and listings of a user's favorited steps/sequences. Rate-limited like
  the other social actions; unfavoriting preserves the like.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias OGrupoDeEstudos.Encyclopedia.Step
  alias OGrupoDeEstudos.Engagement.{Favorite, Like, LikeQuery}
  alias OGrupoDeEstudos.RateLimiter
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Sequences.Sequence

  @doc """
  Toggles a favorite for the given user on a favoritable entity.

  When favoriting, also ensures a like exists (auto-like).
  When unfavoriting, the like is preserved.

  Returns `{:ok, :favorited}` or `{:ok, :unfavorited}`.
  """
  def toggle_favorite(user_id, favoritable_type, favoritable_id) do
    with :ok <- RateLimiter.check("favorite", user_id, limit: 20, window_seconds: 10) do
      do_toggle_favorite(user_id, favoritable_type, favoritable_id)
    end
  end

  defp do_toggle_favorite(user_id, favoritable_type, favoritable_id) do
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

  @doc """
  Garante (idempotente, sem rate limit) que um favorito e seu auto-like existam.

  Usado por `Engagement.Learnings`: marcar um passo como aprendido também o
  favorita, então a estrela aparece nas demais telas. Retorna
  `{:ok, :favorited | :already_favorited}` ou `{:error, changeset}`.
  """
  def ensure_favorited(user_id, favoritable_type, favoritable_id) do
    if favorited?(user_id, favoritable_type, favoritable_id) do
      {:ok, :already_favorited}
    else
      create_favorite_with_like(user_id, favoritable_type, favoritable_id)
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
end
