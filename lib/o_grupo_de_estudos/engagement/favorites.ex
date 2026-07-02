defmodule OGrupoDeEstudos.Engagement.Favorites do
  @moduledoc """
  Favorites: toggling (with an auto-like on favorite), batch lookups for list
  pages, and listings of a user's favorited steps/sequences. Rate-limited like
  the other social actions; unfavoriting preserves the like.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Engagement.{Favorite, Like, LikeQuery}
  alias OGrupoDeEstudos.RateLimiter
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Sequences

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

  @doc "Returns the codes of every step the user has favorited (deleted excluded)."
  def step_codes_for(user_id) do
    user_id
    |> favorited_ids("step")
    |> Encyclopedia.step_summaries_by_ids()
    |> Map.values()
    |> Enum.map(& &1.code)
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
    user_id
    |> favorited_ids("step")
    |> resolve_in_order(&Encyclopedia.steps_by_ids/1)
  end

  def list_user_favorites(user_id, "sequence") do
    user_id
    |> favorited_ids("sequence")
    |> resolve_in_order(&Sequences.map_by_ids/1)
  end

  @doc "Ids favorited by the user for a type, most recently favorited first."
  def favorited_ids(user_id, favoritable_type) do
    from(f in Favorite,
      where: f.user_id == ^user_id and f.favoritable_type == ^favoritable_type,
      order_by: [desc: f.inserted_at],
      select: f.favoritable_id
    )
    |> Repo.all()
  end

  # Owning contexts drop deleted records; keep the favorited order.
  defp resolve_in_order(ids, batch_fetch) do
    records = batch_fetch.(ids)

    ids
    |> Enum.map(&records[&1])
    |> Enum.reject(&is_nil/1)
  end

  @doc "Returns the total count of favorites for the given user across all types."
  def count_user_favorites(user_id) do
    Repo.aggregate(
      from(f in Favorite, where: f.user_id == ^user_id),
      :count
    )
  end
end
