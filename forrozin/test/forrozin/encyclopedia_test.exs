defmodule Forrozin.EncyclopediaTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Encyclopedia

  # ---------------------------------------------------------------------------
  # Categories
  # ---------------------------------------------------------------------------

  describe "list_categories/0" do
    test "retorna lista vazia quando não há categorias" do
      assert Encyclopedia.list_categories() == []
    end

    test "retorna todas as categorias ordenadas por label" do
      insert(:category, name: "sacadas", label: "Sacadas")
      insert(:category, name: "bases", label: "Bases")

      labels = Encyclopedia.list_categories() |> Enum.map(& &1.label)

      assert labels == ["Bases", "Sacadas"]
    end
  end

  describe "get_category_by_name/1" do
    test "retorna a categoria quando existe" do
      insert(:category, name: "sacadas", label: "Sacadas")
      assert {:ok, %{name: "sacadas"}} = Encyclopedia.get_category_by_name("sacadas")
    end

    test "retorna erro quando não existe" do
      assert {:error, :not_found} = Encyclopedia.get_category_by_name("inexistente")
    end
  end

  # ---------------------------------------------------------------------------
  # Sections
  # ---------------------------------------------------------------------------

  describe "list_sections/0" do
    test "retorna lista vazia quando não há seções" do
      assert Encyclopedia.list_sections() == []
    end

    test "retorna seções ordenadas por posição" do
      insert(:section, title: "Sacadas", position: 2)
      insert(:section, title: "Bases", position: 1)

      titles = Encyclopedia.list_sections() |> Enum.map(& &1.title)

      assert titles == ["Bases", "Sacadas"]
    end
  end

  describe "list_sections_with_steps/0" do
    test "retorna seções com passos e subseções pré-carregados" do
      section = insert(:section)
      insert(:step, section: section, code: "BF", name: "Base frontal")

      [result] = Encyclopedia.list_sections_with_steps()

      assert result.id == section.id
      assert length(result.steps) == 1
      assert hd(result.steps).code == "BF"
    end

    test "não inclui passos wip para leitura pública" do
      section = insert(:section)
      insert(:step, section: section, code: "BF", name: "Base frontal", wip: false)
      insert(:step, section: section, code: "HF-SRS", name: "Sacada Rotativa", wip: true)

      [result] = Encyclopedia.list_sections_with_steps()

      codes = Enum.map(result.steps, & &1.code)
      assert "BF" in codes
      refute "HF-SRS" in codes
    end

    test "não inclui passos com status draft" do
      section = insert(:section)
      insert(:step, section: section, code: "BF", name: "Base frontal", status: "published")
      insert(:step, section: section, code: "BQ", name: "Base quadrada", status: "draft")

      [result] = Encyclopedia.list_sections_with_steps()

      codes = Enum.map(result.steps, & &1.code)
      assert "BF" in codes
      refute "BQ" in codes
    end
  end

  # ---------------------------------------------------------------------------
  # Steps
  # ---------------------------------------------------------------------------

  describe "get_step_by_code/1" do
    test "retorna o passo quando existe e é público" do
      insert(:step, code: "BF", name: "Base frontal")

      assert {:ok, %{code: "BF"}} = Encyclopedia.get_step_by_code("BF")
    end

    test "retorna erro para passo wip" do
      insert(:step, code: "HF-SRS", name: "Sacada Rotativa", wip: true)

      assert {:error, :not_found} = Encyclopedia.get_step_by_code("HF-SRS")
    end

    test "retorna erro quando não existe" do
      assert {:error, :not_found} = Encyclopedia.get_step_by_code("INEXISTENTE")
    end
  end

  describe "search_steps/1" do
    test "retorna passos que contêm o termo no nome" do
      insert(:step, code: "BF", name: "Base frontal")
      insert(:step, code: "BQ", name: "Base quadrada")
      insert(:step, code: "SC", name: "Sacada simples")

      results = Encyclopedia.search_steps("base")

      codes = Enum.map(results, & &1.code)
      assert "BF" in codes
      assert "BQ" in codes
      refute "SC" in codes
    end

    test "busca é case-insensitive" do
      insert(:step, code: "BF", name: "Base frontal")

      results = Encyclopedia.search_steps("BASE")

      assert length(results) == 1
    end

    test "não retorna passos wip na busca pública" do
      insert(:step, code: "BF", name: "Base frontal", wip: false)
      insert(:step, code: "HF-SRS", name: "Base rotativa suspensa", wip: true)

      results = Encyclopedia.search_steps("base")

      codes = Enum.map(results, & &1.code)
      assert "BF" in codes
      refute "HF-SRS" in codes
    end

    test "retorna lista vazia quando não há correspondência" do
      insert(:step, code: "BF", name: "Base frontal")

      assert Encyclopedia.search_steps("xyzzyqwerty_inexistente") == []
    end
  end

  # ---------------------------------------------------------------------------
  # Graph
  # ---------------------------------------------------------------------------

  describe "build_graph/1" do
    test "retorna mapa com chaves :nodes e :edges" do
      graph = Encyclopedia.build_graph()
      assert Map.has_key?(graph, :nodes)
      assert Map.has_key?(graph, :edges)
    end

    test ":nodes contém passos públicos com categoria precarregada" do
      cat = insert(:category)
      insert(:step, code: "BF-TEST", name: "Base frontal", category: cat)
      graph = Encyclopedia.build_graph()
      node = Enum.find(graph.nodes, fn n -> n.code == "BF-TEST" end)
      assert node != nil
      assert node.code == "BF-TEST"
      assert node.category.id == cat.id
    end

    test ":edges contém conexões com source_step e target_step precarregados" do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      insert(:connection, source_step: step_a, target_step: step_b, type: "exit")
      graph = Encyclopedia.build_graph()
      assert length(graph.edges) == 1
      [edge] = graph.edges
      assert edge.source_step.code == "BF"
      assert edge.target_step.code == "SC"
    end

    test "não inclui passos wip nos nós" do
      insert(:step, code: "BF", wip: false)
      insert(:step, code: "HF-SRS", wip: true)
      graph = Encyclopedia.build_graph()
      codes = Enum.map(graph.nodes, & &1.code)
      assert "BF" in codes
      refute "HF-SRS" in codes
    end

    test "não inclui arestas onde target_step é wip" do
      step_pub = insert(:step, code: "BF", wip: false)
      step_wip = insert(:step, code: "HF-SRS", wip: true)
      insert(:connection, source_step: step_pub, target_step: step_wip, type: "exit")
      graph = Encyclopedia.build_graph()
      assert graph.edges == []
    end

    test ":edges incluem label quando presente" do
      step_a = insert(:step, code: "ARM-D")
      step_b = insert(:step, code: "TR-ARM")
      insert(:connection, source_step: step_a, target_step: step_b, type: "exit", label: "Trava Armada")
      graph = Encyclopedia.build_graph()
      [edge] = graph.edges
      assert edge.label == "Trava Armada"
    end

    test "não inclui arestas onde source_step é wip" do
      step_wip = insert(:step, code: "HF-SRS", wip: true)
      step_pub = insert(:step, code: "BF", wip: false)
      insert(:connection, source_step: step_wip, target_step: step_pub, type: "exit")
      graph = Encyclopedia.build_graph()
      assert graph.edges == []
    end

    test "com [admin: true] inclui passos wip nos nós" do
      insert(:step, code: "BF", wip: false)
      insert(:step, code: "HF-SRS", wip: true)
      graph = Encyclopedia.build_graph(admin: true)
      codes = Enum.map(graph.nodes, & &1.code)
      assert "BF" in codes
      assert "HF-SRS" in codes
    end
  end

  # ---------------------------------------------------------------------------
  # Technical Concepts
  # ---------------------------------------------------------------------------

  describe "list_technical_concepts/0" do
    test "retorna lista vazia quando não há conceitos" do
      assert Encyclopedia.list_technical_concepts() == []
    end

    test "retorna conceitos ordenados por título" do
      insert(:technical_concept, title: "Transferência de peso")
      insert(:technical_concept, title: "Elástico")

      titles = Encyclopedia.list_technical_concepts() |> Enum.map(& &1.title)

      assert titles == ["Elástico", "Transferência de peso"]
    end
  end
end
