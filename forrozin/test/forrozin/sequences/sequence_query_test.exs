defmodule Forrozin.Sequences.SequenceQueryTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Sequences.SequenceQuery

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_sequence(user, attrs) do
    name = Keyword.get(attrs, :name, "Sequência Teste")
    insert(:sequence, user: user, name: name)
  end

  # ---------------------------------------------------------------------------
  # list_by/1
  # ---------------------------------------------------------------------------

  describe "list_by/1 with :user_id" do
    test "returns only sequences belonging to the given user" do
      user_a = insert(:user)
      user_b = insert(:user)

      seq_a = create_sequence(user_a, name: "Sequência de A")
      _seq_b = create_sequence(user_b, name: "Sequência de B")

      results = SequenceQuery.list_by(user_id: user_a.id)
      ids = Enum.map(results, & &1.id)

      assert seq_a.id in ids
      assert length(results) == 1
    end

    test "returns empty list when user has no sequences" do
      user = insert(:user)

      assert SequenceQuery.list_by(user_id: user.id) == []
    end

    test "returns multiple sequences for the same user" do
      user = insert(:user)
      _s1 = create_sequence(user, name: "Sequência 1")
      _s2 = create_sequence(user, name: "Sequência 2")

      results = SequenceQuery.list_by(user_id: user.id)

      assert length(results) == 2
    end
  end

  describe "list_by/1 default ordering" do
    test "orders by inserted_at descending by default" do
      user = insert(:user)

      # Insert with different timestamps using override
      s1 = insert(:sequence, user: user, name: "Antiga", inserted_at: ~N[2026-01-01 10:00:00])
      s2 = insert(:sequence, user: user, name: "Nova", inserted_at: ~N[2026-06-01 10:00:00])

      results = SequenceQuery.list_by(user_id: user.id)
      ids = Enum.map(results, & &1.id)

      assert List.first(ids) == s2.id
      assert List.last(ids) == s1.id
    end
  end

  describe "list_by/1 with :preload" do
    test "preloads sequence_steps" do
      user = insert(:user)
      sequence = insert(:sequence, user: user)
      step = insert(:step)
      insert(:sequence_step, sequence: sequence, step: step, position: 1)

      [result] = SequenceQuery.list_by(user_id: user.id, preload: [:sequence_steps])

      assert length(result.sequence_steps) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # get_by/1
  # ---------------------------------------------------------------------------

  describe "get_by/1 with :id" do
    test "returns the sequence with the given id" do
      user = insert(:user)
      sequence = create_sequence(user, name: "Sequência Específica")

      result = SequenceQuery.get_by(id: sequence.id)

      assert result.id == sequence.id
      assert result.name == "Sequência Específica"
    end

    test "returns nil when the id does not exist" do
      result = SequenceQuery.get_by(id: Ecto.UUID.generate())

      assert is_nil(result)
    end
  end

  describe "get_by/1 with :preload" do
    test "preloads sequence_steps with step" do
      user = insert(:user)
      sequence = insert(:sequence, user: user)
      step = insert(:step, code: "BF", name: "Base Frontal")
      insert(:sequence_step, sequence: sequence, step: step, position: 1)

      result = SequenceQuery.get_by(id: sequence.id, preload: [sequence_steps: :step])

      assert length(result.sequence_steps) == 1
      assert hd(result.sequence_steps).step.code == "BF"
    end
  end
end
