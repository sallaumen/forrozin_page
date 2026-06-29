defmodule OGrupoDeEstudosWeb.GraphVisual.JourneyPlanTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.GraphVisual.JourneyPlan

  test "base_plan começa em BF, termina em IV e tem 12 passos" do
    plan = JourneyPlan.base_plan()

    assert hd(plan) == "BF"
    assert List.last(plan) == "IV"
    assert length(plan) == 12
  end

  describe "next_goal/1" do
    test "é o primeiro passo do plano-base ainda não aprendido" do
      assert JourneyPlan.next_goal([]) == "BF"
      assert JourneyPlan.next_goal(["BF", "BAL"]) == "BA"
    end

    test "ignora ordem dos aprendidos (usa a ordem do plano)" do
      assert JourneyPlan.next_goal(["BAL", "BF"]) == "BA"
    end

    test "é nil quando todo o plano-base foi aprendido" do
      assert JourneyPlan.next_goal(JourneyPlan.base_plan()) == nil
    end
  end
end
