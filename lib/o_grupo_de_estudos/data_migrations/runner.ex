defmodule OGrupoDeEstudos.DataMigrations.Runner do
  @moduledoc """
  Runs data migration scripts on application startup.

  Each migration module must implement the `DataMigrationScript` behaviour:
  - `name/0` — unique string identifier
  - `run_once?/0` — if true, skips if already completed
  - `run/0` — the actual migration logic

  Migrations are registered in `@migrations` and run sequentially.
  Already-completed one-time migrations are skipped.
  Results are recorded in the `data_migrations` table.
  """

  require Logger

  import Ecto.Query

  alias OGrupoDeEstudos.{DataMigration, Repo}

  @migrations [
    OGrupoDeEstudos.DataMigrations.SendConfirmationToExistingUsers
  ]

  def run_all do
    for module <- @migrations do
      name = module.name()

      if module.run_once?() and already_completed?(name) do
        Logger.info("[DataMigrations] Skipping #{name} (already completed)")
      else
        Logger.info("[DataMigrations] Running #{name}...")
        record = record_start(name)

        try do
          result = module.run()
          record_complete(record, "ok: #{inspect(result)}")
          Logger.info("[DataMigrations] #{name} completed: #{inspect(result)}")
        rescue
          error ->
            record_complete(record, "error: #{Exception.message(error)}")
            Logger.error("[DataMigrations] #{name} failed: #{Exception.message(error)}")
        end
      end
    end
  end

  defp already_completed?(name) do
    Repo.exists?(from(dm in DataMigration, where: dm.name == ^name and dm.result != "pending"))
  end

  defp record_start(name) do
    %DataMigration{
      name: name,
      started_at: DateTime.utc_now(),
      result: "running"
    }
    |> Repo.insert!(on_conflict: :replace_all, conflict_target: :name)
  end

  defp record_complete(record, result) do
    import Ecto.Changeset

    record
    |> change(%{completed_at: DateTime.utc_now(), result: result})
    |> Repo.update!()
  end
end
