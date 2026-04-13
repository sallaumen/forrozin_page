defmodule ForrozinWeb.UserConfirmationControllerTest do
  use ForrozinWeb.ConnCase, async: true

  alias Forrozin.Accounts

  describe "GET /confirmar/:token" do
    test "exibe página de sucesso com token válido", %{conn: conn} do
      {:ok, user} =
        Accounts.registrar_usuario(%{
          nome_usuario: "confirmavel",
          email: "confirmavel@example.com",
          senha: "senhasegura123"
        })

      conn = get(conn, ~p"/confirmar/#{user.confirmation_token}")

      assert html_response(conn, 200) =~ "Email confirmado"
    end

    test "exibe página de erro com token inválido", %{conn: conn} do
      conn = get(conn, ~p"/confirmar/token_invalido")

      assert html_response(conn, 200) =~ "Link inválido"
    end

    test "exibe página de erro ao reutilizar token já utilizado", %{conn: conn} do
      {:ok, user} =
        Accounts.registrar_usuario(%{
          nome_usuario: "reutiliza",
          email: "reutiliza@example.com",
          senha: "senhasegura123"
        })

      get(conn, ~p"/confirmar/#{user.confirmation_token}")
      conn2 = get(build_conn(), ~p"/confirmar/#{user.confirmation_token}")

      assert html_response(conn2, 200) =~ "Link inválido"
    end
  end
end
