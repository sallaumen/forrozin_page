defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshopPrograms do
  use Ecto.Migration

  # Programacao: um punhado de workshops sob um nome so (um fim de semana,
  # um festival). Workshop pertence a zero ou uma programacao.
  #
  # Sem starts_at/ends_at aqui de proposito: as datas da programacao sao o
  # min/max dos filhos, e coluna desnormalizada mente assim que um workshop e
  # remarcado ou cancelado.
  def change do
    create table(:workshop_programs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :owner_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :location, :string
      add :status, :string, null: false, default: "draft"

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:workshop_programs, [:slug])
    create_if_not_exists index(:workshop_programs, [:owner_id])

    # nilify_all: apagar a programacao solta os workshops, nao os destroi.
    alter table(:workshops) do
      add :program_id, references(:workshop_programs, type: :binary_id, on_delete: :nilify_all)
    end

    create_if_not_exists index(:workshops, [:program_id, :starts_at])
  end
end
