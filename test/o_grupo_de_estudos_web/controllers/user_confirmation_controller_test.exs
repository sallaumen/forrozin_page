defmodule OGrupoDeEstudosWeb.UserConfirmationControllerTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  describe "GET /confirm/:token" do
    test "displays success page with valid token", %{conn: conn} do
      user = insert(:user, confirmed_at: nil, confirmation_token: "valid_ctrl_token")
      conn = get(conn, ~p"/confirm/#{user.confirmation_token}")
      assert html_response(conn, 200) =~ "Email confirmado"
    end

    test "displays error page with invalid token", %{conn: conn} do
      conn = get(conn, ~p"/confirm/token_invalido")
      assert html_response(conn, 200) =~ "Link inválido"
    end

    test "displays error page when reusing an already used token", %{conn: conn} do
      insert(:user, confirmed_at: nil, confirmation_token: "reuse_ctrl_token")
      get(conn, ~p"/confirm/reuse_ctrl_token")
      conn2 = get(build_conn(), ~p"/confirm/reuse_ctrl_token")
      assert html_response(conn2, 200) =~ "Link inválido"
    end
  end
end
