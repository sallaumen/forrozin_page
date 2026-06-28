defmodule OGrupoDeEstudos.Repo.Migrations.CreateStudyActiveDays do
  use Ecto.Migration

  # Um registro por (usuario, dia) marcando que a pessoa abriu o app naquele dia.
  # Alimenta a consistencia: o dia conta mesmo sem registro de diario.
  def change do
    create table(:study_active_days, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :day, :date, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:study_active_days, [:user_id, :day])
  end
end
