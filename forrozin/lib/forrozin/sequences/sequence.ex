defmodule Forrozin.Sequences.Sequence do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sequences" do
    field :name, :string
    field :allow_repeats, :boolean, default: false

    belongs_to :user, Forrozin.Accounts.User
    has_many :sequence_steps, Forrozin.Sequences.SequenceStep, preload_order: [asc: :position]

    timestamps()
  end

  def changeset(sequence, attrs) do
    sequence
    |> cast(attrs, [:name, :user_id, :allow_repeats])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 100)
    |> foreign_key_constraint(:user_id)
  end
end
