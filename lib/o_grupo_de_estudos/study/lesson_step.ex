defmodule OGrupoDeEstudos.Study.LessonStep do
  @moduledoc """
  Vínculo entre uma lição e um passo do acervo.

  Mesmo molde de `NoteStep`: o passo citado na lição deixa de ser palavra
  solta e vira caminho de volta para a folha do passo.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Encyclopedia.Step
  alias OGrupoDeEstudos.Study.Lesson

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "lesson_steps" do
    belongs_to :lesson, Lesson
    belongs_to :step, Step

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(lesson_step, attrs) do
    lesson_step
    |> cast(attrs, [:lesson_id, :step_id])
    |> validate_required([:lesson_id, :step_id])
    |> foreign_key_constraint(:lesson_id)
    |> foreign_key_constraint(:step_id)
    |> unique_constraint([:lesson_id, :step_id])
  end
end
