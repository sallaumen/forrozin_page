defmodule ForrozinWeb.UserRegistrationLiveTest do
  use ForrozinWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "página de cadastro" do
    test "renderiza formulário", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/signup")
      assert html =~ "Criar conta"
      assert html =~ "Usuário"
      assert html =~ "Senha"
    end

    test "redireciona para /collection se já autenticado", %{conn: conn} do
      user = insert(:user)
      conn = conn |> log_in_user(user)

      assert {:error, {:redirect, %{to: "/collection"}}} = live(conn, ~p"/signup")
    end
  end

  describe "cadastro de usuário" do
    test "cria conta e redireciona para /login", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/signup")

      result =
        lv
        |> form("form",
          user: %{
            username: "novousuario",
            email: "novo@example.com",
            password: "senhasegura123"
          }
        )
        |> render_submit()

      assert {:error, {:redirect, %{to: "/login"}}} = result
    end

    test "exibe erros com dados inválidos", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/signup")

      html =
        lv
        |> form("form", user: %{username: "ab", email: "invalido", password: "curta"})
        |> render_submit()

      assert html =~ "should be at least"
    end
  end
end
