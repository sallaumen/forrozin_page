defmodule OGrupoDeEstudos.Workshops.ProgramQuery do
  @moduledoc """
  Leituras de `WorkshopProgram`.

  As datas da programação são agregadas dos filhos, nunca lidas de coluna.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Search
  alias OGrupoDeEstudos.Workshops.{Workshop, WorkshopProgram, WorkshopQuery}

  @doc "Programação por slug, com dono carregado."
  @spec get_by_slug(String.t()) :: WorkshopProgram.t() | nil
  def get_by_slug(slug) when is_binary(slug) do
    WorkshopProgram
    |> where([p], p.slug == ^slug)
    |> preload(:owner)
    |> Repo.one()
  end

  @doc "Programação por id, com dono carregado."
  @spec get(Ecto.UUID.t()) :: WorkshopProgram.t() | nil
  def get(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> WorkshopProgram |> where([p], p.id == ^uuid) |> preload(:owner) |> Repo.one()
      :error -> nil
    end
  end

  @doc """
  Workshops da programação, do mais cedo ao mais tarde.

  Cancelado continua na lista: quem se inscreveu precisa ver o que houve.
  Rascunho fica de fora para quem não administra.
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
  Só os workshops pedidos que realmente estão nesta programação e aceitam
  inscrição. Id vindo do cliente nunca é confiado.
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
  Programações publicadas com workshop publicado no período, já com o resumo
  agregado (quantos e de quando a quando).

  Uma programação sem workshop publicado não aparece: ela não tem data
  própria, então não teria onde entrar na linha do tempo.
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

  @doc "Programações que a pessoa criou, mais recente primeiro."
  @spec list_for_owner(Ecto.UUID.t()) :: [WorkshopProgram.t()]
  def list_for_owner(owner_id) do
    WorkshopProgram
    |> where([p], p.owner_id == ^owner_id)
    |> order_by([p], desc: p.inserted_at)
    |> preload(:owner)
    |> Repo.all()
  end

  @doc """
  Lote `program_id => %{count, starts_at, ends_at}`, agregado dos filhos.

  Evita N+1 na agenda, onde cada card de programação precisa do intervalo de
  datas e de quantos workshops tem dentro.
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
          # type/2 obrigatorio: o Ecto perde o tipo no agregado e devolveria
          # NaiveDateTime, que nao casa com o resto do codigo (utc_datetime).
          starts_at: type(min(w.starts_at), :utc_datetime),
          ends_at: type(max(coalesce(w.ends_at, w.starts_at)), :utc_datetime)
        }
      }
    )
    |> Repo.all()
    |> Map.new()
  end
end
