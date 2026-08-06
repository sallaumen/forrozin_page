defmodule OGrupoDeEstudos.Workshops.ProgramAdminQuery do
  @moduledoc """
  Reads of `ProgramAdmin`.

  The creator never shows up in these queries: they own the program through its
  `owner_id`. `Workshops.program_admin?/2` is what joins the two.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.ProgramAdmin

  @doc "Co-organizers with display data, oldest first."
  @spec list_co_admins(Ecto.UUID.t()) :: [map()]
  def list_co_admins(program_id) do
    from(a in ProgramAdmin,
      join: u in assoc(a, :user),
      where: a.program_id == ^program_id,
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
  def co_admin?(program_id, user_id) do
    from(a in ProgramAdmin, where: a.program_id == ^program_id and a.user_id == ^user_id)
    |> Repo.exists?()
  end

  @doc "Ids of the programs where the person is a co-organizer."
  @spec program_ids_for(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def program_ids_for(user_id) do
    from(a in ProgramAdmin, where: a.user_id == ^user_id, select: a.program_id)
    |> Repo.all()
  end

  @doc "Removes the link. Returns `{:error, :not_found}` when it does not exist."
  @spec delete(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, ProgramAdmin.t()} | {:error, :not_found}
  def delete(program_id, user_id) do
    case Repo.get_by(ProgramAdmin, program_id: program_id, user_id: user_id) do
      nil -> {:error, :not_found}
      admin -> Repo.delete(admin)
    end
  end
end
