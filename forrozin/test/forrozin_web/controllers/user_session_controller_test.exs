defmodule ForrozinWeb.UserSessionControllerTest do
  use ForrozinWeb.ConnCase, async: true

  describe "GET /entrar" do
    test "renderiza formulário de login", %{conn: conn} do
      conn = get(conn, ~p"/entrar")
      assert html_response(conn, 200) =~ "Entrar"
    end

    test "redireciona para /acervo se já autenticado", %{conn: conn} do
      user = insert(:user)
      conn = conn |> log_in_user(user) |> get(~p"/entrar")
      assert redirected_to(conn) == ~p"/acervo"
    end
  end

  describe "POST /entrar" do
    setup do
      {:ok, user} =
        Forrozin.Accounts.registrar_usuario(%{
          nome_usuario: "logintest",
          email: "logintest@example.com",
          senha: "senhasegura123"
        })

      %{user: user}
    end

    test "loga o usuário com credenciais corretas", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/entrar", %{
          "session" => %{"nome_usuario" => user.nome_usuario, "senha" => "senhasegura123"}
        })

      assert redirected_to(conn) == ~p"/acervo"
      assert get_session(conn, :user_id) == user.id
    end

    test "exibe erro com credenciais inválidas", %{conn: conn} do
      conn =
        post(conn, ~p"/entrar", %{
          "session" => %{"nome_usuario" => "logintest", "senha" => "senhaerrada"}
        })

      assert html_response(conn, 200) =~ "inválidos"
    end
  end

  describe "DELETE /sair" do
    test "encerra a sessão e redireciona", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> log_in_user(user)
        |> delete(~p"/sair")

      assert redirected_to(conn) == ~p"/entrar"
      refute get_session(conn, :user_id)
    end
  end
end
