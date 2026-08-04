defmodule OGrupoDeEstudos.Study.LessonDelivery do
  @moduledoc """
  Delivery of a lesson to a teacher-student link.

  `read_at` marks when the student opened the lesson: it feeds the teacher's
  "who read it" and the student's "Nova" badge.
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
