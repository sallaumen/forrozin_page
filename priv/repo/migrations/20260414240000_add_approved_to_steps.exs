defmodule Forrozin.Repo.Migrations.AddApprovedToSteps do
  use Ecto.Migration

  def change do
    alter table(:steps) do
      add :approved, :boolean, default: false, null: false
    end

    # All existing steps are official (approved)
    execute "UPDATE steps SET approved = true"

    # Steps with suggested_by_id that were set to nil (already approved)
    # are already covered by the line above
  end
end
