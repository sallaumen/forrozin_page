defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshopAdmins do
  use Ecto.Migration

  # Co-organizadores. O `organizer_id` do workshop continua sendo o criador e
  # dono raiz: troca-lo por linhas nesta tabela quebraria o preload(:organizer)
  # de quatro consultas, a busca por nome de professor e a UI inteira, e ainda
  # exigiria backfill. Aqui so entra quem foi promovido depois.
  def change do
    create table(:workshop_admins, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workshop_id, references(:workshops, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Quem promoveu. Se essa conta sumir, o vinculo continua valendo.
      add :invited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:workshop_admins, [:workshop_id, :user_id])
    create_if_not_exists index(:workshop_admins, [:user_id])
  end
end
