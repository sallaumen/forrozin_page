defmodule OGrupoDeEstudos.Workshops.WorkshopStep do
  @moduledoc """
  Collection step that was taught in a workshop.

  The admin builds the list: like-based curation was considered and dropped,
  because ordering by vote solves, with much more machinery, a problem the
  permission already solves.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Encyclopedia.Step
  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_steps" do
    belongs_to :workshop, Workshop
    belongs_to :step, Step

    field :position, :integer, default: 0

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(workshop_step, attrs) do
    workshop_step
    |> cast(attrs, [:workshop_id, :step_id, :position])
    |> validate_required([:workshop_id, :step_id])
    |> unique_constraint([:workshop_id, :step_id])
    |> foreign_key_constraint(:workshop_id)
    |> foreign_key_constraint(:step_id)
  end
end
