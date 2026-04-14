defmodule ForrozinWeb.UserSessionControllerTest do
  use ForrozinWeb.ConnCase, async: true

  describe "GET /login" do
    test "renderiza formulário de login", %{conn: conn} do
      conn = get(conn, ~p"/login")
      assert html_response(conn, 200) =~ "Entrar"
    end

    test "redireciona para /collection se já autenticado", %{conn: conn} do
      user = insert(:user)
      conn = conn |> log_in_user(user) |> get(~p"/login")
      assert redirected_to(conn) == ~p"/collection"
    end
  end

  describe "POST /login" do
    setup do
      {:ok, user} =
        Forrozin.Accounts.register_user(%{
          username: "logintest",
          email: "logintest@example.com",
          password: "senhasegura123"
        })

      %{user: user}
    end

    test "loga o usuário com credenciais corretas", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/login", %{
          "session" => %{"username" => user.username, "password" => "senhasegura123"}
        })

      assert redirected_to(conn) == ~p"/collection"
      assert get_session(conn, :user_id) == user.id
    end

    test "exibe erro com credenciais inválidas", %{conn: conn} do
      conn =
        post(conn, ~p"/login", %{
          "session" => %{"username" => "logintest", "password" => "senhaerrada"}
        })

      assert html_response(conn, 200) =~ "inválidos"
    end
  end

  describe "DELETE /logout" do
    test "encerra a sessão e redireciona", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> log_in_user(user)
        |> delete(~p"/logout")

      assert redirected_to(conn) == ~p"/login"
      refute get_session(conn, :user_id)
    end
  end
end
