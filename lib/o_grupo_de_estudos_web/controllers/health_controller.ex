defmodule OGrupoDeEstudosWeb.HealthController do
  use OGrupoDeEstudosWeb, :controller

  alias OGrupoDeEstudos.Repo

  @doc """
  Health check do Fly: 200 só com o banco respondendo, senão 503 —
  máquina presa com pool morto deve falhar o check e ser reciclada.
  """
  def check(conn, _params) do
    case database_status() do
      :ok -> send_health(conn, 200, "ok")
      :error -> send_health(conn, 503, "database unavailable")
    end
  end

  defp database_status do
    case Repo.query("SELECT 1", [], timeout: 4_000) do
      {:ok, _result} -> :ok
      {:error, _reason} -> :error
    end
  rescue
    _error -> :error
  end

  defp send_health(conn, status, body) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, body)
  end
end
