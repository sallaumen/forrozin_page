defmodule OGrupoDeEstudos.Study.LessonSequence do
  @moduledoc "A sequence cited by a teacher lesson. Mirrors `LessonStep`."

  use Ecto.Schema

  import Ecto.Changeset

  alias OGrupoDeEstudos.Sequences.Sequence
  alias OGrupoDeEstudos.Study.Lesson

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "lesson_sequences" do
    belongs_to :lesson, Lesson
    belongs_to :sequence, Sequence

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(lesson_sequence, attrs) do
    lesson_sequence
    |> cast(attrs, [:lesson_id, :sequence_id])
    |> validate_required([:lesson_id, :sequence_id])
    |> unique_constraint([:lesson_id, :sequence_id])
  end
end
