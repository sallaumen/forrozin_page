defmodule OGrupoDeEstudos.Workshops.WorkshopStepQuery do
  @moduledoc "Leituras dos passos dados num workshop."

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.{WorkshopEnrollment, WorkshopStep}

  @doc "Os passos do workshop, na ordem em que quem dá a aula montou."
  @spec list_for_workshop(Ecto.UUID.t()) :: [map()]
  def list_for_workshop(workshop_id) do
    from(ws in WorkshopStep,
      join: s in assoc(ws, :step),
      where: ws.workshop_id == ^workshop_id,
      order_by: [asc: ws.position, asc: ws.inserted_at],
      select: %{id: ws.id, step_id: s.id, code: s.code, name: s.name}
    )
    |> Repo.all()
  end

  @doc "Próxima posição livre, para o passo novo entrar no fim da lista."
  @spec next_position(Ecto.UUID.t()) :: integer()
  def next_position(workshop_id) do
    from(ws in WorkshopStep,
      where: ws.workshop_id == ^workshop_id,
      select: coalesce(max(ws.position), -1)
    )
    |> Repo.one()
    |> Kernel.+(1)
  end

  @doc "Tira o passo do workshop. `{:error, :not_found}` quando não estava lá."
  @spec delete(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, WorkshopStep.t()} | {:error, :not_found}
  def delete(workshop_id, step_id) do
    case Repo.get_by(WorkshopStep, workshop_id: workshop_id, step_id: step_id) do
      nil -> {:error, :not_found}
      vinculo -> Repo.delete(vinculo)
    end
  rescue
    Ecto.Query.CastError -> {:error, :not_found}
  end

  @doc """
  Workshops onde ESTA pessoa viu este passo.

  Só conta workshop em que ela esteve (inscrita ou organizando): dizer "você
  viu" sobre uma aula que ela não fez seria mentira.
  """
  @spec where_user_saw(Ecto.UUID.t() | nil, Ecto.UUID.t()) :: [map()]
  def where_user_saw(nil, _step_id), do: []

  def where_user_saw(user_id, step_id) do
    from(ws in WorkshopStep,
      join: w in assoc(ws, :workshop),
      left_join: e in WorkshopEnrollment,
      on: e.workshop_id == w.id and e.user_id == ^user_id,
      where: ws.step_id == ^step_id,
      where: not is_nil(e.id) or w.organizer_id == ^user_id,
      order_by: [desc: w.starts_at],
      select: %{title: w.title, slug: w.slug, starts_at: w.starts_at}
    )
    |> Repo.all()
  rescue
    Ecto.Query.CastError -> []
  end

  @doc """
  Step ids this user saw across workshops they attended or organized, as a
  MapSet. Batch version of `where_user_saw/2` for the collection screen.
  """
  @spec step_ids_seen_by(Ecto.UUID.t() | nil) :: MapSet.t()
  def step_ids_seen_by(nil), do: MapSet.new()

  def step_ids_seen_by(user_id) do
    from(ws in WorkshopStep,
      join: w in assoc(ws, :workshop),
      left_join: e in WorkshopEnrollment,
      on: e.workshop_id == w.id and e.user_id == ^user_id,
      where: not is_nil(e.id) or w.organizer_id == ^user_id,
      select: ws.step_id,
      distinct: true
    )
    |> Repo.all()
    |> MapSet.new()
  rescue
    Ecto.Query.CastError -> MapSet.new()
  end
end
