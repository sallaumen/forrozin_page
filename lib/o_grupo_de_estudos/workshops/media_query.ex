defmodule OGrupoDeEstudos.Workshops.MediaQuery do
  @moduledoc """
  Reads of `WorkshopMedia`.

  The order is fixed: official first, then the community, each block from newest
  to oldest. It is what the product owner asked for, and it is what makes the
  teacher's video the first thing a person sees.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.WorkshopMedia

  @doc "Visible media of the workshop, official first."
  @spec list_for_workshop(Ecto.UUID.t()) :: [WorkshopMedia.t()]
  def list_for_workshop(workshop_id) do
    from(m in WorkshopMedia,
      where: m.workshop_id == ^workshop_id and is_nil(m.deleted_at),
      order_by: [desc: m.official, desc: m.inserted_at],
      preload: [:uploaded_by]
    )
    |> Repo.all()
  end

  @doc "One media scoped to the workshop: a forged id from another finds nothing."
  @spec get_scoped(Ecto.UUID.t(), Ecto.UUID.t()) :: WorkshopMedia.t() | nil
  def get_scoped(media_id, workshop_id) do
    case Ecto.UUID.cast(media_id) do
      {:ok, uuid} ->
        from(m in WorkshopMedia,
          where: m.id == ^uuid and m.workshop_id == ^workshop_id and is_nil(m.deleted_at)
        )
        |> Repo.one()

      :error ->
        nil
    end
  end

  @doc "Media by id, unscoped. For the controller that serves the file."
  @spec get(Ecto.UUID.t()) :: WorkshopMedia.t() | nil
  def get(media_id) do
    case Ecto.UUID.cast(media_id) do
      {:ok, uuid} -> Repo.get(WorkshopMedia, uuid)
      :error -> nil
    end
  end

  @doc "How many files and how many bytes the workshop already stores."
  @spec usage(Ecto.UUID.t()) :: %{count: non_neg_integer(), bytes: non_neg_integer()}
  def usage(workshop_id) do
    from(m in WorkshopMedia,
      where: m.workshop_id == ^workshop_id and is_nil(m.deleted_at),
      select: %{count: count(m.id), bytes: coalesce(sum(m.byte_size), 0)}
    )
    |> Repo.one()
  end
end
