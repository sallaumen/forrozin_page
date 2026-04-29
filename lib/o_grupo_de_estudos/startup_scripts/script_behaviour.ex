defmodule OGrupoDeEstudos.StartupScripts.ScriptBehaviour do
  @moduledoc """
  Behaviour for startup scripts.

  ## Callbacks

  - `name/0` — unique identifier (e.g., "2026-04-29-send-confirmation-emails")
  - `run_once?/0` — if true, only runs once (skipped if already in data_migrations table)
  - `run/0` — the script logic, returns any term
  """

  @callback name() :: String.t()
  @callback run_once?() :: boolean()
  @callback run() :: any()
end
