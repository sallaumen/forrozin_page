defmodule OGrupoDeEstudosWeb.GoogleAuthControllerTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Mox

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Accounts.GoogleAuth
  alias OGrupoDeEstudos.Engagement.UserLoginEvent
  alias OGrupoDeEstudos.Repo

  setup :verify_on_exit!

  @google_profile %{
    google_id: "google-sub-123",
    email: "maria.silva@gmail.com",
    name: "Maria Silva"
  }

  describe "GET /auth/google" do
    test "redirects to the google authorize url and stores session params", %{conn: conn} do
      expect(GoogleAuth.Mock, :authorize_url, fn ->
        {:ok,
         %{
           url: "https://accounts.google.com/authorize?state=abc",
           session_params: %{state: "abc"}
         }}
      end)

      conn = get(conn, ~p"/auth/google")

      assert redirected_to(conn) =~ "accounts.google.com"
      assert get_session(conn, :google_auth_session_params) == %{state: "abc"}
    end

    test "redirects to login with an error when the authorize url fails", %{conn: conn} do
      expect(GoogleAuth.Mock, :authorize_url, fn -> {:error, :nxdomain} end)

      conn = get(conn, ~p"/auth/google")

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Google"
    end
  end

  describe "GET /auth/google/callback" do
    test "registers a new user, logs in and redirects to settings", %{conn: conn} do
      expect(GoogleAuth.Mock, :callback, fn %{"code" => "ok"}, %{state: "abc"} ->
        {:ok, @google_profile}
      end)

      conn =
        conn
        |> init_test_session(%{google_auth_session_params: %{state: "abc"}})
        |> get(~p"/auth/google/callback?code=ok")

      assert redirected_to(conn) == ~p"/settings"

      user = Accounts.get_user_by_email("maria.silva@gmail.com")
      assert get_session(conn, :user_id) == user.id

      event = Repo.get_by!(UserLoginEvent, user_id: user.id)
      assert event.method == "google"
    end

    test "logs in the already-registered google user and redirects to collection", %{conn: conn} do
      {:ok, user, :registered} = Accounts.login_or_register_google_user(@google_profile)

      expect(GoogleAuth.Mock, :callback, fn _params, _session_params ->
        {:ok, @google_profile}
      end)

      conn =
        conn
        |> init_test_session(%{google_auth_session_params: %{state: "abc"}})
        |> get(~p"/auth/google/callback?code=ok")

      assert redirected_to(conn) == ~p"/collection"
      assert get_session(conn, :user_id) == user.id
    end

    test "links google to an existing account with the same email", %{conn: conn} do
      {:ok, existing} =
        Accounts.register_user(%{
          username: "mariaantiga",
          name: "Maria Silva",
          email: "maria.silva@gmail.com",
          password: "senhasegura123",
          country: "BR",
          state: "PR",
          city: "Curitiba"
        })

      expect(GoogleAuth.Mock, :callback, fn _params, _session_params ->
        {:ok, @google_profile}
      end)

      conn =
        conn
        |> init_test_session(%{google_auth_session_params: %{state: "abc"}})
        |> get(~p"/auth/google/callback?code=ok")

      assert redirected_to(conn) == ~p"/collection"
      assert get_session(conn, :user_id) == existing.id
      assert Repo.get(Accounts.User, existing.id).google_id == "google-sub-123"
    end

    test "accepts a stored teacher invite after google signup", %{conn: conn} do
      teacher = insert(:user, is_teacher: true, invite_slug: "prof-joana")

      expect(GoogleAuth.Mock, :callback, fn _params, _session_params ->
        {:ok, @google_profile}
      end)

      conn
      |> init_test_session(%{
        google_auth_session_params: %{state: "abc"},
        google_auth_teacher_invite: teacher.invite_slug
      })
      |> get(~p"/auth/google/callback?code=ok")

      student = Accounts.get_user_by_email("maria.silva@gmail.com")
      assert OGrupoDeEstudos.Study.get_link_between(student.id, teacher.id) != nil
    end

    test "redirects to login with an error when the exchange fails", %{conn: conn} do
      expect(GoogleAuth.Mock, :callback, fn _params, _session_params ->
        {:error, :invalid_grant}
      end)

      conn =
        conn
        |> init_test_session(%{google_auth_session_params: %{state: "abc"}})
        |> get(~p"/auth/google/callback?code=bad")

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Google"
      assert get_session(conn, :user_id) == nil
    end

    test "redirects to login when there are no stored session params", %{conn: conn} do
      conn = get(conn, ~p"/auth/google/callback?code=ok")

      assert redirected_to(conn) == ~p"/login"
      assert get_session(conn, :user_id) == nil
    end
  end
end
