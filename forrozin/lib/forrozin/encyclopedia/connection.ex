defmodule Forrozin.Encyclopedia.Connection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  alias Forrozin.Encyclopedia.Step

  @valid_types ["exit", "entry"]
  @required_fields [:source_step_id, :target_step_id, :type]
  @optional_fields [:label, :description]

  schema "step_connections" do
    field :type, :string
    field :label, :string
    field :description, :string

    belongs_to :source_step, Step, foreign_key: :source_step_id
    belongs_to :target_step, Step, foreign_key: :target_step_id

    timestamps()
  end

  def changeset(connection, attrs) do
    connection
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:type, @valid_types)
    |> unique_constraint([:source_step_id, :target_step_id, :type],
      name: :step_connections_source_step_id_target_step_id_type_index
    )
    |> foreign_key_constraint(:source_step_id)
    |> foreign_key_constraint(:target_step_id)
  end
end
