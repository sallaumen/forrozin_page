defmodule OGrupoDeEstudos.Study.Lesson do
  @moduledoc """
  Lesson written by a teacher for the class (workshop content, for instance).

  The content lives here once; the delivery to each student is a
  `LessonDelivery` tied to the teacher-student link, so the lesson shows up on
  each student's shared page and one edit fixes every copy at once.
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
