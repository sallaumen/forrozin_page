defmodule OGrupoDeEstudosWeb.GraphVisual.SequenceSummaryTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Encyclopedia.Category
  alias OGrupoDeEstudosWeb.GraphVisual.SequenceSummary

  @not_loaded %Ecto.Association.NotLoaded{
    __field__: :category,
    __owner__: nil,
    __cardinality__: :one
  }

  defp code(c), do: %{code: c, name: "Nome #{c}"}
  defp cat_step(category), do: %{step: %{category: category}}

  # ── step_display_label/1 ──────────────────────────────────────────────

  describe "step_display_label/1" do
    test "formats a step map into 'CODE · NAME' with the middle-dot separator" do
      assert SequenceSummary.step_display_label(%{code: "BF", name: "Base"}) == "BF · Base"
    end

    test "reads only code/name and preserves accents verbatim" do
      step = %{code: "IV", name: "Inversão", category: %{name: "basico"}, position: 3}
      assert SequenceSummary.step_display_label(step) == "IV · Inversão"
    end
  end

  # ── step_display_label/2 ──────────────────────────────────────────────

  describe "step_display_label/2" do
    test "resolves a code present in the steps list" do
      steps = [%{code: "BF", name: "Base"}, %{code: "IV", name: "Inversão"}]
      assert SequenceSummary.step_display_label("BF", steps) == "BF · Base"
    end

    test "falls back to the raw code when no step matches" do
      assert SequenceSummary.step_display_label("ZZZ", [%{code: "BF", name: "Base"}]) == "ZZZ"
    end

    test "empty steps list returns the code verbatim" do
      assert SequenceSummary.step_display_label("BF", []) == "BF"
    end

    test "lookup is exact and case-sensitive" do
      assert SequenceSummary.step_display_label("bf", [%{code: "BF", name: "Base"}]) == "bf"
    end
  end

  # ── sequence_summary_badges/1 (takes a LIST of step maps) ──────────────

  describe "sequence_summary_badges/1" do
    test "open sequence with no inner loop: count + sem loops" do
      seq = [code("BF"), code("IV"), code("SCSP")]
      assert SequenceSummary.sequence_summary_badges(seq) == ["3 passos", "sem loops"]
    end

    test "closes at start AND inner loop: all three badges" do
      seq = [code("BF"), code("IV"), code("IV"), code("BF")]

      assert SequenceSummary.sequence_summary_badges(seq) == [
               "4 passos",
               "fecha no início",
               "tem loop curto"
             ]
    end

    test "closes at start but the only repeat is the closing one: no inner loop" do
      seq = [code("BF"), code("IV"), code("SCSP"), code("BF")]

      assert SequenceSummary.sequence_summary_badges(seq) == [
               "4 passos",
               "fecha no início",
               "sem loops"
             ]
    end

    test "empty sequence: 0 passos + sem loops" do
      assert SequenceSummary.sequence_summary_badges([]) == ["0 passos", "sem loops"]
    end

    test "single-step sequence: 1 passos + sem loops (no inner loop despite head==last)" do
      assert SequenceSummary.sequence_summary_badges([code("BF")]) == [
               "1 passos",
               "fecha no início",
               "sem loops"
             ]
    end
  end

  # ── sequence_closes_at_start?/1 (private; exercised via badges) ────────

  describe "sequence_closes_at_start? (via sequence_summary_badges)" do
    test "first and last equal yields the 'fecha no início' badge" do
      assert "fecha no início" in SequenceSummary.sequence_summary_badges([
               code("BF"),
               code("IV"),
               code("BF")
             ])
    end

    test "first and last differ omits the badge" do
      refute "fecha no início" in SequenceSummary.sequence_summary_badges([
               code("BF"),
               code("IV"),
               code("SCSP")
             ])
    end

    test "empty list omits the badge" do
      refute "fecha no início" in SequenceSummary.sequence_summary_badges([])
    end
  end

  # ── sequence_has_inner_loop?/1 ────────────────────────────────────────

  describe "sequence_has_inner_loop?/1" do
    test "distinct open sequence has no inner loop" do
      refute SequenceSummary.sequence_has_inner_loop?([code("BF"), code("IV"), code("SCSP")])
    end

    test "repeated middle code (open) is an inner loop" do
      assert SequenceSummary.sequence_has_inner_loop?([
               code("BF"),
               code("IV"),
               code("IV"),
               code("SCSP")
             ])
    end

    test "closing repeat alone is not an inner loop (trailing code dropped first)" do
      refute SequenceSummary.sequence_has_inner_loop?([code("BF"), code("IV"), code("BF")])
    end

    test "closing repeat plus a genuine middle repeat is an inner loop" do
      assert SequenceSummary.sequence_has_inner_loop?([
               code("BF"),
               code("IV"),
               code("IV"),
               code("BF")
             ])
    end

    test "empty and single-element have no inner loop" do
      refute SequenceSummary.sequence_has_inner_loop?([])
      refute SequenceSummary.sequence_has_inner_loop?([code("BF")])
    end

    test "two identical codes (first==last) has no inner loop" do
      refute SequenceSummary.sequence_has_inner_loop?([code("BF"), code("BF")])
    end
  end

  # ── sequence_category_labels/1 (Sequence struct; assoc-guarded) ────────

  describe "sequence_category_labels/1" do
    test "returns up to three unique {name, label, color} tuples in step order" do
      a = %Category{name: "basico", label: "Básico", color: "#a"}
      b = %Category{name: "giros", label: "Giros", color: "#b"}
      c = %Category{name: "footwork", label: "Footwork", color: "#c"}
      d = %Category{name: "saltos", label: "Saltos", color: "#d"}
      seq = %{sequence_steps: [cat_step(a), cat_step(b), cat_step(a), cat_step(c), cat_step(d)]}

      assert SequenceSummary.sequence_category_labels(seq) == [
               {"basico", "Básico", "#a"},
               {"giros", "Giros", "#b"},
               {"footwork", "Footwork", "#c"}
             ]
    end

    test "skips steps whose category is unloaded or nil" do
      loaded = %Category{name: "basico", label: "Básico", color: "#a"}
      seq = %{sequence_steps: [cat_step(@not_loaded), cat_step(nil), cat_step(loaded)]}
      assert SequenceSummary.sequence_category_labels(seq) == [{"basico", "Básico", "#a"}]
    end

    test "empty steps returns empty list" do
      assert SequenceSummary.sequence_category_labels(%{sequence_steps: []}) == []
    end

    test "fewer than three distinct categories returns them all" do
      a = %Category{name: "basico", label: "Básico", color: "#a"}
      b = %Category{name: "giros", label: "Giros", color: "#b"}
      seq = %{sequence_steps: [cat_step(a), cat_step(b)]}

      assert SequenceSummary.sequence_category_labels(seq) == [
               {"basico", "Básico", "#a"},
               {"giros", "Giros", "#b"}
             ]
    end
  end

  # ── sequence_category_filter_label/2 ──────────────────────────────────

  describe "sequence_category_filter_label/2" do
    test "the 'all' sentinel returns Todas" do
      assert SequenceSummary.sequence_category_filter_label("all", [
               %{name: "basico", label: "Básico"}
             ]) ==
               "Todas"
    end

    test "a known category name resolves to its label" do
      cats = [%{name: "basico", label: "Básico"}, %{name: "giros", label: "Giros"}]
      assert SequenceSummary.sequence_category_filter_label("basico", cats) == "Básico"
    end

    test "an unknown category name returns the generic fallback" do
      assert SequenceSummary.sequence_category_filter_label("nope", [
               %{name: "basico", label: "Básico"}
             ]) ==
               "Categoria"
    end

    test "empty categories with a non-all name returns the fallback" do
      assert SequenceSummary.sequence_category_filter_label("basico", []) == "Categoria"
    end
  end
end
