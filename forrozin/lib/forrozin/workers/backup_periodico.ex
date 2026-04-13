defmodule Forrozin.Workers.BackupPeriodico do
  @moduledoc """
  Worker Oban responsável por gerar backups periódicos do banco de dados.

  Agendado via Oban Cron para rodar a cada hora.
  Aceita argumento `"dir"` opcional para facilitar testes.
  """

  use Oban.Worker, queue: :backup, max_attempts: 2

  alias Forrozin.Admin.Backup

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    dir = Map.get(args, "dir")

    if dir do
      Backup.criar_backup!(dir)
    else
      Backup.criar_backup!()
    end

    :ok
  end
end
