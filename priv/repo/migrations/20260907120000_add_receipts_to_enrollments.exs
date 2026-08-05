defmodule OGrupoDeEstudos.Repo.Migrations.AddReceiptsToEnrollments do
  use Ecto.Migration

  # The receipt lives on the enrollment, next to `payment_status`, because that is
  # its lifecycle: it arrives while the payment is pending and stops mattering
  # once whoever runs the class confirms it.
  #
  # `whatsapp_opened_at` only exists on the workshop: it is where the WhatsApp
  # button lives. It answers "how many people chose that path" without counting
  # the same person twice, which a plain counter would.
  def change do
    alter table(:workshop_enrollments) do
      add :receipt_key, :string
      add :receipt_content_type, :string
      add :receipt_byte_size, :bigint
      add :receipt_sent_at, :utc_datetime
      add :whatsapp_opened_at, :utc_datetime
    end

    alter table(:program_enrollments) do
      add :receipt_key, :string
      add :receipt_content_type, :string
      add :receipt_byte_size, :bigint
      add :receipt_sent_at, :utc_datetime
    end
  end
end
