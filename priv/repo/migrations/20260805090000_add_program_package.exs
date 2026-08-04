defmodule OGrupoDeEstudos.Repo.Migrations.AddProgramPackage do
  use Ecto.Migration

  # Package price: "the three days for R$150". It coexists with the single price of
  # each workshop, so at the same event some people paid the package and others pay
  # per day. The package enrollment groups the workshop enrollments.
  def change do
    alter table(:workshop_programs) do
      add :price_cents, :integer
      add :payment_info, :string
    end

    create table(:program_enrollments, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :program_id, references(:workshop_programs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :payment_status, :string, null: false, default: "pending"
      add :paid_at, :utc_datetime

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:program_enrollments, [:program_id, :user_id])
    create_if_not_exists index(:program_enrollments, [:user_id])

    # When present, the payment of that workshop is covered by the package.
    alter table(:workshop_enrollments) do
      add :program_enrollment_id,
          references(:program_enrollments, type: :binary_id, on_delete: :nilify_all)
    end

    create_if_not_exists index(:workshop_enrollments, [:program_enrollment_id])
  end
end
