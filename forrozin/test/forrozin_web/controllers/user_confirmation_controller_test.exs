defmodule ForrozinWeb.UserConfirmationControllerTest do
  use ForrozinWeb.ConnCase, async: true

  alias Forrozin.Accounts

  describe "GET /confirm/:token" do
    test "displays success page with valid token", %{conn: conn} do
      {:ok, user} =
        Accounts.register_user(%{
          username: "confirmavel",
          email: "confirmavel@example.com",
          password: "senhasegura123"
        })

      conn = get(conn, ~p"/confirm/#{user.confirmation_token}")

      assert html_response(conn, 200) =~ "Email confirmado"
    end

    test "displays error page with invalid token", %{conn: conn} do
      conn = get(conn, ~p"/confirm/token_invalido")

      assert html_response(conn, 200) =~ "Link inválido"
    end

    test "displays error page when reusing an already used token", %{conn: conn} do
      {:ok, user} =
        Accounts.register_user(%{
          username: "reutiliza",
          email: "reutiliza@example.com",
          password: "senhasegura123"
        })

      get(conn, ~p"/confirm/#{user.confirmation_token}")
      conn2 = get(build_conn(), ~p"/confirm/#{user.confirmation_token}")

      assert html_response(conn2, 200) =~ "Link inválido"
    end
  end
end
