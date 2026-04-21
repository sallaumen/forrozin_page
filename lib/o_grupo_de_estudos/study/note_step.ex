defmodule OGrupoDeEstudos.Study.NoteStep do
  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Encyclopedia.Step
  alias OGrupoDeEstudos.Study.Note

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "study_note_steps" do
    belongs_to :study_note, Note
    belongs_to :step, Step

    timestamps()
  end

  def changeset(note_step, attrs) do
    note_step
    |> cast(attrs, [:study_note_id, :step_id])
    |> validate_required([:study_note_id, :step_id])
    |> foreign_key_constraint(:study_note_id)
    |> foreign_key_constraint(:step_id)
    |> unique_constraint([:study_note_id, :step_id])
  end
end
