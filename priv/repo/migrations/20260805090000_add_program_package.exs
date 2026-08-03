defmodule OGrupoDeEstudos.Repo.Migrations.AddProgramPackage do
  use Ecto.Migration

  # Preco de pacote: "os tres dias por R$150". Convive com o preco avulso de
  # cada workshop, entao no mesmo evento pode haver quem pagou o pacote e quem
  # paga cada dia. A inscricao no pacote agrupa as inscricoes de workshop.
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

    # Quando presente, o pagamento daquele workshop esta coberto pelo pacote.
    alter table(:workshop_enrollments) do
      add :program_enrollment_id,
          references(:program_enrollments, type: :binary_id, on_delete: :nilify_all)
    end

    create_if_not_exists index(:workshop_enrollments, [:program_enrollment_id])
  end
end
