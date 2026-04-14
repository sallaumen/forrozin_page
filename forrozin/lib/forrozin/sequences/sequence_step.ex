defmodule Forrozin.Sequences.SequenceStep do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sequence_steps" do
    field :position, :integer

    belongs_to :sequence, Forrozin.Sequences.Sequence
    belongs_to :step, Forrozin.Encyclopedia.Step

    timestamps(updated_at: false)
  end

  def changeset(seq_step, attrs) do
    seq_step
    |> cast(attrs, [:position, :sequence_id, :step_id])
    |> validate_required([:position, :sequence_id, :step_id])
    |> unique_constraint([:sequence_id, :position])
    |> foreign_key_constraint(:step_id)
    |> foreign_key_constraint(:sequence_id)
  end
end
