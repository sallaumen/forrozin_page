defmodule OGrupoDeEstudos.Study.Goal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "study_goals" do
    field :body, :string
    field :completed, :boolean, default: false
    field :position, :integer, default: 0

    belongs_to :owner_user, OGrupoDeEstudos.Accounts.User
    belongs_to :teacher_student_link, OGrupoDeEstudos.Study.TeacherStudentLink

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [:body, :completed, :position, :owner_user_id, :teacher_student_link_id])
    |> validate_required([:body])
    |> validate_length(:body, max: 500)
  end
end
