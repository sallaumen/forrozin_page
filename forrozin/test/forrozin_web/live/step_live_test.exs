defmodule ForrozinWeb.StepLiveTest do
  use ForrozinWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp conn_logado(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  describe "acesso" do
    test "redireciona para /login se não autenticado", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/steps/BF")
    end

    test "redireciona para /collection se o passo não existe", %{conn: conn} do
      {:error, {:redirect, %{to: "/collection"}}} = live(conn_logado(conn), ~p"/steps/INEXISTENTE")
    end
  end

  describe "detalhe do passo" do
    test "exibe nome e código do passo", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, code: "BF", name: "Base Frontal")
      {:ok, _lv, html} = live(conn_logado(conn), ~p"/steps/BF")
      assert html =~ "Base Frontal"
      assert html =~ "BF"
    end

    test "exibe nota técnica quando presente", %{conn: conn} do
      section = insert(:section)

      insert(:step,
        section: section,
        code: "BF2",
        name: "Base Frontal",
        note: "Descrição mecânica do passo."
      )

      {:ok, _lv, html} = live(conn_logado(conn), ~p"/steps/BF2")
      assert html =~ "Descrição mecânica do passo."
    end

    test "não exibe passo wip para usuário comum", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, code: "WIP1", name: "Passo WIP", wip: true)
      {:error, {:redirect, %{to: "/collection"}}} = live(conn_logado(conn), ~p"/steps/WIP1")
    end
  end
end
