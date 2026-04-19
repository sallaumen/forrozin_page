defmodule OGrupoDeEstudos.Media.CategoryPoseDefault do
  @moduledoc "Default animation poses for a category (fallback when step has no custom animation)."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "category_pose_defaults" do
    field :keyframes, {:array, :map}
    field :duration_ms, :integer, default: 2000

    belongs_to :category, OGrupoDeEstudos.Encyclopedia.Category

    timestamps()
  end

  def changeset(pose_default, attrs) do
    pose_default
    |> cast(attrs, [:category_id, :keyframes, :duration_ms])
    |> validate_required([:category_id, :keyframes])
    |> validate_number(:duration_ms, greater_than: 0)
    |> unique_constraint(:category_id)
  end
end
