defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshopMedia do
  use Ecto.Migration

  # Galeria do workshop: foto e video de quem esteve la.
  #
  # storage_key e opaco e NAO fica na pasta publica: midia de workshop pago e
  # restrita a quem se inscreveu, entao e servida por controller com permissao,
  # nunca pelo Plug.Static.
  def change do
    create table(:workshop_media, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workshop_id, references(:workshops, type: :binary_id, on_delete: :delete_all),
        null: false

      add :uploaded_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :kind, :string, null: false
      add :storage_key, :string, null: false
      add :content_type, :string, null: false
      add :byte_size, :integer, null: false
      add :poster_key, :string
      # Midia de quem administra o workshop aparece primeiro, marcada.
      add :official, :boolean, null: false, default: false
      add :caption, :string
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:workshop_media, [:workshop_id, :official, :inserted_at])
    create_if_not_exists index(:workshop_media, [:uploaded_by_id])
  end
end
