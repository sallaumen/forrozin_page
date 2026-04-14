defmodule ForrozinWeb.UserSessionControllerTest do
  use ForrozinWeb.ConnCase, async: true

  describe "GET /login" do
    test "renders login form", %{conn: conn} do
      conn = get(conn, ~p"/login")
      assert html_response(conn, 200) =~ "Entrar"
    end

    test "redirects to /collection when already authenticated", %{conn: conn} do
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
          password: "senhasegura123",
          country: "BR",
          state: "PR",
          city: "Curitiba"
        })

      %{user: user}
    end

    test "logs in user with correct credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/login", %{
          "session" => %{"username" => user.username, "password" => "senhasegura123"}
        })

      assert redirected_to(conn) == ~p"/collection"
      assert get_session(conn, :user_id) == user.id
    end

    test "displays error with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/login", %{
          "session" => %{"username" => "logintest", "password" => "senhaerrada"}
        })

      assert html_response(conn, 200) =~ "inválidos"
    end
  end

  describe "DELETE /logout" do
    test "ends session and redirects", %{conn: conn} do
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
