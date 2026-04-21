defmodule OGrupoDeEstudos.Study.TeacherStudentLink do
  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Study.Note

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "teacher_student_links" do
    field :active, :boolean, default: true
    field :ended_at, :utc_datetime_usec

    belongs_to :teacher, User
    belongs_to :student, User

    has_many :notes, Note

    timestamps()
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [:teacher_id, :student_id, :active, :ended_at])
    |> validate_required([:teacher_id, :student_id])
    |> validate_teacher_student_difference()
    |> foreign_key_constraint(:teacher_id)
    |> foreign_key_constraint(:student_id)
    |> unique_constraint([:teacher_id, :student_id])
  end

  defp validate_teacher_student_difference(changeset) do
    teacher_id = get_field(changeset, :teacher_id)
    student_id = get_field(changeset, :student_id)

    if teacher_id && student_id && teacher_id == student_id do
      add_error(changeset, :student_id, "não pode vincular a si mesmo")
    else
      changeset
    end
  end
end
