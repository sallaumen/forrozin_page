defmodule OGrupoDeEstudos.Repo.Migrations.InvitesViramPedidos do
  use Ecto.Migration

  # A private workshop stops being invisible and becomes "entry by approval": it
  # shows on the agenda like any other, and whoever wants in asks. The authorship of
  # the row flips (before the organizer invited; now the person asks) and that is
  # why the table changes name along with it: calling it an "invite" would make the
  # code lie.
  #
  # No backfill: production has no workshop at all, so there is no row to migrate.
  # The 'approved' default exists only so a dev row is not left without a status,
  # since an old invite was equivalent to granted access.
  # de status, ja que convite antigo equivalia a acesso concedido.
  def change do
    rename table(:workshop_invites), to: table(:workshop_join_requests)
    rename table(:workshop_join_requests), :invited_by_id, to: :reviewed_by_id

    alter table(:workshop_join_requests) do
      add :status, :string, null: false, default: "approved"
      add :reviewed_at, :utc_datetime
    end
  end
end
