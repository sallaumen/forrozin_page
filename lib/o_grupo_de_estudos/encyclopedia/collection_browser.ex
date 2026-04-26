defmodule OGrupoDeEstudos.Encyclopedia.CollectionBrowser do
  @moduledoc false

  @section_image_overrides %{
    "Bases" => "/images/collection/base.png",
    "Sacadas" => "/images/collection/sacada-simples.png",
    "Giros" => "/images/collection/giro-simples.png"
  }

  @step_image_overrides %{
    "SC" => "/images/collection/sacada-simples.png",
    "SC-E" => "/images/collection/sacada-esquerda.png"
  }

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
    visible_steps = normalize_steps(flatten_visible_steps(section))

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
      image_path: section_image_path(section, visible_steps)
    }
  end

  defp build_section_details(section) do
    visible_steps = normalize_steps(flatten_visible_steps(section))

    %{
      id: section.id,
      title: section.title,
      code: section.code,
      description: section.description,
      category_name: section.category && section.category.name,
      category_label: section.category && section.category.label,
      category_color: section.category && section.category.color,
      featured_steps: featured_steps(visible_steps),
      illustrated_steps: illustrated_steps(visible_steps),
      subsections: Enum.map(section.subsections, &build_subsection_card/1)
    }
  end

  defp build_subsection_card(subsection) do
    steps = normalize_steps(subsection.steps)

    %{
      id: subsection.id,
      title: subsection.title,
      note: subsection.note,
      step_count: length(steps),
      featured_steps: featured_steps(steps)
    }
  end

  defp flatten_visible_steps(section) do
    (section.steps ++ Enum.flat_map(section.subsections, & &1.steps))
    |> Enum.uniq_by(& &1.id)
  end

  defp featured_steps(steps) do
    # Prioritize core steps (non-HF) over footwork variants
    {core, footwork} = Enum.split_with(steps, fn s -> not String.starts_with?(s.code, "HF-") end)

    core_sorted = Enum.sort_by(core, &{-(&1.like_count || 0), &1.name})
    footwork_sorted = Enum.sort_by(footwork, &{-(&1.like_count || 0), &1.name})

    (core_sorted ++ footwork_sorted) |> Enum.take(3)
  end

  defp illustrated_steps(steps) do
    steps
    |> Enum.filter(fn s -> s.image_path && not String.starts_with?(s.code, "HF-") end)
    |> Enum.sort_by(&{-(&1.like_count || 0), &1.name})
    |> Enum.take(4)
  end

  defp normalize_steps(steps) do
    Enum.map(steps, &normalize_step/1)
  end

  defp normalize_step(step) do
    step =
      case Map.get(@step_image_overrides, step.code) do
        nil -> step
        image_path -> %{step | image_path: image_path}
      end

    # Ensure image_path starts with / for proper URL resolution
    case step.image_path do
      nil -> step
      "/" <> _ -> step
      path -> %{step | image_path: "/" <> path}
    end
  end

  defp section_image_path(section, steps) do
    Map.get(@section_image_overrides, section.title) || Enum.find_value(steps, & &1.image_path)
  end
end
