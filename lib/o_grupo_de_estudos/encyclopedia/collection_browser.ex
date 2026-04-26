defmodule OGrupoDeEstudos.Encyclopedia.CollectionBrowser do
  @moduledoc false

  def build_sections(sections) do
    Enum.map(sections, &build_section_card/1)
  end

  def section_details(sections, section_id) do
    sections
    |> Enum.find(&(&1.id == section_id))
    |> case do
      nil -> nil
      section -> build_section_details(section)
    end
  end

  defp build_section_card(section) do
    visible_steps = flatten_visible_steps(section)

    %{
      id: section.id,
      title: section.title,
      code: section.code,
      description: section.description,
      category_name: section.category && section.category.name,
      category_label: section.category && section.category.label,
      category_color: section.category && section.category.color,
      subsection_count: length(section.subsections),
      step_count: length(visible_steps),
      popularity_score: Enum.sum(Enum.map(visible_steps, &(&1.like_count || 0))),
      featured_steps: featured_steps(visible_steps),
      image_path: section_image_path(visible_steps)
    }
  end

  defp build_section_details(section) do
    visible_steps = flatten_visible_steps(section)

    %{
      id: section.id,
      title: section.title,
      code: section.code,
      description: section.description,
      category_name: section.category && section.category.name,
      category_label: section.category && section.category.label,
      category_color: section.category && section.category.color,
      featured_steps: featured_steps(visible_steps),
      subsections: Enum.map(section.subsections, &build_subsection_card/1)
    }
  end

  defp build_subsection_card(subsection) do
    %{
      id: subsection.id,
      title: subsection.title,
      note: subsection.note,
      step_count: length(subsection.steps),
      featured_steps: featured_steps(subsection.steps)
    }
  end

  defp flatten_visible_steps(section) do
    section.steps ++ Enum.flat_map(section.subsections, & &1.steps)
  end

  defp featured_steps(steps) do
    steps
    |> Enum.sort_by(&{-(&1.like_count || 0), &1.name})
    |> Enum.take(3)
  end

  defp section_image_path(steps) do
    Enum.find_value(steps, & &1.image_path)
  end
end
