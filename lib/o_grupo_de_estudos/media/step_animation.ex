defmodule OGrupoDeEstudos.Media.StepAnimation do
  @moduledoc "Animation keyframes for a specific step."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "step_animations" do
    field :keyframes, {:array, :map}
    field :duration_ms, :integer, default: 2000

    belongs_to :step, OGrupoDeEstudos.Encyclopedia.Step

    timestamps()
  end

  def changeset(animation, attrs) do
    animation
    |> cast(attrs, [:step_id, :keyframes, :duration_ms])
    |> validate_required([:step_id, :keyframes])
    |> validate_number(:duration_ms, greater_than: 0)
    |> unique_constraint(:step_id)
  end
end
