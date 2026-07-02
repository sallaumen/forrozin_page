defmodule OGrupoDeEstudos.Accounts.UserQuery do
  @moduledoc """
  Query module for the User schema.

  Owns the query-built reads of the Accounts context (search, sitemap
  usernames, batch summaries). Single-row `Repo.get_by` lookups stay in
  the context.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Repo

  @doc """
  Searches users by username or name (case-insensitive), up to 5 results,
  ordered by username. Accepts `exclude_id:`.
  """
  @spec search(String.t(), [{:exclude_id, Ecto.UUID.t()}]) :: [User.t()]
  def search(term, opts \\ []) do
    term
    |> base_search_query()
    |> exclude_id(opts[:exclude_id])
    |> order_by([u], asc: u.username)
    |> limit(5)
    |> Repo.all()
  end

  @doc """
  Searches teachers by name or username, up to 8 results, ordered by name,
  projected as lightweight maps. Accepts `exclude_id:`.
  """
  @spec search_teachers(String.t(), [{:exclude_id, Ecto.UUID.t()}]) :: [map()]
  def search_teachers(term, opts \\ []) do
    term
    |> base_search_query()
    |> where([u], u.is_teacher == true)
    |> exclude_id(opts[:exclude_id])
    |> order_by([u], asc: u.name)
    |> limit(8)
    |> select([u], %{id: u.id, name: u.name, username: u.username, city: u.city, state: u.state})
    |> Repo.all()
  end

  @doc "Every username, ordered (sitemap generation)."
  @spec list_usernames() :: [String.t()]
  def list_usernames do
    from(u in User, select: u.username, order_by: u.username)
    |> Repo.all()
  end

  @doc "Lightweight summaries (id, username, name, avatar) for the given ids."
  @spec summaries_by_ids([Ecto.UUID.t()]) :: [map()]
  def summaries_by_ids([]), do: []

  def summaries_by_ids(ids) when is_list(ids) do
    from(u in User,
      where: u.id in ^ids,
      select: %{id: u.id, username: u.username, name: u.name, avatar_path: u.avatar_path}
    )
    |> Repo.all()
  end

  defp base_search_query(term) do
    term_like = "%#{OGrupoDeEstudos.Search.escape_like(String.downcase(term))}%"
    where(User, [u], ilike(u.username, ^term_like) or ilike(u.name, ^term_like))
  end

  defp exclude_id(query, nil), do: query
  defp exclude_id(query, id), do: where(query, [u], u.id != ^id)
end
