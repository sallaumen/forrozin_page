defmodule OGrupoDeEstudos.Workers.NotificationCleanupTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Workers.NotificationCleanup
  alias OGrupoDeEstudos.Repo

  describe "perform/1" do
    test "purges read notifications older than 90 days" do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      # Create a notification inserted 100 days ago and read (should be deleted)
      old_read_notification =
        insert(:notification,
          read_at: NaiveDateTime.add(now, -100, :day) |> NaiveDateTime.truncate(:second)
        )
        |> then(fn notif ->
          notif
          |> Ecto.Changeset.change(
            inserted_at: NaiveDateTime.add(now, -100, :day) |> NaiveDateTime.truncate(:second)
          )
          |> Repo.update!()
        end)

      # Create a notification inserted 80 days ago and read (should NOT be deleted)
      recent_read_notification =
        insert(:notification,
          read_at: NaiveDateTime.add(now, -80, :day) |> NaiveDateTime.truncate(:second)
        )
        |> then(fn notif ->
          notif
          |> Ecto.Changeset.change(
            inserted_at: NaiveDateTime.add(now, -80, :day) |> NaiveDateTime.truncate(:second)
          )
          |> Repo.update!()
        end)

      # Create an unread notification from 100 days ago (should NOT be deleted)
      old_unread_notification =
        insert(:notification,
          read_at: nil
        )
        |> then(fn notif ->
          notif
          |> Ecto.Changeset.change(
            inserted_at: NaiveDateTime.add(now, -100, :day) |> NaiveDateTime.truncate(:second)
          )
          |> Repo.update!()
        end)

      # Perform the cleanup job
      assert :ok = perform_job(NotificationCleanup, %{})

      # Verify old read notification was deleted
      refute Repo.get(
               OGrupoDeEstudos.Engagement.Notifications.Notification,
               old_read_notification.id
             )

      # Verify recent read notification still exists
      assert Repo.get(
               OGrupoDeEstudos.Engagement.Notifications.Notification,
               recent_read_notification.id
             )

      # Verify unread notifications are preserved
      assert Repo.get(
               OGrupoDeEstudos.Engagement.Notifications.Notification,
               old_unread_notification.id
             )
    end

    test "handles empty notification table gracefully" do
      assert :ok = perform_job(NotificationCleanup, %{})
    end

    test "only considers inserted_at, not read_at timestamp" do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      # Create a notification inserted 100 days ago but read recently
      old_inserted_notification =
        insert(:notification,
          read_at: now
        )
        |> then(fn notif ->
          notif
          |> Ecto.Changeset.change(
            inserted_at: NaiveDateTime.add(now, -100, :day) |> NaiveDateTime.truncate(:second)
          )
          |> Repo.update!()
        end)

      assert :ok = perform_job(NotificationCleanup, %{})

      # Should be deleted because inserted_at is >90 days old and it's read
      refute Repo.get(
               OGrupoDeEstudos.Engagement.Notifications.Notification,
               old_inserted_notification.id
             )
    end
  end
end
