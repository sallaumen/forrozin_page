defmodule Forrozin.Workers.PeriodicBackup do
  @moduledoc """
  Oban worker that generates periodic database backups.

  Scheduled via Oban Cron to run every hour.
  Accepts an optional `"dir"` argument to ease testing.
  """

  use Oban.Worker, queue: :backup, max_attempts: 2

  alias Forrozin.Admin.Backup

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    dir = Map.get(args, "dir")

    if dir do
      Backup.create_backup!(dir)
    else
      Backup.create_backup!()
    end

    :ok
  end
end
