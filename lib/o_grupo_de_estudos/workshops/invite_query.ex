defmodule OGrupoDeEstudos.Workshops.InviteQuery do
  @moduledoc "Leituras de `WorkshopInvite`."

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.{Workshop, WorkshopInvite}

  @doc "Convidados com dados de exibição, mais antigo primeiro."
  @spec list_for_workshop(Ecto.UUID.t()) :: [map()]
  def list_for_workshop(workshop_id) do
    from(i in WorkshopInvite,
      join: u in assoc(i, :user),
      where: i.workshop_id == ^workshop_id,
      order_by: [asc: i.inserted_at],
      select: %{
        id: i.id,
        user_id: u.id,
        name: u.name,
        username: u.username,
        invited_at: i.inserted_at
      }
    )
    |> Repo.all()
  end

  @doc "true quando a pessoa foi convidada para este workshop."
  @spec invited?(Ecto.UUID.t(), Ecto.UUID.t()) :: boolean()
  def invited?(workshop_id, user_id) do
    from(i in WorkshopInvite, where: i.workshop_id == ^workshop_id and i.user_id == ^user_id)
    |> Repo.exists?()
  end

  @doc "Ids dos workshops privados para os quais a pessoa foi convidada."
  @spec invited_workshop_ids(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def invited_workshop_ids(user_id) do
    from(i in WorkshopInvite, where: i.user_id == ^user_id, select: i.workshop_id)
    |> Repo.all()
  end

  @doc "Tira o convite. `{:error, :not_found}` quando não existe."
  @spec delete(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, WorkshopInvite.t()} | {:error, :not_found}
  def delete(workshop_id, user_id) do
    case Repo.get_by(WorkshopInvite, workshop_id: workshop_id, user_id: user_id) do
      nil -> {:error, :not_found}
      convite -> Repo.delete(convite)
    end
  end

  @doc "Ids de workshops privados, para excluir da agenda pública."
  @spec private_workshop_ids() :: Ecto.Query.t()
  def private_workshop_ids do
    from(w in Workshop, where: w.visibility == :private, select: w.id)
  end
end
