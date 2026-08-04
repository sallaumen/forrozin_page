defmodule OGrupoDeEstudos.Engagement.LearnedStep do
  @moduledoc """
  Record that a user marked a step as learned.

  Mirrors the `Favorite` and `Like` pattern, but is specific to steps (a real FK
  to `steps`). Marking as learned implies favoriting (see `Engagement.Learnings`),
  so the favorite star shows up on the other screens without duplicating the
  truth: `favorites` remains the source of "is a favorite".
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "learned_steps" do
    belongs_to :user, OGrupoDeEstudos.Accounts.User
    belongs_to :step, OGrupoDeEstudos.Encyclopedia.Step
    timestamps(updated_at: false)
  end

  def changeset(learned_step, attrs) do
    learned_step
    |> cast(attrs, [:user_id, :step_id])
    |> validate_required([:user_id, :step_id])
    |> unique_constraint([:user_id, :step_id])
  end
end
