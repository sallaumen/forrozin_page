defmodule OGrupoDeEstudos.Workshops.AdminQuery do
  @moduledoc """
  Reads of `WorkshopAdmin`.

  The creator never shows up in these queries: they own the workshop through its
  `organizer_id`. `Workshops.admin_ids/1` is what joins the two.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.WorkshopAdmin

  @doc "Ids of the co-organizers (without the creator)."
  @spec co_admin_ids(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def co_admin_ids(workshop_id) do
    from(a in WorkshopAdmin, where: a.workshop_id == ^workshop_id, select: a.user_id)
    |> Repo.all()
  end

  @doc "Co-organizers with display data, oldest first."
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

  @doc "true when the user is a co-organizer (does not consider the creator)."
  @spec co_admin?(Ecto.UUID.t(), Ecto.UUID.t()) :: boolean()
  def co_admin?(workshop_id, user_id) do
    from(a in WorkshopAdmin,
      where: a.workshop_id == ^workshop_id and a.user_id == ^user_id
    )
    |> Repo.exists?()
  end

  @doc "Ids of the workshops where the person is a co-organizer."
  @spec workshop_ids_for(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def workshop_ids_for(user_id) do
    from(a in WorkshopAdmin, where: a.user_id == ^user_id, select: a.workshop_id)
    |> Repo.all()
  end

  @doc "Removes the link. Returns `{:error, :not_found}` when it does not exist."
  @spec delete(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, WorkshopAdmin.t()} | {:error, :not_found}
  def delete(workshop_id, user_id) do
    case Repo.get_by(WorkshopAdmin, workshop_id: workshop_id, user_id: user_id) do
      nil -> {:error, :not_found}
      admin -> Repo.delete(admin)
    end
  end
end
