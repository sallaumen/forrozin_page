defmodule OGrupoDeEstudosWeb.Helpers.NotificationRoutesTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.Helpers.NotificationRoutes

  @targets %{
    steps: %{"step-1" => %{code: "BF", name: "Base Frontal"}},
    users: %{"user-1" => %{id: "user-1", username: "maria", name: "Maria", avatar_path: nil}}
  }

  defp notif(attrs) do
    Map.merge(
      %{action: :liked_step, target_type: nil, target_id: nil, parent_type: nil, parent_id: nil},
      attrs
    )
  end

  describe "path/2" do
    test "study nudge goes to the shared diary" do
      n = notif(%{action: :study_nudge, target_type: "study_link", target_id: "l1"})
      assert NotificationRoutes.path(n, @targets) == "/study/shared/l1"
    end

    test "shared note update goes to the shared diary" do
      n = notif(%{action: :shared_note_updated, target_type: "study_link", target_id: "l1"})
      assert NotificationRoutes.path(n, @targets) == "/study/shared/l1"
    end

    test "study_link parent goes to the study area" do
      n = notif(%{parent_type: "study_link", parent_id: "l1"})
      assert NotificationRoutes.path(n, @targets) == "/study"
    end

    test "step parent resolves to the step page" do
      n = notif(%{parent_type: "step", parent_id: "step-1"})
      assert NotificationRoutes.path(n, @targets) == "/steps/BF"
    end

    test "unknown step falls back to the collection" do
      n = notif(%{parent_type: "step", parent_id: "missing"})
      assert NotificationRoutes.path(n, @targets) == "/collection"
    end

    test "profile parent resolves to the user page" do
      n = notif(%{parent_type: "profile", parent_id: "user-1"})
      assert NotificationRoutes.path(n, @targets) == "/users/maria"
    end

    test "unknown profile falls back to the collection" do
      n = notif(%{parent_type: "profile", parent_id: "missing"})
      assert NotificationRoutes.path(n, @targets) == "/collection"
    end

    test "sequence parent goes to the sequence page" do
      n = notif(%{parent_type: "sequence", parent_id: "seq-1"})
      assert NotificationRoutes.path(n, @targets) == "/sequence"
    end

    test "anything else falls back to the collection" do
      assert NotificationRoutes.path(notif(%{}), @targets) == "/collection"
    end
  end

  describe "step_name/2" do
    test "returns the parent step name when resolvable" do
      n = notif(%{parent_type: "step", parent_id: "step-1"})
      assert NotificationRoutes.step_name(n, @targets) == "Base Frontal"
    end

    test "returns nil for unknown steps and other parents" do
      assert NotificationRoutes.step_name(notif(%{parent_type: "step", parent_id: "x"}), @targets) ==
               nil

      assert NotificationRoutes.step_name(notif(%{parent_type: "sequence"}), @targets) == nil
    end
  end
end
