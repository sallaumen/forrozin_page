defmodule OGrupoDeEstudos.Repo.Migrations.AddEnrollmentRemindedAt do
  use Ecto.Migration

  # Marca de que o aviso de vespera ja saiu. Roda duas vezes no mesmo dia e
  # ninguem recebe duas. Coluna em vez de unique do Oban porque e dado
  # inspecionavel: da para responder "por que fulano nao recebeu?".
  def change do
    alter table(:workshop_enrollments) do
      add :reminded_at, :utc_datetime
    end

    create_if_not_exists index(:workshop_enrollments, [:reminded_at])
  end
end
