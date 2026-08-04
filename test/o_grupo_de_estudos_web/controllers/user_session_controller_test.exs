defmodule OGrupoDeEstudosWeb.UserSessionControllerTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  alias OGrupoDeEstudos.Engagement.UserLoginEvent
  alias OGrupoDeEstudos.Repo

  describe "GET /login" do
    test "shows the google sign-in button", %{conn: conn} do
      conn = get(conn, ~p"/login")
      response = html_response(conn, 200)

      assert response =~ "Entrar com o Google"
      assert response =~ "/auth/google"
    end

    test "google button carries the teacher invite along", %{conn: conn} do
      conn = get(conn, ~p"/login?teacher_invite=prof-joana")

      assert html_response(conn, 200) =~ "/auth/google?teacher_invite=prof-joana"
    end

    test "google button carries the return_to along", %{conn: conn} do
      conn = get(conn, ~p"/login?return_to=/workshops/forro-em-curitiba")
      response = html_response(conn, 200)

      assert response =~ "return_to=%2Fworkshops%2Fforro-em-curitiba"
    end

    test "signup link carries the return_to along", %{conn: conn} do
      conn = get(conn, ~p"/login?return_to=/workshops/forro-em-curitiba")
      response = html_response(conn, 200)

      assert response =~ "/signup?return_to=%2Fworkshops%2Fforro-em-curitiba"
    end

    test "ignores an external return_to", %{conn: conn} do
      conn = get(conn, ~p"/login?return_to=https://evil.com")

      refute html_response(conn, 200) =~ "evil.com"
    end

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
        OGrupoDeEstudos.Accounts.register_user(%{
          username: "logintest",
          name: "Login Teste",
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
        conn
        |> put_req_header(
          "user-agent",
          "Mozilla/5.0 (iPhone) AppleWebKit/537.36 Chrome/123.0 Mobile Safari/537.36"
        )
        |> post(~p"/login", %{
          "session" => %{"username" => user.username, "password" => "senhasegura123"}
        })

      assert redirected_to(conn) == ~p"/collection"
      assert get_session(conn, :user_id) == user.id

      event = Repo.get_by!(UserLoginEvent, user_id: user.id)
      assert event.method == "password"
      assert event.device_type == :mobile
      assert event.browser == "Chrome"
    end

    test "logs in user with email as identifier", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/login", %{
          "session" => %{"username" => "logintest@example.com", "password" => "senhasegura123"}
        })

      assert redirected_to(conn) == ~p"/collection"
      assert get_session(conn, :user_id) == user.id
    end

    test "returns to the workshop page after login", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/login", %{
          "session" => %{
            "username" => user.username,
            "password" => "senhasegura123",
            "return_to" => "/workshops/forro-em-curitiba"
          }
        })

      assert redirected_to(conn) == "/workshops/forro-em-curitiba"
    end

    test "falls back to collection when return_to points outside the app", %{
      conn: conn,
      user: user
    } do
      conn =
        post(conn, ~p"/login", %{
          "session" => %{
            "username" => user.username,
            "password" => "senhasegura123",
            "return_to" => "https://evil.com/phishing"
          }
        })

      assert redirected_to(conn) == ~p"/collection"
    end

    test "displays error with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/login", %{
          "session" => %{"username" => "logintest", "password" => "senhaerrada"}
        })

      assert html_response(conn, 200) =~ "inválidos"
      assert Repo.aggregate(UserLoginEvent, :count) == 0
    end
  end

  describe "GET /auto-login/:token" do
    test "logs in with token and tracks the auto-login", %{conn: conn} do
      user = insert(:user)
      token = Phoenix.Token.sign(OGrupoDeEstudosWeb.Endpoint, "auto_login", user.id)

      conn =
        conn
        |> put_req_header(
          "user-agent",
          "Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/605.1.15 Safari/605.1.15"
        )
        |> get(~p"/auto-login/#{token}")

      assert redirected_to(conn) == ~p"/collection"
      assert get_session(conn, :user_id) == user.id

      event = Repo.get_by!(UserLoginEvent, user_id: user.id)
      assert event.method == "auto_login"
      assert event.device_type == :desktop
      assert event.browser == "Safari"
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
