defmodule OGrupoDeEstudos.Study.LessonDelivery do
  @moduledoc """
  Entrega de uma lição a um vínculo professor-aluno.

  `read_at` marca quando o aluno abriu a lição — alimenta o
  "quem já leu" do professor e o badge "Nova" do aluno.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "lesson_deliveries" do
    field :read_at, :utc_datetime_usec

    belongs_to :lesson, OGrupoDeEstudos.Study.Lesson
    belongs_to :teacher_student_link, OGrupoDeEstudos.Study.TeacherStudentLink

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, [:lesson_id, :teacher_student_link_id])
    |> validate_required([:lesson_id, :teacher_student_link_id])
    |> foreign_key_constraint(:lesson_id)
    |> foreign_key_constraint(:teacher_student_link_id)
    |> unique_constraint([:lesson_id, :teacher_student_link_id])
  end
end
