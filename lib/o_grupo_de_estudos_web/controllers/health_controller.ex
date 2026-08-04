defmodule OGrupoDeEstudosWeb.HealthController do
  use OGrupoDeEstudosWeb, :controller

  alias OGrupoDeEstudos.Health

  @doc """
  Fly health check: 200 only with the database answering, otherwise 503. A
  machine stuck with a dead pool must fail the check and be recycled.
  """
  def check(conn, _params) do
    if Health.database_responsive?() do
      send_health(conn, 200, "ok")
    else
      send_health(conn, 503, "database unavailable")
    end
  end

  defp send_health(conn, status, body) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, body)
  end
end
