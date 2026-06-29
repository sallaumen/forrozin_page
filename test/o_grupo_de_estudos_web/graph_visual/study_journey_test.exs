defmodule OGrupoDeEstudosWeb.GraphVisual.StudyJourneyTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.GraphVisual.StudyJourney

  defp set(codes), do: MapSet.new(codes)

  describe "frontier/2" do
    test "returns non-learned targets of edges leaving a learned step" do
      edges = [{"BF", "SC"}, {"BF", "IV"}, {"SC", "TR"}, {"XX", "YY"}]
      assert StudyJourney.frontier(set(["BF"]), edges) == set(["SC", "IV"])
    end

    test "excludes targets that are already learned" do
      edges = [{"BF", "SC"}, {"BF", "IV"}]
      assert StudyJourney.frontier(set(["BF", "SC"]), edges) == set(["IV"])
    end

    test "is empty when nothing is learned" do
      assert StudyJourney.frontier(set([]), [{"BF", "SC"}]) == set([])
    end

    test "deduplicates when two learned steps reach the same frontier target" do
      assert StudyJourney.frontier(set(["A", "B"]), [{"A", "C"}, {"B", "C"}]) == set(["C"])
    end
  end

  describe "edge_state/2" do
    test "learned to learned is :learned" do
      assert StudyJourney.edge_state(set(["A", "B"]), {"A", "B"}) == :learned
    end

    test "learned to non-learned is :frontier" do
      assert StudyJourney.edge_state(set(["A"]), {"A", "B"}) == :frontier
    end

    test "a non-learned source is :hidden, even if the target is learned" do
      assert StudyJourney.edge_state(set(["B"]), {"A", "B"}) == :hidden
      assert StudyJourney.edge_state(set([]), {"A", "B"}) == :hidden
    end
  end

  describe "visible_codes/2" do
    test "is the union of learned and frontier" do
      assert StudyJourney.visible_codes(set(["A"]), set(["B", "C"])) == set(["A", "B", "C"])
    end
  end

  describe "next_goal/2" do
    test "returns the first base-plan code not yet learned" do
      assert StudyJourney.next_goal(~w(BF BAL BA GS-ME), set(["BF", "BAL"])) == "BA"
    end

    test "returns nil when the whole base plan is learned" do
      assert StudyJourney.next_goal(~w(BF BAL), set(["BF", "BAL"])) == nil
    end

    test "returns the first step when nothing is learned" do
      assert StudyJourney.next_goal(~w(BF BAL), set([])) == "BF"
    end
  end
end
