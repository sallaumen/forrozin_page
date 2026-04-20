defmodule OGrupoDeEstudos.Engagement.UserAccessTracking do
  @moduledoc """
  Enqueues lightweight user access tracking jobs.
  """

  require Logger

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Workers.TrackUserLogin

  def track_login(%User{id: user_id}, client_info, method)
      when method in [:password, :auto_login] do
    now =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_iso8601()

    args =
      client_info
      |> Map.take([:device_type, :browser, :is_pwa, :user_agent])
      |> Map.merge(%{
        user_id: user_id,
        method: Atom.to_string(method),
        occurred_at: now
      })

    args
    |> TrackUserLogin.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        :ok

      {:error, changeset} ->
        Logger.warning("Could not enqueue login tracking job: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end
end
