defmodule OGrupoDeEstudos.Repo.Migrations.NormalizeNotificationActions do
  use Ecto.Migration

  # Corrective data migration (small and indexed, not a backfill):
  # Notification.action becomes an Ecto.Enum and an old row with an action outside
  # the known set would break the load. The Fly release_command runs migrations
  # BEFORE the rollout, so the data is clean before the new code serves.
  # Notifications with an unknown action were already unroutable in the UI;
  # removing them is the fix.

  @known_actions ~w(replied_comment liked_comment liked_step liked_sequence
                    followed_user study_request study_accepted study_nudge
                    shared_note_updated suggestion_created suggestion_approved
                    suggestion_rejected)

  def up do
    placeholders = @known_actions |> Enum.map(&"'#{&1}'") |> Enum.join(", ")

    %{num_rows: removed} =
      repo().query!("DELETE FROM notifications WHERE action NOT IN (#{placeholders})")

    IO.puts("NormalizeNotificationActions: #{removed} notificações com action legado removidas")
  end

  def down do
    # No down: removing unroutable rows is neither reversible nor needs to be.
    :ok
  end
end
