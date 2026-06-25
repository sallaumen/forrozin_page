defmodule OGrupoDeEstudosWeb.GraphVisual.SequenceSummary do
  @moduledoc """
  Pure presentation helpers for the sequence-library panel of `GraphVisualLive`,
  rendered directly in the co-located template:

    * `sequence_summary_badges/1` — the "N passos / fecha no início / loop" chips
    * `sequence_has_inner_loop?/1`, `sequence_closes_at_start?/1` — shape detection
    * `sequence_category_labels/1` — up to 3 distinct `{name, label, color}` chips
    * `sequence_category_filter_label/2` — the active category-filter button label
    * `step_display_label/1,2` — "CODE · Name" rendering for a step or code

  All pure; association reads use `Ecto.assoc_loaded?/1` (in-memory, no Repo).
  Imported into the LiveView so the template resolves these as bare locals.
  """

  def sequence_summary_badges(sequence) do
    [
      "#{length(sequence)} passos",
      if(sequence_closes_at_start?(sequence), do: "fecha no início", else: nil),
      if(sequence_has_inner_loop?(sequence), do: "tem loop curto", else: "sem loops")
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp sequence_closes_at_start?([first | _] = sequence) do
    List.last(sequence).code == first.code
  end

  defp sequence_closes_at_start?(_sequence), do: false

  def sequence_has_inner_loop?(sequence) do
    codes = Enum.map(sequence, & &1.code)

    codes =
      if length(codes) > 1 and List.first(codes) == List.last(codes) do
        Enum.drop(codes, -1)
      else
        codes
      end

    length(codes) != length(Enum.uniq(codes))
  end

  def step_display_label(%{code: code, name: name}), do: "#{code} · #{name}"

  def step_display_label(code, steps) do
    case Enum.find(steps, &(&1.code == code)) do
      nil -> code
      step -> step_display_label(step)
    end
  end

  def sequence_category_labels(sequence) do
    sequence.sequence_steps
    |> Enum.map(fn sequence_step ->
      step = sequence_step.step

      if Ecto.assoc_loaded?(step.category) && step.category do
        {step.category.name, step.category.label, step.category.color}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(fn {name, _label, _color} -> name end)
    |> Enum.take(3)
  end

  def sequence_category_filter_label("all", _categories), do: "Todas"

  def sequence_category_filter_label(category_name, categories) do
    case Enum.find(categories, &(&1.name == category_name)) do
      nil -> "Categoria"
      category -> category.label
    end
  end
end
