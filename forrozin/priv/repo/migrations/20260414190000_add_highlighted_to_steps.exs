defmodule Forrozin.Repo.Migrations.AddHighlightedToSteps do
  use Ecto.Migration

  def change do
    alter table(:steps) do
      add :highlighted, :boolean, default: false, null: false
    end

    # Set initial highlights based on current hub codes
    execute "UPDATE steps SET highlighted = true WHERE code IN ('BF', 'GS', 'GP', 'IV', 'SC', 'CM-F')"
  end
end
