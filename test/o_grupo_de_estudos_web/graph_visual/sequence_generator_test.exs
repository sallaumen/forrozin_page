defmodule OGrupoDeEstudosWeb.GraphVisual.SequenceGeneratorTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.GraphVisual.SequenceGenerator

  @steps [
    %{code: "BF", name: "Base frontal"},
    %{code: "SC", name: "Sacada simples"}
  ]

  describe "resolve_step_code/3" do
    test "matches a bare code prefix" do
      assert SequenceGenerator.resolve_step_code("BF", @steps, "X") == "BF"
    end

    test "matches the code prefix before the middle dot label" do
      assert SequenceGenerator.resolve_step_code("BF · Base frontal", @steps, "X") == "BF"
    end

    test "matches by step name (accent/case-insensitive)" do
      assert SequenceGenerator.resolve_step_code("sacada simples", @steps, "X") == "SC"
    end

    test "falls back when the query is empty" do
      assert SequenceGenerator.resolve_step_code("", @steps, "FALL") == "FALL"
    end

    test "falls back when nothing matches" do
      assert SequenceGenerator.resolve_step_code("zzz", @steps, "FALL") == "FALL"
    end
  end
end
