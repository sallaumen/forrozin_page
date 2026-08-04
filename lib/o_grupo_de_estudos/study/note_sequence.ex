defmodule OGrupoDeEstudos.Study.NoteSequence do
  @moduledoc "A sequence cited by a diary note. Mirrors `NoteStep`."

  use Ecto.Schema

  import Ecto.Changeset

  alias OGrupoDeEstudos.Sequences.Sequence
  alias OGrupoDeEstudos.Study.Note

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "study_note_sequences" do
    belongs_to :study_note, Note
    belongs_to :sequence, Sequence

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(note_sequence, attrs) do
    note_sequence
    |> cast(attrs, [:study_note_id, :sequence_id])
    |> validate_required([:study_note_id, :sequence_id])
    |> unique_constraint([:study_note_id, :sequence_id])
  end
end
