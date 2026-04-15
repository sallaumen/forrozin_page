defmodule OGrupoDeEstudos.Encyclopedia.StepLink do
  @moduledoc "Represents a user-submitted external link for a step."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "step_links" do
    field :url, :string
    field :title, :string
    field :approved, :boolean, default: false
    field :deleted_at, :naive_datetime

    belongs_to :step, OGrupoDeEstudos.Encyclopedia.Step
    belongs_to :submitted_by, OGrupoDeEstudos.Accounts.User, foreign_key: :submitted_by_id

    timestamps()
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [:url, :title, :step_id, :submitted_by_id, :approved, :deleted_at])
    |> validate_required([:url, :step_id, :submitted_by_id])
    |> validate_format(:url, ~r/^https?:\/\//, message: "must start with http:// or https://")
    |> validate_length(:url, max: 500)
    |> validate_length(:title, max: 200)
    |> foreign_key_constraint(:step_id)
    |> foreign_key_constraint(:submitted_by_id)
  end
end
