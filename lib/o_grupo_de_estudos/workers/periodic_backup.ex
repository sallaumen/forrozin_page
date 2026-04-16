defmodule OGrupoDeEstudos.Workers.PeriodicBackup do
  @moduledoc """
  Oban worker that generates periodic database backups and cleans old ones.

  Scheduled via Oban Cron to run every hour.
  Creates a new backup, then removes any backups older than 7 days.
  """

  use Oban.Worker, queue: :backup, max_attempts: 2

  alias OGrupoDeEstudos.Admin.Backup

  @max_age_days 7

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    dir = Map.get(args, "dir")

    if dir do
      Backup.create_backup!(dir)
      cleanup_old_backups(dir)
    else
      Backup.create_backup!()
      cleanup_old_backups(Backup.default_dir())
    end

    :ok
  end

  defp cleanup_old_backups(dir) do
    cutoff = NaiveDateTime.add(NaiveDateTime.utc_now(), -@max_age_days * 86_400)

    Backup.list_backups(dir)
    |> Enum.each(fn path ->
      case Backup.backup_info(path) do
        %{timestamp: ts} when not is_nil(ts) ->
          if NaiveDateTime.compare(ts, cutoff) == :lt do
            File.rm(path)
          end

        _ ->
          :skip
      end
    end)
  end
end
