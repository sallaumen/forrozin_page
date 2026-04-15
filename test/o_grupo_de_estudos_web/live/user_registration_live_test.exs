defmodule OGrupoDeEstudosWeb.UserRegistrationLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "signup page" do
    test "renders form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/signup")
      assert html =~ "Criar conta"
      assert html =~ "Usuário"
      assert html =~ "Senha"
    end

    test "redirects to /collection when already authenticated", %{conn: conn} do
      user = insert(:user)
      conn = conn |> log_in_user(user)

      assert {:error, {:redirect, %{to: "/collection"}}} = live(conn, ~p"/signup")
    end
  end

  describe "user registration" do
    test "creates account and auto-logs in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/signup")

      result =
        lv
        |> form("form",
          user: %{
            username: "novousuario",
            name: "Novo Usuário",
            email: "novo@example.com",
            password: "senhasegura123",
            country: "BR",
            state: "PR",
            city: "Curitiba"
          }
        )
        |> render_submit()

      # Redirects to auto-login endpoint
      assert {:error, {:redirect, %{to: "/auto-login/" <> _user_id}}} = result
    end

    test "displays errors with invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/signup")

      html =
        lv
        |> form("form", user: %{username: "ab", email: "invalido", password: "curta"})
        |> render_submit()

      assert html =~ "should be at least"
    end
  end
end
