defmodule OGrupoDeEstudos.StartupScripts.Runner do
  @moduledoc """
  Runs startup scripts on application startup.

  Each script module must implement the `ScriptBehaviour` behaviour:
  - `name/0` — unique string identifier
  - `run_once?/0` — if true, skips if already completed
  - `run/0` — the actual script logic

  Scripts are registered in `@migrations` and run sequentially.
  Already-completed one-time scripts are skipped.
  Results are recorded in the `data_migrations` table.
  """

  require Logger

  import Ecto.Query

  alias OGrupoDeEstudos.{Repo, StartupScriptRecord}

  @migrations [
    OGrupoDeEstudos.StartupScripts.SendConfirmationToExistingUsers
  ]

  def run_all do
    for module <- @migrations do
      name = module.name()

      if module.run_once?() and already_completed?(name) do
        Logger.info("[StartupScripts] Skipping #{name} (already completed)")
      else
        Logger.info("[StartupScripts] Running #{name}...")
        record = record_start(name)

        try do
          result = module.run()
          record_complete(record, "ok: #{inspect(result)}")
          Logger.info("[StartupScripts] #{name} completed: #{inspect(result)}")
        rescue
          error ->
            record_complete(record, "error: #{Exception.message(error)}")
            Logger.error("[StartupScripts] #{name} failed: #{Exception.message(error)}")
        end
      end
    end
  end

  defp already_completed?(name) do
    Repo.exists?(
      from(dm in StartupScriptRecord, where: dm.name == ^name and dm.result != "pending")
    )
  end

  defp record_start(name) do
    %StartupScriptRecord{
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
