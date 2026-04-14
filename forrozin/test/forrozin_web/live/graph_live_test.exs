defmodule ForrozinWeb.GraphLiveTest do
  use ForrozinWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  defp conn_logado(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  defp conn_admin(conn) do
    admin = insert(:admin)
    log_in_user(conn, admin)
  end

  describe "acesso" do
    test "redireciona para /login se não autenticado", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/graph")
    end

    test "redireciona usuário comum para /graph/visual", %{conn: conn} do
      {:error, {:redirect, %{to: "/graph/visual"}}} = live(conn_logado(conn), ~p"/graph")
    end
  end

  describe "mount — admin" do
    test "renderiza o título Grafo de Passos", %{conn: conn} do
      {:ok, _lv, html} = live(conn_admin(conn), ~p"/graph")
      assert html =~ "Grafo de Passos"
    end

    test "exibe o código de um passo público", %{conn: conn} do
      insert(:step, code: "BF", name: "Base frontal")
      {:ok, _lv, html} = live(conn_admin(conn), ~p"/graph")
      assert html =~ "BF"
    end

    test "exibe aresta entre dois passos", %{conn: conn} do
      step_a = insert(:step, code: "BF", name: "Base frontal")
      step_b = insert(:step, code: "SC", name: "Sacada simples")
      insert(:connection, source_step: step_a, target_step: step_b, type: "exit")
      {:ok, _lv, html} = live(conn_admin(conn), ~p"/graph")
      assert html =~ "BF"
      assert html =~ "SC"
    end

    test "não exibe passo wip", %{conn: conn} do
      insert(:step, code: "HF-SRS", name: "Sacada Rotativa Suspensa", wip: true)
      {:ok, _lv, html} = live(conn_admin(conn), ~p"/graph")
      refute html =~ "HF-SRS"
    end

    test "contém div#graph-canvas com data-graph JSON válido", %{conn: conn} do
      {:ok, _lv, html} = live(conn_admin(conn), ~p"/graph")
      assert html =~ ~s(id="graph-canvas")
      assert html =~ "data-graph"
      # Extrai o JSON do atributo e valida
      [_, json] = Regex.run(~r/data-graph="([^"]*)"/, html)
      decoded = json |> String.replace("&quot;", "\"") |> Jason.decode!()
      assert Map.has_key?(decoded, "nodes")
      assert Map.has_key?(decoded, "edges")
    end
  end

  describe "controles de admin" do
    test "admin vê botão de editar conexões", %{conn: conn} do
      {:ok, _lv, html} = live(conn_admin(conn), ~p"/graph")
      assert html =~ "Editar conexões"
    end

    test "usuário comum é redirecionado antes de ver o grafo", %{conn: conn} do
      {:error, {:redirect, %{to: "/graph/visual"}}} = live(conn_logado(conn), ~p"/graph")
    end

    test "admin vê botão × nas arestas existentes", %{conn: conn} do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      insert(:connection, source_step: step_a, target_step: step_b, type: "exit")
      {:ok, _lv, html} = live(conn_admin(conn), ~p"/graph")
      assert html =~ "delete_connection"
    end

    test "usuário comum não acessa a tabela de conexões", %{conn: conn} do
      {:error, {:redirect, %{to: "/graph/visual"}}} = live(conn_logado(conn), ~p"/graph")
    end
  end

  describe "modo edição (admin)" do
    test "clicar em Editar conexões exibe os painéis de seleção", %{conn: conn} do
      {:ok, lv, _html} = live(conn_admin(conn), ~p"/graph")
      html = render_click(lv, "toggle_edit_mode", %{})
      assert html =~ "Origens"
      assert html =~ "Destinos"
    end

    test "selecionar origem e destino e criar adiciona aresta na lista", %{conn: conn} do
      step_a = insert(:step, code: "BF", name: "Base frontal")
      step_b = insert(:step, code: "SC", name: "Sacada simples")
      {:ok, lv, _html} = live(conn_admin(conn), ~p"/graph")
      render_click(lv, "toggle_edit_mode", %{})
      render_click(lv, "select_source", %{"step_id" => step_a.id})
      render_click(lv, "select_target", %{"step_id" => step_b.id})
      html = render_click(lv, "create_connections", %{})
      assert html =~ "BF"
      assert html =~ "SC"
    end

    test "criar conexão duplicada não gera erro e mantém o grafo estável", %{conn: conn} do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      insert(:connection, source_step: step_a, target_step: step_b, type: "exit")
      {:ok, lv, _html} = live(conn_admin(conn), ~p"/graph")
      render_click(lv, "toggle_edit_mode", %{})
      render_click(lv, "select_source", %{"step_id" => step_a.id})
      render_click(lv, "select_target", %{"step_id" => step_b.id})
      html = render_click(lv, "create_connections", %{})
      assert html =~ "BF"
    end
  end

  describe "remover conexão (admin)" do
    test "admin clica × e a contagem de arestas cai para zero", %{conn: conn} do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      connection = insert(:connection, source_step: step_a, target_step: step_b, type: "exit")
      {:ok, lv, html} = live(conn_admin(conn), ~p"/graph")
      assert html =~ "1 arestas"
      html = render_click(lv, "delete_connection", %{"connection_id" => connection.id})
      assert html =~ "0 arestas"
    end
  end
end
