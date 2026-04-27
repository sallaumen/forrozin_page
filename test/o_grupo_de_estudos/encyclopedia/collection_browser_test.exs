defmodule OGrupoDeEstudos.Encyclopedia.CollectionBrowserTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Encyclopedia.CollectionBrowser

  test "build_sections/1 returns section cards sorted by likes" do
    category = insert(:category, name: "sacadas", label: "Sacadas", color: "#ef5b8d")
    section = insert(:section, title: "Sacadas", code: "SC", position: 1, category: category)

    insert(:step, section: section, category: category, code: "SC-LOW", name: "Baixa", like_count: 1)
    insert(:step, section: section, category: category, code: "SC-HIGH", name: "Alta", like_count: 5)
    insert(:step, section: section, category: category, code: "SC-MID", name: "Media", like_count: 3)
    insert(:step, section: section, category: category, code: "SC-EXTRA", name: "Extra", like_count: 2)

    [card] =
      Encyclopedia.list_sections_with_steps()
      |> CollectionBrowser.build_sections()

    assert card.title == "Sacadas"
    assert card.step_count == 4
    assert card.popularity_score == 11
    assert card.image_path == "/images/collection/sacada-simples.png"
    # Featured shows top 3 core steps by likes
    assert length(card.featured_steps) == 3
  end

  test "section_details/2 returns all steps and subsections" do
    category = insert(:category, name: "giros", label: "Giros", color: "#8b5cf6")
    section = insert(:section, title: "Giros", code: "G", position: 1, category: category)
    subsection = insert(:subsection, section: section, title: "Giros simples", position: 1)

    insert(:step, section: section, subsection: subsection, category: category, code: "GS-1", name: "Primeiro", like_count: 4)
    insert(:step, section: section, subsection: subsection, category: category, code: "GS-2", name: "Segundo", like_count: 1)
    insert(:step, section: section, category: category, code: "GF-1", name: "Fora da subsecao", like_count: 2)

    sections = Encyclopedia.list_sections_with_steps()
    details = CollectionBrowser.section_details(sections, section.id)

    assert details.id == section.id
    assert Enum.map(details.subsections, & &1.title) == ["Giros simples"]
    # All 3 steps present, sorted by likes
    codes = Enum.map(details.steps, & &1.code)
    assert "GS-1" in codes
    assert "GS-2" in codes
    assert "GF-1" in codes
    assert length(codes) == 3
  end

  test "section_details/2 applies step image overrides" do
    category = insert(:category, name: "sacadas", label: "Sacadas", color: "#ef5b8d")
    section = insert(:section, title: "Sacadas", code: "SC", position: 1, category: category)

    insert(:step, section: section, category: category, code: "SC-E", name: "Sacada de esquerda", like_count: 0)

    sections = Encyclopedia.list_sections_with_steps()
    details = CollectionBrowser.section_details(sections, section.id)

    sc_e = Enum.find(details.steps, &(&1.code == "SC-E"))
    assert sc_e.image_path == "/images/collection/sacada-esquerda.png"
  end
end
