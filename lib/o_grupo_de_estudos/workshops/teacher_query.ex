defmodule OGrupoDeEstudos.Workshops.TeacherQuery do
  @moduledoc "Reads of who teaches a workshop."

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.WorkshopTeacher

  @doc """
  Who teaches, in the order the organizer set.

  Returns the same map shape for an account and for a written name, so the screen
  does not have to know the difference: whoever has no account comes without
  `username` and without a photo, and that is all that changes.
  """
  @spec list_for_workshop(Ecto.UUID.t()) :: [map()]
  def list_for_workshop(workshop_id) do
    from(t in WorkshopTeacher,
      left_join: u in assoc(t, :user),
      where: t.workshop_id == ^workshop_id,
      order_by: [asc: t.position, asc: t.inserted_at],
      select: %{
        id: t.id,
        user_id: u.id,
        name: coalesce(u.name, t.display_name),
        username: u.username,
        avatar_path: u.avatar_path
      }
    )
    |> Repo.all()
  end

  @doc "Ids of the workshops where the person is listed as a teacher."
  @spec workshop_ids_for_user(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def workshop_ids_for_user(user_id) do
    from(t in WorkshopTeacher, where: t.user_id == ^user_id, select: t.workshop_id)
    |> Repo.all()
  end

  @doc "Deletes every teacher of the workshop (used before rewriting the list)."
  @spec delete_all(Ecto.UUID.t()) :: {non_neg_integer(), nil}
  def delete_all(workshop_id) do
    from(t in WorkshopTeacher, where: t.workshop_id == ^workshop_id) |> Repo.delete_all()
  end
end
