defmodule OGrupoDeEstudos.Repo.Migrations.AddWorkshopPaymentMode do
  use Ecto.Migration

  # "How people pay" was a free text field, and free text is nothing the system can
  # use: it cannot show the right way to pay, nor offer the receipt shortcut. Now the
  # WHEN is a choice between two options, and whoever pays on signup has a
  # destination phone number.
  #
  # `payment_info` stays, in another role: it stops carrying the when and carries
  # only the Pix key or an extra instruction.
  #
  # No backfill: production has no workshop at all. The dev rows keep a null mode,
  # which the screen already treats as "arranged with the organizer".
  # o modo nulo, que a tela ja trata como "combinado com quem organiza".
  def change do
    alter table(:workshops) do
      add :payment_mode, :string
      add :payment_phone, :string
    end
  end
end
