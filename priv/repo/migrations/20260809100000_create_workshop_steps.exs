defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshopSteps do
  use Ecto.Migration

  # Nao existia relacao nenhuma entre workshop e passo do acervo: o diario era
  # o unico lugar do app onde passo encontrava data. Quem saia de um workshop
  # com cinco passos na cabeca nao tinha onde registrar isso.
  #
  # Quem administra o workshop monta a lista. Curadoria por like foi
  # considerada e descartada: ordenar por voto resolve, com muito mais peca, um
  # problema que a permissao ja resolve.
  def change do
    create table(:workshop_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workshop_id, references(:workshops, type: :binary_id, on_delete: :delete_all),
        null: false

      add :step_id, references(:steps, type: :binary_id, on_delete: :delete_all), null: false
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:workshop_steps, [:workshop_id, :step_id])
    # Le-se sempre por workshop, na ordem em que quem da a aula montou.
    create index(:workshop_steps, [:workshop_id, :position])
    # E o caminho de volta: "onde eu vi este passo?"
    create index(:workshop_steps, [:step_id])
  end
end
