defmodule Forrozin.EncyclopediaTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Encyclopedia

  # ---------------------------------------------------------------------------
  # Categories
  # ---------------------------------------------------------------------------

  describe "list_categories/0" do
    test "returns empty list when there are no categories" do
      assert Encyclopedia.list_categories() == []
    end

    test "returns all categories ordered by label" do
      insert(:category, name: "sacadas", label: "Sacadas")
      insert(:category, name: "bases", label: "Bases")

      labels = Encyclopedia.list_categories() |> Enum.map(& &1.label)

      assert labels == ["Bases", "Sacadas"]
    end
  end

  describe "fetch_category_by_name/1" do
    test "returns the category when it exists" do
      insert(:category, name: "sacadas", label: "Sacadas")
      assert {:ok, %{name: "sacadas"}} = Encyclopedia.fetch_category_by_name("sacadas")
    end

    test "returns error when it does not exist" do
      assert {:error, :not_found} = Encyclopedia.fetch_category_by_name("inexistente")
    end
  end

  # ---------------------------------------------------------------------------
  # Sections
  # ---------------------------------------------------------------------------

  describe "list_sections/0" do
    test "returns empty list when there are no sections" do
      assert Encyclopedia.list_sections() == []
    end

    test "returns sections ordered by position" do
      insert(:section, title: "Sacadas", position: 2)
      insert(:section, title: "Bases", position: 1)

      titles = Encyclopedia.list_sections() |> Enum.map(& &1.title)

      assert titles == ["Bases", "Sacadas"]
    end
  end

  describe "list_sections_with_steps/0" do
    test "returns sections with steps and subsections preloaded" do
      section = insert(:section)
      insert(:step, section: section, code: "BF", name: "Base frontal")

      [result] = Encyclopedia.list_sections_with_steps()

      assert result.id == section.id
      assert [_] = result.steps
      assert hd(result.steps).code == "BF"
    end

    test "does not include wip steps in public reads" do
      section = insert(:section)
      insert(:step, section: section, code: "BF", name: "Base frontal", wip: false)
      insert(:step, section: section, code: "HF-SRS", name: "Sacada Rotativa", wip: true)

      [result] = Encyclopedia.list_sections_with_steps()

      codes = Enum.map(result.steps, & &1.code)
      assert "BF" in codes
      refute "HF-SRS" in codes
    end

    test "does not include draft steps" do
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

  describe "fetch_step_by_code/1" do
    test "returns the step when it exists and is public" do
      insert(:step, code: "BF", name: "Base frontal")

      assert {:ok, %{code: "BF"}} = Encyclopedia.fetch_step_by_code("BF")
    end

    test "returns error for wip step" do
      insert(:step, code: "HF-SRS", name: "Sacada Rotativa", wip: true)

      assert {:error, :not_found} = Encyclopedia.fetch_step_by_code("HF-SRS")
    end

    test "returns error when step does not exist" do
      assert {:error, :not_found} = Encyclopedia.fetch_step_by_code("INEXISTENTE")
    end
  end

  describe "search_steps/1" do
    test "returns steps containing the term in the name" do
      insert(:step, code: "BF", name: "Base frontal")
      insert(:step, code: "BQ", name: "Base quadrada")
      insert(:step, code: "SC", name: "Sacada simples")

      results = Encyclopedia.search_steps("base")

      codes = Enum.map(results, & &1.code)
      assert "BF" in codes
      assert "BQ" in codes
      refute "SC" in codes
    end

    test "search is case-insensitive" do
      insert(:step, code: "BF", name: "Base frontal")

      results = Encyclopedia.search_steps("BASE")

      assert [_] = results
    end

    test "does not return wip steps in public search" do
      insert(:step, code: "BF", name: "Base frontal", wip: false)
      insert(:step, code: "HF-SRS", name: "Base rotativa suspensa", wip: true)

      results = Encyclopedia.search_steps("base")

      codes = Enum.map(results, & &1.code)
      assert "BF" in codes
      refute "HF-SRS" in codes
    end

    test "returns empty list when there are no matches" do
      insert(:step, code: "BF", name: "Base frontal")

      assert Encyclopedia.search_steps("xyzzyqwerty_inexistente") == []
    end
  end

  # ---------------------------------------------------------------------------
  # Graph
  # ---------------------------------------------------------------------------

  describe "build_graph/1" do
    test "returns map with :nodes and :edges keys" do
      graph = Encyclopedia.build_graph()
      assert Map.has_key?(graph, :nodes)
      assert Map.has_key?(graph, :edges)
    end

    test ":nodes contains public steps with category preloaded" do
      cat = insert(:category)
      insert(:step, code: "BF-TEST", name: "Base frontal", category: cat)
      graph = Encyclopedia.build_graph()
      node = Enum.find(graph.nodes, fn n -> n.code == "BF-TEST" end)
      assert node != nil
      assert node.code == "BF-TEST"
      assert node.category.id == cat.id
    end

    test ":edges contains connections with source_step and target_step preloaded" do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      insert(:connection, source_step: step_a, target_step: step_b)
      graph = Encyclopedia.build_graph()
      assert [_] = graph.edges
      [edge] = graph.edges
      assert edge.source_step.code == "BF"
      assert edge.target_step.code == "SC"
    end

    test "does not include wip steps in nodes" do
      insert(:step, code: "BF", wip: false)
      insert(:step, code: "HF-SRS", wip: true)
      graph = Encyclopedia.build_graph()
      codes = Enum.map(graph.nodes, & &1.code)
      assert "BF" in codes
      refute "HF-SRS" in codes
    end

    test "does not include edges where target_step is wip" do
      step_pub = insert(:step, code: "BF", wip: false)
      step_wip = insert(:step, code: "HF-SRS", wip: true)
      insert(:connection, source_step: step_pub, target_step: step_wip)
      graph = Encyclopedia.build_graph()
      assert graph.edges == []
    end

    test ":edges include label when present" do
      step_a = insert(:step, code: "ARM-D")
      step_b = insert(:step, code: "TR-ARM")
      insert(:connection, source_step: step_a, target_step: step_b, label: "Trava Armada")
      graph = Encyclopedia.build_graph()
      [edge] = graph.edges
      assert edge.label == "Trava Armada"
    end

    test "does not include edges where source_step is wip" do
      step_wip = insert(:step, code: "HF-SRS", wip: true)
      step_pub = insert(:step, code: "BF", wip: false)
      insert(:connection, source_step: step_wip, target_step: step_pub)
      graph = Encyclopedia.build_graph()
      assert graph.edges == []
    end

    test "with [admin: true] includes wip steps in nodes" do
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
    test "returns empty list when there are no concepts" do
      assert Encyclopedia.list_technical_concepts() == []
    end

    test "returns concepts ordered by title" do
      insert(:technical_concept, title: "Transferência de peso")
      insert(:technical_concept, title: "Elástico")

      titles = Encyclopedia.list_technical_concepts() |> Enum.map(& &1.title)

      assert titles == ["Elástico", "Transferência de peso"]
    end
  end
end
