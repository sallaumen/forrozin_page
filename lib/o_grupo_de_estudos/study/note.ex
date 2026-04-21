defmodule OGrupoDeEstudos.Study.Note do
  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Encyclopedia.Step
  alias OGrupoDeEstudos.Study.{NoteStep, TeacherStudentLink}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @kinds ~w(personal shared)

  schema "study_notes" do
    field :kind, :string
    field :note_date, :date
    field :content, :string, default: ""

    belongs_to :owner_user, User
    belongs_to :teacher_student_link, TeacherStudentLink

    has_many :note_steps, NoteStep, foreign_key: :study_note_id

    many_to_many :related_steps, Step,
      join_through: NoteStep,
      join_keys: [study_note_id: :id, step_id: :id]

    timestamps()
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:kind, :note_date, :content, :owner_user_id, :teacher_student_link_id])
    |> put_default_content()
    |> validate_required([:kind, :note_date])
    |> validate_inclusion(:kind, @kinds)
    |> validate_length(:content, max: 50_000)
    |> validate_kind_scope()
    |> foreign_key_constraint(:owner_user_id)
    |> foreign_key_constraint(:teacher_student_link_id)
    |> unique_constraint([:owner_user_id, :note_date],
      name: :study_notes_personal_unique_index
    )
    |> unique_constraint([:teacher_student_link_id, :note_date],
      name: :study_notes_shared_unique_index
    )
  end

  defp validate_kind_scope(changeset) do
    case get_field(changeset, :kind) do
      "personal" ->
        changeset
        |> validate_required([:owner_user_id])
        |> put_change(:teacher_student_link_id, nil)

      "shared" ->
        changeset
        |> validate_required([:teacher_student_link_id])
        |> put_change(:owner_user_id, nil)

      _ ->
        changeset
    end
  end

  defp put_default_content(changeset) do
    case get_field(changeset, :content) do
      nil -> put_change(changeset, :content, "")
      _ -> changeset
    end
  end
end
