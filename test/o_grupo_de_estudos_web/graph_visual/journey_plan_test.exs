defmodule OGrupoDeEstudosWeb.GraphVisual.JourneyPlanTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.GraphVisual.JourneyPlan

  test "base_plan starts at BF, ends at IV and has 12 steps" do
    plan = JourneyPlan.base_plan()

    assert hd(plan) == "BF"
    assert List.last(plan) == "IV"
    assert length(plan) == 12
  end

  describe "next_goal/1" do
    test "returns the first step of the base plan that is not learned yet" do
      assert JourneyPlan.next_goal([]) == "BF"
      assert JourneyPlan.next_goal(["BF", "BAL"]) == "BA"
    end

    test "ignores the order of the learned steps and follows the plan order" do
      assert JourneyPlan.next_goal(["BAL", "BF"]) == "BA"
    end

    test "returns nil when the whole base plan is learned" do
      assert JourneyPlan.next_goal(JourneyPlan.base_plan()) == nil
    end
  end
end
