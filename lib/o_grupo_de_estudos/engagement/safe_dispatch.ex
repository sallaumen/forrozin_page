defmodule OGrupoDeEstudos.Engagement.SafeDispatch do
  @moduledoc """
  Runs best-effort side effects (notifications, activity broadcasts) so that a
  failure never breaks the main CRUD operation. Logs the failure instead of
  swallowing it silently, keeping notification bugs visible.
  """

  require Logger

  @doc "Runs `fun`, returning its result; on error, logs a warning and returns `:ok`."
  def run(fun) when is_function(fun, 0) do
    fun.()
  rescue
    error ->
      Logger.warning("Engagement dispatch failed: #{Exception.message(error)}")
      :ok
  end
end
