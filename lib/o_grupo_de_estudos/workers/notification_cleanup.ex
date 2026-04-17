defmodule OGrupoDeEstudos.Workers.NotificationCleanup do
  @moduledoc """
  Oban worker that purges old read notifications (>90 days).

  Scheduled via Oban Cron to run weekly (Sundays at 03:00 UTC).
  Only deletes notifications that have been read for more than 90 days,
  preserving unread notifications indefinitely.
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 1

  import Ecto.Query
  require Logger

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Engagement.Notifications.Notification

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    cutoff =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-90, :day)
      |> NaiveDateTime.truncate(:second)

    {deleted, _} =
      from(n in Notification,
        where: not is_nil(n.read_at) and n.inserted_at < ^cutoff
      )
      |> Repo.delete_all()

    Logger.info("NotificationCleanup: purged #{deleted} old read notifications")
    :ok
  end
end
