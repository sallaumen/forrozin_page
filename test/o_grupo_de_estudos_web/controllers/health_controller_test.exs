defmodule OGrupoDeEstudosWeb.HealthControllerTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  test "GET /healthz returns 200 when the database responds", %{conn: conn} do
    conn = get(conn, "/healthz")

    assert response(conn, 200) == "ok"
  end
end
