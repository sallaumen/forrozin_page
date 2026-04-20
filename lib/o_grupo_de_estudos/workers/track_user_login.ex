defmodule OGrupoDeEstudos.Workers.TrackUserLogin do
  @moduledoc """
  Persists successful login tracking without blocking the browser request.
  """

  use Oban.Worker, queue: :tracking, max_attempts: 3

  alias Ecto.Multi
  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Engagement.UserLoginEvent
  alias OGrupoDeEstudos.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id} = args}) do
    case Repo.get(User, user_id) do
      nil ->
        {:discard, :user_not_found}

      user ->
        occurred_at = parse_occurred_at(args["occurred_at"])

        attrs = %{
          user_id: user.id,
          method: args["method"],
          device_type: args["device_type"],
          browser: args["browser"],
          is_pwa: args["is_pwa"] || false,
          user_agent: args["user_agent"],
          occurred_at: occurred_at
        }

        Multi.new()
        |> Multi.insert(:login_event, UserLoginEvent.changeset(%UserLoginEvent{}, attrs))
        |> Multi.update(
          :user,
          Ecto.Changeset.change(user,
            last_login_at: occurred_at,
            last_seen_at: occurred_at
          )
        )
        |> Repo.transaction()
        |> case do
          {:ok, _changes} -> :ok
          {:error, _step, reason, _changes} -> {:error, reason}
        end
    end
  end

  defp parse_occurred_at(nil) do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end

  defp parse_occurred_at(occurred_at) do
    case NaiveDateTime.from_iso8601(occurred_at) do
      {:ok, datetime} -> NaiveDateTime.truncate(datetime, :second)
      {:error, _reason} -> parse_occurred_at(nil)
    end
  end
end
