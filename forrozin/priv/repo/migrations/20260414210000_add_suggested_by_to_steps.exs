defmodule Forrozin.Repo.Migrations.AddSuggestedByToSteps do
  use Ecto.Migration

  def change do
    alter table(:steps) do
      add :suggested_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:steps, [:suggested_by_id])
  end
end
