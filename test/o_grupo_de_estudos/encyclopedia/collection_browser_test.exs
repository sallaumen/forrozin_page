defmodule OGrupoDeEstudos.Encyclopedia.CollectionBrowserTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Encyclopedia.CollectionBrowser

  test "build_sections/1 returns at most three featured steps sorted by likes" do
    category = insert(:category, name: "sacadas", label: "Sacadas", color: "#ef5b8d")
    section = insert(:section, title: "Sacadas", code: "SC", position: 1, category: category)

    insert(:step,
      section: section,
      category: category,
      code: "SC-LOW",
      name: "Baixa",
      like_count: 1
    )

    insert(:step,
      section: section,
      category: category,
      code: "SC-HIGH",
      name: "Alta",
      like_count: 5
    )

    insert(:step,
      section: section,
      category: category,
      code: "SC-MID",
      name: "Media",
      like_count: 3
    )

    insert(:step,
      section: section,
      category: category,
      code: "SC-EXTRA",
      name: "Extra",
      like_count: 2
    )

    [card] =
      Encyclopedia.list_sections_with_steps()
      |> CollectionBrowser.build_sections()

    assert card.title == "Sacadas"
    assert card.step_count == 4
    assert card.popularity_score == 11
    assert Enum.map(card.featured_steps, & &1.code) == ["SC-HIGH", "SC-MID", "SC-EXTRA"]
  end

  test "section_details/2 keeps real subsections and exposes direct featured steps" do
    category = insert(:category, name: "giros", label: "Giros", color: "#8b5cf6")
    section = insert(:section, title: "Giros", code: "G", position: 1, category: category)
    subsection = insert(:subsection, section: section, title: "Giros simples", position: 1)

    insert(:step,
      section: section,
      subsection: subsection,
      category: category,
      code: "GS-1",
      name: "Primeiro",
      like_count: 4
    )

    insert(:step,
      section: section,
      subsection: subsection,
      category: category,
      code: "GS-2",
      name: "Segundo",
      like_count: 1
    )

    insert(:step,
      section: section,
      category: category,
      code: "GF-1",
      name: "Fora da subsecao",
      like_count: 2
    )

    sections = Encyclopedia.list_sections_with_steps()
    details = CollectionBrowser.section_details(sections, section.id)

    assert details.id == section.id
    assert Enum.map(details.subsections, & &1.title) == ["Giros simples"]
    assert Enum.map(details.featured_steps, & &1.code) == ["GS-1", "GF-1", "GS-2"]
  end
end
