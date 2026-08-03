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
  alias OGrupoDeEstudos.Workshops.Workshop

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

  @doc """
  Agenda pública: só publicados, com organizador carregado.
  Ordena por data de início (mais próximo primeiro), ou decrescente no passado.
  """
  @spec list_feed(opts()) :: [Workshop.t()]
  def list_feed(opts \\ []) do
    period = Keyword.get(opts, :period, :upcoming)

    Workshop
    |> where([w], w.status == :published)
    |> apply_period(period, Keyword.get(opts, :now, DateTime.utc_now()))
    |> apply_search(opts[:search])
    |> order_for(period)
    |> maybe_limit(opts[:limit])
    |> preload(:organizer)
    |> Repo.all()
  end

  @doc "Workshops de um organizador, inclusive rascunho e cancelado."
  @spec list_for_organizer(Ecto.UUID.t()) :: [Workshop.t()]
  def list_for_organizer(organizer_id) do
    Workshop
    |> where([w], w.organizer_id == ^organizer_id)
    |> order_by([w], desc: w.starts_at)
    |> preload(:organizer)
    |> Repo.all()
  end

  # ── filtros ───────────────────────────────────────────────────────────

  defp apply_period(query, :upcoming, now), do: where(query, [w], w.starts_at >= ^now)
  defp apply_period(query, :past, now), do: where(query, [w], w.starts_at < ^now)

  defp apply_period(query, period, now) when period in [:week, :month, :year] do
    {from, to} = Brazil.range_utc(period, now |> Brazil.to_local() |> DateTime.to_date())

    # Sobreposição de intervalos, não só o início: um workshop que começa em
    # 30/01 e termina em 02/02 pertence aos dois meses.
    where(
      query,
      [w],
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
