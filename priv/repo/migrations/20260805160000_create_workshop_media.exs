defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshopMedia do
  use Ecto.Migration

  # Workshop gallery: photos and video from whoever was there.
  #
  # storage_key is opaque and does NOT sit in the public folder: media of a paid
  # workshop is restricted to whoever enrolled, so it is served by a controller with
  # permission, never by Plug.Static.
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
      # Media from a workshop admin comes first, marked.
      add :official, :boolean, null: false, default: false
      add :caption, :string
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:workshop_media, [:workshop_id, :official, :inserted_at])
    create_if_not_exists index(:workshop_media, [:uploaded_by_id])
  end
end
