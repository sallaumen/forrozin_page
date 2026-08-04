defmodule OGrupoDeEstudos.Workshops.WorkshopQuery do
  @moduledoc """
  Leituras de `Workshop`.

  A agenda pública combina três filtros independentes (período, busca e
  status) sobre a mesma consulta base, no padrão de reducer de opts do
  projeto.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Brazil
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Search
  alias OGrupoDeEstudos.Workshops.{AdminQuery, Workshop, WorkshopProgram}

  @type period :: :upcoming | :past | :week | :month | :year
  @type opt ::
          {:period, period()}
          | {:search, String.t()}
          | {:status, :draft | :published | :cancelled}
          | {:organizer_id, Ecto.UUID.t()}
          | {:limit, pos_integer()}
  @type opts :: [opt()]

  @doc "Workshop por slug, com o organizador carregado."
  @spec get_by_slug(String.t()) :: Workshop.t() | nil
  def get_by_slug(slug) when is_binary(slug) do
    Workshop
    |> where([w], w.slug == ^slug)
    |> preload(:organizer)
    |> Repo.one()
  end

  @doc "Workshop por id, com o organizador carregado."
  @spec get(Ecto.UUID.t()) :: Workshop.t() | nil
  def get(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Workshop |> where([w], w.id == ^uuid) |> preload(:organizer) |> Repo.one()
      :error -> nil
    end
  end

  @doc "Id do organizador, sem carregar o workshop inteiro."
  @spec organizer_id(Ecto.UUID.t()) :: Ecto.UUID.t() | nil
  def organizer_id(workshop_id) do
    case Ecto.UUID.cast(workshop_id) do
      {:ok, uuid} -> Repo.one(from w in Workshop, where: w.id == ^uuid, select: w.organizer_id)
      :error -> nil
    end
  end

  @doc "Lote `id => %{slug, title}`, para montar link de notificação sem N+1."
  @spec slugs_by_ids([Ecto.UUID.t()]) :: %{
          Ecto.UUID.t() => %{slug: String.t(), title: String.t()}
        }
  def slugs_by_ids([]), do: %{}

  def slugs_by_ids(ids) do
    from(w in Workshop,
      where: w.id in ^ids,
      select: {w.id, %{slug: w.slug, title: w.title}}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Agenda pública: só publicados, com organizador carregado.
  Ordena por data de início (mais próximo primeiro), ou decrescente no passado.
  """
  @spec list_feed(opts()) :: [Workshop.t()]
  def list_feed(opts \\ []) do
    period = Keyword.get(opts, :period, :upcoming)

    # A private workshop enters the agenda with the rest: it is not secret, it just
    # has entry by approval. Hiding it would make the community look empty exactly
    # when there is a workshop happening.
    from(w in Workshop, as: :periodo)
    |> where([w], w.status == :published)
    |> in_period(period, Keyword.get(opts, :now, DateTime.utc_now()))
    |> apply_grouping(opts[:only_loose])
    |> apply_search(opts[:search])
    |> order_for(period)
    |> maybe_limit(opts[:limit])
    |> preload([:organizer, :program])
    |> Repo.all()
  end

  # A workshop inside a program does not show up loose on the agenda: a festival
  # with fifteen workshops would become fifteen lines repeating the same name.
  #
  # It only collapses while the program is PUBLISHED. While it is a draft (or
  # after it is cancelled) nobody sees its card, so hiding the workshop would drop
  # something already announced off the agenda.
  defp apply_grouping(query, true) do
    publicadas = from(p in WorkshopProgram, where: p.status == :published, select: p.id)

    where(query, [w], is_nil(w.program_id) or w.program_id not in subquery(publicadas))
  end

  defp apply_grouping(query, _outro), do: query

  @doc """
  Workshops que a pessoa administra, inclusive rascunho e cancelado.

  Inclui os que ela criou e aqueles em que foi promovida a co-organizadora:
  senão o co-organizador não veria o workshop na própria agenda.
  """
  @spec list_for_organizer(Ecto.UUID.t()) :: [Workshop.t()]
  def list_for_organizer(organizer_id) do
    tambem_admin = AdminQuery.workshop_ids_for(organizer_id)

    Workshop
    |> where([w], w.organizer_id == ^organizer_id or w.id in ^tambem_admin)
    |> order_by([w], desc: w.starts_at)
    |> preload(:organizer)
    |> Repo.all()
  end

  @doc """
  Filtra pelo período, sobre a consulta que tiver o binding `:periodo`.

  Publico porque a agenda de programação usa o mesmo critério: programação não
  tem data própria, ela entra na linha do tempo pelas datas dos workshops
  dela. Usa binding nomeado porque lá o workshop é a segunda tabela, não a
  primeira.
  """
  @spec in_period(Ecto.Query.t(), period(), DateTime.t()) :: Ecto.Query.t()
  def in_period(query, :upcoming, now), do: where(query, [periodo: w], w.starts_at >= ^now)
  def in_period(query, :past, now), do: where(query, [periodo: w], w.starts_at < ^now)

  def in_period(query, period, now) when period in [:week, :month, :year] do
    {from, to} = Brazil.range_utc(period, now |> Brazil.to_local() |> DateTime.to_date())

    # Interval overlap, not just the start: a workshop that begins on 30/01 and ends
    # on 02/02 belongs to both months.
    where(
      query,
      [periodo: w],
      w.starts_at <= ^to and coalesce(w.ends_at, w.starts_at) >= ^from
    )
  end

  defp apply_search(query, nil), do: query
  defp apply_search(query, ""), do: query

  defp apply_search(query, term) do
    like = "%#{Search.escape_like(String.downcase(String.trim(term)))}%"

    query
    |> join(:inner, [w], o in assoc(w, :organizer), as: :organizer)
    |> where(
      [w, organizer: o],
      fragment("lower(?) LIKE ?", w.title, ^like) or
        fragment("lower(?) LIKE ?", o.name, ^like) or
        fragment("lower(?) LIKE ?", o.username, ^like)
    )
  end

  defp order_for(query, :past), do: order_by(query, [w], desc: w.starts_at)
  defp order_for(query, _period), do: order_by(query, [w], asc: w.starts_at)

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, n), do: limit(query, ^n)
end
