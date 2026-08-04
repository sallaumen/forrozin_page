defmodule OGrupoDeEstudos.Repo.Migrations.AddAddressToWorkshops do
  use Ecto.Migration

  # `location` stays, and its meaning narrows to the name of the place ("Telhado
  # do Tatá"). Rows written before this keep the whole address in there, so the
  # display falls back to it when nothing structured exists. No backfill here:
  # migrations only change shape.
  def change do
    alter table(:workshops) do
      add :street, :string
      add :street_number, :string
      add :complement, :string
      add :neighborhood, :string
      add :city, :string
      add :state, :string
      add :postal_code, :string
    end
  end
end
