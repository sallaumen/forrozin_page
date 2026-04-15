defmodule Forrozin.Encyclopedia.ConnectionQueryTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Encyclopedia.ConnectionQuery

  # ---------------------------------------------------------------------------
  # get_by/1
  # ---------------------------------------------------------------------------

  describe "get_by/1 with :source_step_id" do
    test "returns the connection with the given source_step_id" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      insert(:connection, source_step: source, target_step: target)

      assert %{source_step_id: id} = ConnectionQuery.get_by(source_step_id: source.id)
      assert id == source.id
    end

    test "returns nil when no connection found" do
      source = insert(:step, code: "BF")
      assert nil == ConnectionQuery.get_by(source_step_id: source.id)
    end
  end

  describe "get_by/1 with :source_code and :target_code" do
    test "finds a connection by step codes" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      insert(:connection, source_step: source, target_step: target)

      result = ConnectionQuery.get_by(source_code: "BF", target_code: "SC")

      assert result != nil
      assert result.source_step_id == source.id
      assert result.target_step_id == target.id
    end

    test "returns nil when connection does not exist" do
      insert(:step, code: "BF")
      insert(:step, code: "SC")

      assert nil == ConnectionQuery.get_by(source_code: "BF", target_code: "SC")
    end

    test "returns nil when only one direction exists" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      insert(:connection, source_step: source, target_step: target)

      # Reversed direction should not be found
      assert nil == ConnectionQuery.get_by(source_code: "SC", target_code: "BF")
    end
  end

  describe "get_by/1 with :preload" do
    test "preloads the requested associations" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      insert(:connection, source_step: source, target_step: target)

      result =
        ConnectionQuery.get_by(source_step_id: source.id, preload: [:source_step, :target_step])

      assert result.source_step.code == "BF"
      assert result.target_step.code == "SC"
    end
  end

  # ---------------------------------------------------------------------------
  # list_by/1
  # ---------------------------------------------------------------------------

  describe "list_by/1 defaults" do
    test "returns all connections" do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      step_c = insert(:step, code: "GP")
      insert(:connection, source_step: step_a, target_step: step_b)
      insert(:connection, source_step: step_b, target_step: step_c)

      assert [_, _] = ConnectionQuery.list_by()
    end

    test "returns empty list when no connections" do
      assert ConnectionQuery.list_by() == []
    end
  end

  describe "list_by/1 with :source_step_id" do
    test "returns only outgoing connections from the given step" do
      source = insert(:step, code: "BF")
      target1 = insert(:step, code: "SC")
      target2 = insert(:step, code: "GP")
      other = insert(:step, code: "IV")

      insert(:connection, source_step: source, target_step: target1)
      insert(:connection, source_step: source, target_step: target2)
      insert(:connection, source_step: other, target_step: source)

      results = ConnectionQuery.list_by(source_step_id: source.id)

      assert [_, _] = results
      assert Enum.all?(results, &(&1.source_step_id == source.id))
    end
  end

  describe "list_by/1 with :target_step_id" do
    test "returns only incoming connections to the given step" do
      source1 = insert(:step, code: "BF")
      source2 = insert(:step, code: "SC")
      target = insert(:step, code: "GP")

      insert(:connection, source_step: source1, target_step: target)
      insert(:connection, source_step: source2, target_step: target)

      results = ConnectionQuery.list_by(target_step_id: target.id)

      assert [_, _] = results
      assert Enum.all?(results, &(&1.target_step_id == target.id))
    end
  end

  describe "list_by/1 with :step_ids" do
    test "returns only connections where both endpoints are in the given id list" do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      step_c = insert(:step, code: "GP")
      outsider = insert(:step, code: "IV")

      insert(:connection, source_step: step_a, target_step: step_b)
      insert(:connection, source_step: step_b, target_step: step_c)
      insert(:connection, source_step: step_a, target_step: outsider)

      ids = [step_a.id, step_b.id, step_c.id]
      results = ConnectionQuery.list_by(step_ids: ids)

      assert [_, _] = results

      Enum.each(results, fn c ->
        assert c.source_step_id in ids
        assert c.target_step_id in ids
      end)
    end
  end

  describe "list_by/1 with :preload" do
    test "preloads source_step and target_step" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      insert(:connection, source_step: source, target_step: target)

      [result] =
        ConnectionQuery.list_by(source_step_id: source.id, preload: [:source_step, :target_step])

      assert result.source_step.code == "BF"
      assert result.target_step.code == "SC"
    end
  end

  # ---------------------------------------------------------------------------
  # delete_all_by/1
  # ---------------------------------------------------------------------------

  describe "delete_all_by/1 with :either_step_id" do
    test "deletes all connections where step is source or target" do
      step = insert(:step, code: "BF")
      other1 = insert(:step, code: "SC")
      other2 = insert(:step, code: "GP")
      unrelated_a = insert(:step, code: "IV")
      unrelated_b = insert(:step, code: "TR")

      insert(:connection, source_step: step, target_step: other1)
      insert(:connection, source_step: other2, target_step: step)
      insert(:connection, source_step: unrelated_a, target_step: unrelated_b)

      {count, _} = ConnectionQuery.delete_all_by(either_step_id: step.id)

      assert count == 2
      assert [_] = ConnectionQuery.list_by()
    end
  end
end
