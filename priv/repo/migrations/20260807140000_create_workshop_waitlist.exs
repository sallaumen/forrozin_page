defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshopWaitlist do
  use Ecto.Migration

  # Turma cheia deixa de ser beco sem saida: quem chega depois do limite entra
  # numa fila, e quem organiza passa a enxergar a demanda reprimida (fila
  # grande e sinal de que cabe abrir outra turma).
  #
  # Tabela propria, e nao um status em workshop_enrollments, de proposito:
  # dezenas de consultas contam inscritos, e uma linha "esperando" convivendo
  # com as inscricoes de verdade faria toda contagem mentir ate a ultima delas
  # ser corrigida.
  def change do
    create table(:workshop_waitlist_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workshop_id, references(:workshops, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    # A ordem da fila e a ordem de chegada: sem posicao guardada, que exigiria
    # renumerar todo mundo a cada saida.
    create unique_index(:workshop_waitlist_entries, [:workshop_id, :user_id])
    create index(:workshop_waitlist_entries, [:workshop_id, :inserted_at])
  end
end
