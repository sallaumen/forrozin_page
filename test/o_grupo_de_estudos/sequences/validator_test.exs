defmodule OGrupoDeEstudos.Sequences.ValidatorTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Admin
  alias OGrupoDeEstudos.Sequences.{SequenceStep, Validator}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Builds a minimal SequenceStep-like struct with step_id set
  defp make_ss(step_id, position) do
    %SequenceStep{step_id: step_id, position: position}
  end

  # ---------------------------------------------------------------------------
  # Empty input
  # ---------------------------------------------------------------------------

  describe "validate/1 with empty list" do
    test "returns :valid for an empty sequence" do
      assert :valid == Validator.validate([])
    end
  end

  # ---------------------------------------------------------------------------
  # :valid cases
  # ---------------------------------------------------------------------------

  describe "validate/1 — valid sequences" do
    test "single active step with no connections needed" do
      step = insert(:step, code: "BF")

      assert :valid == Validator.validate([make_ss(step.id, 1)])
    end

    test "two active steps with an active connection" do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      {:ok, _} = Admin.create_connection(%{source_step_id: step_a.id, target_step_id: step_b.id})

      assert :valid == Validator.validate([make_ss(step_a.id, 1), make_ss(step_b.id, 2)])
    end

    test "three active steps with active connections" do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      step_c = insert(:step, code: "TR")
      {:ok, _} = Admin.create_connection(%{source_step_id: step_a.id, target_step_id: step_b.id})
      {:ok, _} = Admin.create_connection(%{source_step_id: step_b.id, target_step_id: step_c.id})

      assert :valid ==
               Validator.validate([
                 make_ss(step_a.id, 1),
                 make_ss(step_b.id, 2),
                 make_ss(step_c.id, 3)
               ])
    end
  end

  # ---------------------------------------------------------------------------
  # :deleted_step
  # ---------------------------------------------------------------------------

  describe "validate/1 — deleted step issues" do
    test "detects a soft-deleted step" do
      step = insert(:step, code: "BF")
      {:ok, _} = Admin.delete_step(step)

      assert {:invalid, issues} = Validator.validate([make_ss(step.id, 1)])
      assert [%{position: 1, type: :deleted_step, code: "BF"}] = issues
    end

    test "detects deleted step among active ones" do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      {:ok, _} = Admin.create_connection(%{source_step_id: step_a.id, target_step_id: step_b.id})
      {:ok, _} = Admin.delete_step(step_b)

      assert {:invalid, issues} =
               Validator.validate([make_ss(step_a.id, 1), make_ss(step_b.id, 2)])

      deleted_step_issues = Enum.filter(issues, &(&1.type == :deleted_step))
      assert [_] = deleted_step_issues
      assert hd(deleted_step_issues).position == 2
      assert hd(deleted_step_issues).code == "SC"
    end
  end

  # ---------------------------------------------------------------------------
  # :missing_connection
  # ---------------------------------------------------------------------------

  describe "validate/1 — missing connection issues" do
    test "detects missing connection between two active steps" do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")

      assert {:invalid, issues} =
               Validator.validate([make_ss(step_a.id, 1), make_ss(step_b.id, 2)])

      assert [%{position: 1, type: :missing_connection}] = issues
      assert String.contains?(hd(issues).code, "BF")
      assert String.contains?(hd(issues).code, "SC")
    end

    test "reports missing connection at the correct position" do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      step_c = insert(:step, code: "TR")
      {:ok, _} = Admin.create_connection(%{source_step_id: step_a.id, target_step_id: step_b.id})
      # No connection from B → C

      assert {:invalid, issues} =
               Validator.validate([
                 make_ss(step_a.id, 1),
                 make_ss(step_b.id, 2),
                 make_ss(step_c.id, 3)
               ])

      assert [%{position: 2, type: :missing_connection}] = issues
    end
  end

  # ---------------------------------------------------------------------------
  # :deleted_connection
  # ---------------------------------------------------------------------------

  describe "validate/1 — deleted connection issues" do
    test "detects a soft-deleted connection between two active steps" do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")

      {:ok, conn} =
        Admin.create_connection(%{source_step_id: step_a.id, target_step_id: step_b.id})

      {:ok, _} = Admin.delete_connection(conn.id)

      assert {:invalid, issues} =
               Validator.validate([make_ss(step_a.id, 1), make_ss(step_b.id, 2)])

      assert [%{position: 1, type: :deleted_connection}] = issues
      assert String.contains?(hd(issues).code, "BF")
      assert String.contains?(hd(issues).code, "SC")
    end
  end

  # ---------------------------------------------------------------------------
  # Multiple issues in a single sequence
  # ---------------------------------------------------------------------------

  describe "validate/1 — multiple issues" do
    test "reports both deleted step and missing connection" do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      # No connection and step_b is deleted
      {:ok, _} = Admin.delete_step(step_b)

      assert {:invalid, issues} =
               Validator.validate([make_ss(step_a.id, 1), make_ss(step_b.id, 2)])

      types = Enum.map(issues, & &1.type) |> MapSet.new()
      assert MapSet.member?(types, :deleted_step)
    end
  end
end
