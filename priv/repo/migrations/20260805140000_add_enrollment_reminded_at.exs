defmodule OGrupoDeEstudos.Repo.Migrations.AddEnrollmentRemindedAt do
  use Ecto.Migration

  # Mark that the day-before reminder already went out. Run twice on the same day
  # and nobody gets two. A column instead of an Oban unique because it is
  # inspectable data: it can answer "why did this person not receive it?".
  def change do
    alter table(:workshop_enrollments) do
      add :reminded_at, :utc_datetime
    end

    create_if_not_exists index(:workshop_enrollments, [:reminded_at])
  end
end
