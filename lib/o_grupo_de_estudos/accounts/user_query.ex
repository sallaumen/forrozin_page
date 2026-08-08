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

  @doc "Ids of every admin user."
  @spec admin_ids() :: [Ecto.UUID.t()]
  def admin_ids do
    from(u in User, where: u.role == :admin, select: u.id)
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

  @doc "Streams users whose stored email is not lowercase (email backfill)."
  @spec stream_mixed_case_emails() :: Enumerable.t()
  def stream_mixed_case_emails do
    from(u in User, where: u.email != fragment("lower(?)", u.email))
    |> Repo.stream()
  end

  @doc """
  Accounts born through Google sign-in before the cutoff (welcome backfill).

  A google-born account is confirmed in the same insert, so `confirmed_at`
  sits within seconds of `inserted_at`; an account that linked Google later
  was confirmed long after registering and stays out.
  """
  @spec list_google_registered_before(DateTime.t()) :: [User.t()]
  def list_google_registered_before(%DateTime{} = cutoff) do
    naive_cutoff = DateTime.to_naive(cutoff)

    from(u in User,
      where: not is_nil(u.google_id),
      where: is_nil(u.confirmation_token),
      where: u.confirmed_at >= datetime_add(u.inserted_at, -5, "second"),
      where: u.confirmed_at <= datetime_add(u.inserted_at, 5, "second"),
      where: u.inserted_at < ^naive_cutoff,
      order_by: [asc: u.inserted_at]
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
