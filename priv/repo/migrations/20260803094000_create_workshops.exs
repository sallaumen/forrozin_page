defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshops do
  use Ecto.Migration

  def change do
    create table(:workshops, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :organizer_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :slug, :string, null: false
      add :title, :string, null: false
      add :description, :text, null: false
      add :location, :string
      add :starts_at, :utc_datetime, null: false
      add :ends_at, :utc_datetime
      # nulo = gratuito; em centavos, para nunca fazer conta com float
      add :price_cents, :integer
      add :payment_info, :string
      # nulo = sem limite de vagas
      add :capacity, :integer
      add :status, :string, null: false, default: "draft"

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:workshops, [:slug])
    # A agenda ordena e filtra por data dentro de um status; o índice composto
    # cobre o caminho quente da listagem pública.
    create_if_not_exists index(:workshops, [:status, :starts_at])
    create_if_not_exists index(:workshops, [:organizer_id, :starts_at])

    create table(:workshop_enrollments, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workshop_id, references(:workshops, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Privado do organizador: nunca sai numa query pública.
      add :payment_status, :string, null: false, default: "pending"
      add :paid_at, :utc_datetime

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:workshop_enrollments, [:workshop_id, :user_id])
    create_if_not_exists index(:workshop_enrollments, [:user_id])
  end
end
