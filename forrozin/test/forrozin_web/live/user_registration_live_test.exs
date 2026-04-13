defmodule ForrozinWeb.UserRegistrationLiveTest do
  use ForrozinWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "página de cadastro" do
    test "renderiza formulário", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/cadastro")
      assert html =~ "Criar conta"
      assert html =~ "Usuário"
      assert html =~ "Senha"
    end

    test "redireciona para /acervo se já autenticado", %{conn: conn} do
      user = insert(:user)
      conn = conn |> log_in_user(user)

      assert {:error, {:redirect, %{to: "/acervo"}}} = live(conn, ~p"/cadastro")
    end
  end

  describe "cadastro de usuário" do
    test "cria conta e redireciona para /entrar", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/cadastro")

      result =
        lv
        |> form("form",
          usuario: %{
            nome_usuario: "novousuario",
            email: "novo@example.com",
            senha: "senhasegura123"
          }
        )
        |> render_submit()

      assert {:error, {:redirect, %{to: "/entrar"}}} = result
    end

    test "exibe erros com dados inválidos", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/cadastro")

      html =
        lv
        |> form("form", usuario: %{nome_usuario: "ab", email: "invalido", senha: "curta"})
        |> render_submit()

      assert html =~ "should be at least"
    end
  end
end
