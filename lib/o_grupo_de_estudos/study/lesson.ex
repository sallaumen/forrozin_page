defmodule OGrupoDeEstudos.Study.Lesson do
  @moduledoc """
  Lição escrita por um professor para a turma (ex.: conteúdo de workshop).

  O conteúdo vive aqui, uma única vez; a entrega a cada aluno é uma
  `LessonDelivery` ligada ao vínculo professor-aluno — assim a lição
  aparece na página compartilhada de cada aluno e uma edição corrige
  todas as cópias de uma vez.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Encyclopedia.Step
  alias OGrupoDeEstudos.Study.LessonStep

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "lessons" do
    field :title, :string
    field :content, :string

    belongs_to :teacher, OGrupoDeEstudos.Accounts.User
    has_many :deliveries, OGrupoDeEstudos.Study.LessonDelivery
    has_many :lesson_steps, LessonStep

    many_to_many :related_steps, Step,
      join_through: LessonStep,
      join_keys: [lesson_id: :id, step_id: :id]

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(lesson, attrs) do
    lesson
    |> cast(attrs, [:title, :content, :teacher_id])
    |> update_change(:title, &String.trim/1)
    |> update_change(:content, &String.trim/1)
    |> validate_required([:title, :content, :teacher_id])
    |> validate_length(:title, max: 120)
    |> validate_length(:content, max: 50_000)
    |> foreign_key_constraint(:teacher_id)
  end
end
