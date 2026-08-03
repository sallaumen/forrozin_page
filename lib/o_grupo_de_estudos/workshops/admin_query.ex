defmodule OGrupoDeEstudos.Workshops.AdminQuery do
  @moduledoc """
  Leituras de `WorkshopAdmin`.

  O criador nunca aparece nestas consultas: ele é dono pelo `organizer_id` do
  próprio workshop. Quem junta os dois é `Workshops.admin_ids/1`.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.WorkshopAdmin

  @doc "Ids dos co-organizadores (sem o criador)."
  @spec co_admin_ids(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def co_admin_ids(workshop_id) do
    from(a in WorkshopAdmin, where: a.workshop_id == ^workshop_id, select: a.user_id)
    |> Repo.all()
  end

  @doc "Co-organizadores com os dados de exibição, mais antigo primeiro."
  @spec list_co_admins(Ecto.UUID.t()) :: [map()]
  def list_co_admins(workshop_id) do
    from(a in WorkshopAdmin,
      join: u in assoc(a, :user),
      where: a.workshop_id == ^workshop_id,
      order_by: [asc: a.inserted_at],
      select: %{
        id: a.id,
        user_id: u.id,
        name: u.name,
        username: u.username,
        avatar_path: u.avatar_path,
        added_at: a.inserted_at
      }
    )
    |> Repo.all()
  end

  @doc "true quando o usuário é co-organizador (não considera o criador)."
  @spec co_admin?(Ecto.UUID.t(), Ecto.UUID.t()) :: boolean()
  def co_admin?(workshop_id, user_id) do
    from(a in WorkshopAdmin,
      where: a.workshop_id == ^workshop_id and a.user_id == ^user_id
    )
    |> Repo.exists?()
  end

  @doc "Ids dos workshops em que a pessoa é co-organizadora."
  @spec workshop_ids_for(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def workshop_ids_for(user_id) do
    from(a in WorkshopAdmin, where: a.user_id == ^user_id, select: a.workshop_id)
    |> Repo.all()
  end

  @doc "Remove o vínculo. Devolve `{:error, :not_found}` quando não existe."
  @spec delete(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, WorkshopAdmin.t()} | {:error, :not_found}
  def delete(workshop_id, user_id) do
    case Repo.get_by(WorkshopAdmin, workshop_id: workshop_id, user_id: user_id) do
      nil -> {:error, :not_found}
      admin -> Repo.delete(admin)
    end
  end
end
