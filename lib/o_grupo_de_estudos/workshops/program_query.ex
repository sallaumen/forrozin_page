defmodule OGrupoDeEstudos.Workshops.ProgramQuery do
  @moduledoc """
  Reads of `WorkshopProgram`.

  The program dates are aggregated from its children, never read from a column.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Search
  alias OGrupoDeEstudos.Workshops.{Workshop, WorkshopProgram, WorkshopQuery}

  @doc "Program by slug, with the owner loaded."
  @spec get_by_slug(String.t()) :: WorkshopProgram.t() | nil
  def get_by_slug(slug) when is_binary(slug) do
    WorkshopProgram
    |> where([p], p.slug == ^slug)
    |> preload(:owner)
    |> Repo.one()
  end

  @doc "Program by id, with the owner loaded."
  @spec get(Ecto.UUID.t()) :: WorkshopProgram.t() | nil
  def get(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> WorkshopProgram |> where([p], p.id == ^uuid) |> preload(:owner) |> Repo.one()
      :error -> nil
    end
  end

  @doc """
  Workshops of the program, earliest to latest.

  A cancelled one stays in the list: whoever enrolled needs to see what happened.
  A draft stays out for whoever does not administer it.
  """
  @spec list_workshops(Ecto.UUID.t(), keyword()) :: [Workshop.t()]
  def list_workshops(program_id, opts \\ []) do
    Workshop
    |> where([w], w.program_id == ^program_id)
    |> filter_visible(Keyword.get(opts, :include_drafts, false))
    |> order_by([w], asc: w.starts_at)
    |> preload(:organizer)
    |> Repo.all()
  end

  defp filter_visible(query, true), do: query
  defp filter_visible(query, false), do: where(query, [w], w.status != :draft)

  @doc """
  Only the requested workshops that really belong to this program and accept
  enrollment. An id coming from the client is never trusted.
  """
  @spec workshops_scoped(Ecto.UUID.t(), [Ecto.UUID.t()]) :: [Workshop.t()]
  def workshops_scoped(_program_id, []), do: []

  def workshops_scoped(program_id, workshop_ids) do
    ids = Enum.filter(workshop_ids, &match?({:ok, _}, Ecto.UUID.cast(&1)))

    Workshop
    |> where([w], w.program_id == ^program_id and w.id in ^ids and w.status == :published)
    |> order_by([w], asc: w.id)
    |> Repo.all()
  end

  @doc """
  Published programs with a published workshop in the period, already carrying
  the aggregated summary (how many, and from when to when).

  A program with no published workshop does not show up: it has no date of its
  own, so it would have nowhere to land on the timeline.
  """
  @spec list_feed(keyword()) :: [{WorkshopProgram.t(), map()}]
  def list_feed(opts \\ []) do
    period = Keyword.get(opts, :period, :upcoming)
    now = Keyword.get(opts, :now, DateTime.utc_now())

    from(p in WorkshopProgram,
      join: w in Workshop,
      as: :periodo,
      on: w.program_id == p.id,
      where: p.status == :published and w.status == :published,
      group_by: p.id,
      select: {
        p,
        %{
          count: count(w.id),
          starts_at: type(min(w.starts_at), :utc_datetime),
          ends_at: type(max(coalesce(w.ends_at, w.starts_at)), :utc_datetime)
        }
      }
    )
    |> WorkshopQuery.in_period(period, now)
    |> apply_program_search(opts[:search])
    |> preload(:owner)
    |> Repo.all()
  end

  defp apply_program_search(query, nil), do: query
  defp apply_program_search(query, ""), do: query

  defp apply_program_search(query, term) do
    like = "%#{Search.escape_like(String.downcase(String.trim(term)))}%"

    query
    |> join(:inner, [p], o in assoc(p, :owner), as: :owner)
    |> where(
      [p, w, owner: o],
      fragment("lower(?) LIKE ?", p.title, ^like) or
        fragment("lower(?) LIKE ?", o.name, ^like) or
        fragment("lower(?) LIKE ?", o.username, ^like)
    )
  end

  @doc "Programs the person created, most recent first."
  @spec list_for_owner(Ecto.UUID.t()) :: [WorkshopProgram.t()]
  def list_for_owner(owner_id) do
    WorkshopProgram
    |> where([p], p.owner_id == ^owner_id)
    |> order_by([p], desc: p.inserted_at)
    |> preload(:owner)
    |> Repo.all()
  end

  @doc """
  Batch `program_id => %{count, starts_at, ends_at}`, aggregated from the children.

  Avoids N+1 on the agenda, where each program card needs the date range and how
  many workshops it holds.
  """
  @spec summaries_by_ids([Ecto.UUID.t()]) :: %{Ecto.UUID.t() => map()}
  def summaries_by_ids([]), do: %{}

  def summaries_by_ids(program_ids) do
    from(w in Workshop,
      where: w.program_id in ^program_ids and w.status == :published,
      group_by: w.program_id,
      select: {
        w.program_id,
        %{
          count: count(w.id),
          # type/2 is required: Ecto loses the type in the aggregate and would return
          # NaiveDateTime, which does not match the rest of the code (utc_datetime).
          starts_at: type(min(w.starts_at), :utc_datetime),
          ends_at: type(max(coalesce(w.ends_at, w.starts_at)), :utc_datetime)
        }
      }
    )
    |> Repo.all()
    |> Map.new()
  end
end
