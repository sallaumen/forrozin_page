defmodule OGrupoDeEstudos.Workshops.TeacherQuery do
  @moduledoc "Leituras de quem dá a aula."

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.WorkshopTeacher

  @doc """
  Quem dá a aula, na ordem em que quem organiza colocou.

  Devolve a mesma forma de mapa para conta e para nome escrito, para a tela
  não precisar saber a diferença: quem não tem conta vem sem `username` e sem
  foto, e é só isso que muda.
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

  @doc "Ids de workshop em que a pessoa consta como quem dá a aula."
  @spec workshop_ids_for_user(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def workshop_ids_for_user(user_id) do
    from(t in WorkshopTeacher, where: t.user_id == ^user_id, select: t.workshop_id)
    |> Repo.all()
  end

  @doc "Apaga todos os professores do workshop (usado antes de regravar a lista)."
  @spec delete_all(Ecto.UUID.t()) :: {non_neg_integer(), nil}
  def delete_all(workshop_id) do
    from(t in WorkshopTeacher, where: t.workshop_id == ^workshop_id) |> Repo.delete_all()
  end
end
