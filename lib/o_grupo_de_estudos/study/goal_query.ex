defmodule OGrupoDeEstudos.Study.GoalQuery do
  @moduledoc "Query module for study `Goal`."

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Study.{Goal, TeacherStudentLink}

  @doc "Personal goals of a user: open first, then by position, newest first."
  @spec list_personal(Ecto.UUID.t()) :: [Goal.t()]
  def list_personal(user_id) do
    Goal
    |> where([g], g.owner_user_id == ^user_id)
    |> apply_default_order()
    |> Repo.all()
  end

  @doc "Shared goals of a link: open first, then by position, newest first."
  @spec list_shared(Ecto.UUID.t()) :: [Goal.t()]
  def list_shared(link_id) do
    Goal
    |> where([g], g.teacher_student_link_id == ^link_id)
    |> apply_default_order()
    |> Repo.all()
  end

  @doc """
  Returns the goal only if the user may touch it: personal owner, or member
  (teacher/student) of the link the goal belongs to. Otherwise `nil`.
  """
  @spec get_authorized(Ecto.UUID.t(), Ecto.UUID.t()) :: Goal.t() | nil
  def get_authorized(goal_id, user_id) do
    member_link_ids =
      from(l in TeacherStudentLink,
        where: l.teacher_id == ^user_id or l.student_id == ^user_id,
        select: l.id
      )

    from(g in Goal,
      where:
        g.id == ^goal_id and
          (g.owner_user_id == ^user_id or
             g.teacher_student_link_id in subquery(member_link_ids))
    )
    |> Repo.one()
  end

  defp apply_default_order(query) do
    order_by(query, [g], asc: g.completed, asc: g.position, desc: g.inserted_at)
  end
end
