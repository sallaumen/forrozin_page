defmodule OGrupoDeEstudos.Workers.NotificationCleanupTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workers.NotificationCleanup

  describe "perform/1" do
    test "purges read notifications older than 90 days" do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      old_read_notification =
        insert(:notification,
          read_at: DateTime.utc_now() |> DateTime.add(-100, :day) |> DateTime.truncate(:second)
        )
        |> then(fn notif ->
          notif
          |> Ecto.Changeset.change(
            inserted_at: NaiveDateTime.add(now, -100, :day) |> NaiveDateTime.truncate(:second)
          )
          |> Repo.update!()
        end)

      recent_read_notification =
        insert(:notification,
          read_at: DateTime.utc_now() |> DateTime.add(-80, :day) |> DateTime.truncate(:second)
        )
        |> then(fn notif ->
          notif
          |> Ecto.Changeset.change(
            inserted_at: NaiveDateTime.add(now, -80, :day) |> NaiveDateTime.truncate(:second)
          )
          |> Repo.update!()
        end)

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

      assert :ok = perform_job(NotificationCleanup, %{})

      refute Repo.get(
               OGrupoDeEstudos.Engagement.Notifications.Notification,
               old_read_notification.id
             )

      assert Repo.get(
               OGrupoDeEstudos.Engagement.Notifications.Notification,
               recent_read_notification.id
             )

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

      refute Repo.get(
               OGrupoDeEstudos.Engagement.Notifications.Notification,
               old_inserted_notification.id
             )
    end
  end
end
