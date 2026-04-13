defmodule ForrozinWeb.GrafoLiveTest do
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
    test "redireciona para /entrar se não autenticado", %{conn: conn} do
      {:error, {:redirect, %{to: "/entrar"}}} = live(conn, ~p"/grafo")
    end
  end

  describe "mount — autenticado" do
    test "renderiza o título Grafo de Passos", %{conn: conn} do
      {:ok, _lv, html} = live(conn_logado(conn), ~p"/grafo")
      assert html =~ "Grafo de Passos"
    end

    test "exibe o código de um passo público", %{conn: conn} do
      insert(:passo, codigo: "BF", nome: "Base frontal")
      {:ok, _lv, html} = live(conn_logado(conn), ~p"/grafo")
      assert html =~ "BF"
    end

    test "exibe aresta entre dois passos", %{conn: conn} do
      passo_a = insert(:passo, codigo: "BF", nome: "Base frontal")
      passo_b = insert(:passo, codigo: "SC", nome: "Sacada simples")
      insert(:conexao, passo_origem: passo_a, passo_destino: passo_b, tipo: "saida")
      {:ok, _lv, html} = live(conn_logado(conn), ~p"/grafo")
      assert html =~ "BF"
      assert html =~ "SC"
    end

    test "não exibe passo wip", %{conn: conn} do
      insert(:passo, codigo: "HF-SRS", nome: "Sacada Rotativa Suspensa", wip: true)
      {:ok, _lv, html} = live(conn_logado(conn), ~p"/grafo")
      refute html =~ "HF-SRS"
    end

    test "contém div#graph-canvas com data-graph JSON válido", %{conn: conn} do
      {:ok, _lv, html} = live(conn_logado(conn), ~p"/grafo")
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
      {:ok, _lv, html} = live(conn_admin(conn), ~p"/grafo")
      assert html =~ "Editar conexões"
    end

    test "usuário comum não vê botão de editar conexões", %{conn: conn} do
      {:ok, _lv, html} = live(conn_logado(conn), ~p"/grafo")
      refute html =~ "Editar conexões"
    end

    test "admin vê botão × nas arestas existentes", %{conn: conn} do
      passo_a = insert(:passo, codigo: "BF")
      passo_b = insert(:passo, codigo: "SC")
      insert(:conexao, passo_origem: passo_a, passo_destino: passo_b, tipo: "saida")
      {:ok, _lv, html} = live(conn_admin(conn), ~p"/grafo")
      assert html =~ "remover_conexao"
    end

    test "usuário comum não vê botão × nas arestas", %{conn: conn} do
      passo_a = insert(:passo, codigo: "BF")
      passo_b = insert(:passo, codigo: "SC")
      insert(:conexao, passo_origem: passo_a, passo_destino: passo_b, tipo: "saida")
      {:ok, _lv, html} = live(conn_logado(conn), ~p"/grafo")
      refute html =~ "remover_conexao"
    end
  end

  describe "modo edição (admin)" do
    test "clicar em Editar conexões exibe os painéis de seleção", %{conn: conn} do
      {:ok, lv, _html} = live(conn_admin(conn), ~p"/grafo")
      html = render_click(lv, "toggle_modo_edicao", %{})
      assert html =~ "Origens"
      assert html =~ "Destinos"
    end

    test "selecionar origem e destino e criar adiciona aresta na lista", %{conn: conn} do
      passo_a = insert(:passo, codigo: "BF", nome: "Base frontal")
      passo_b = insert(:passo, codigo: "SC", nome: "Sacada simples")
      {:ok, lv, _html} = live(conn_admin(conn), ~p"/grafo")
      render_click(lv, "toggle_modo_edicao", %{})
      render_click(lv, "selecionar_origem", %{"passo_id" => passo_a.id})
      render_click(lv, "selecionar_destino", %{"passo_id" => passo_b.id})
      html = render_click(lv, "criar_conexoes", %{})
      assert html =~ "BF"
      assert html =~ "SC"
    end

    test "criar conexão duplicada não gera erro e mantém o grafo estável", %{conn: conn} do
      passo_a = insert(:passo, codigo: "BF")
      passo_b = insert(:passo, codigo: "SC")
      insert(:conexao, passo_origem: passo_a, passo_destino: passo_b, tipo: "saida")
      {:ok, lv, _html} = live(conn_admin(conn), ~p"/grafo")
      render_click(lv, "toggle_modo_edicao", %{})
      render_click(lv, "selecionar_origem", %{"passo_id" => passo_a.id})
      render_click(lv, "selecionar_destino", %{"passo_id" => passo_b.id})
      html = render_click(lv, "criar_conexoes", %{})
      assert html =~ "BF"
    end
  end

  describe "remover conexão (admin)" do
    test "admin clica × e a contagem de arestas cai para zero", %{conn: conn} do
      passo_a = insert(:passo, codigo: "BF")
      passo_b = insert(:passo, codigo: "SC")
      conexao = insert(:conexao, passo_origem: passo_a, passo_destino: passo_b, tipo: "saida")
      {:ok, lv, html} = live(conn_admin(conn), ~p"/grafo")
      assert html =~ "1 arestas"
      html = render_click(lv, "remover_conexao", %{"conexao_id" => conexao.id})
      assert html =~ "0 arestas"
    end
  end
end
