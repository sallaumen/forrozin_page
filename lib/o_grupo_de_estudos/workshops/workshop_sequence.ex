defmodule OGrupoDeEstudos.Workshops.WorkshopSequence do
  @moduledoc """
  A sequence cited by a workshop.

  The sequence belongs to whoever built it, never to the class: only the teacher
  attaches one here, and a student takes it home by favoriting. Deleting the
  workshop drops the citation and leaves the sequence standing.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias OGrupoDeEstudos.Sequences.Sequence
  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_sequences" do
    belongs_to :workshop, Workshop
    belongs_to :sequence, Sequence

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(workshop_sequence, attrs) do
    workshop_sequence
    |> cast(attrs, [:workshop_id, :sequence_id])
    |> validate_required([:workshop_id, :sequence_id])
    |> unique_constraint([:workshop_id, :sequence_id])
    |> foreign_key_constraint(:sequence_id)
  end
end
