defmodule Forrozin.SequencesTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Sequences

  # ---------------------------------------------------------------------------
  # create_sequence/4
  # ---------------------------------------------------------------------------

  describe "create_sequence/4" do
    test "creates a sequence with the given steps in order" do
      user = insert(:user)
      step_a = insert(:step, code: "BF", name: "Base Frontal")
      step_b = insert(:step, code: "SC", name: "Sacada")
      step_c = insert(:step, code: "TR", name: "Trava")

      assert {:ok, sequence} =
               Sequences.create_sequence(user.id, "Aula de Terça", [step_a.id, step_b.id, step_c.id])

      assert sequence.name == "Aula de Terça"
      assert sequence.user_id == user.id

      positions = Enum.map(sequence.sequence_steps, & &1.position)
      assert positions == [1, 2, 3]

      codes = Enum.map(sequence.sequence_steps, & &1.step.code)
      assert codes == ["BF", "SC", "TR"]
    end

    test "creates a sequence with allow_repeats true" do
      user = insert(:user)
      step = insert(:step, code: "BF", name: "Base Frontal")

      assert {:ok, sequence} =
               Sequences.create_sequence(user.id, "Repetida", [step.id, step.id], true)

      assert sequence.allow_repeats == true
      assert length(sequence.sequence_steps) == 2
    end

    test "returns error when name is missing" do
      user = insert(:user)

      assert {:error, changeset} = Sequences.create_sequence(user.id, "", [])

      assert %{name: [_]} = errors_on(changeset)
    end

    test "returns error when user_id is invalid" do
      assert {:error, changeset} =
               Sequences.create_sequence(Ecto.UUID.generate(), "Sequência", [])

      assert %{user_id: [_]} = errors_on(changeset)
    end

    test "preloads sequence_steps with step on success" do
      user = insert(:user)
      step = insert(:step, code: "BF", name: "Base Frontal")

      {:ok, sequence} = Sequences.create_sequence(user.id, "Com Passo", [step.id])

      assert [seq_step] = sequence.sequence_steps
      assert seq_step.step.id == step.id
    end

    test "rolls back if a sequence_step insert fails" do
      user = insert(:user)

      # Pass a non-existent step_id — insert! will raise, triggering rollback
      assert_raise Ecto.InvalidChangesetError, fn ->
        Sequences.create_sequence(user.id, "Rollback Test", [Ecto.UUID.generate()])
      end

      # No sequence should have been persisted
      assert Sequences.list_user_sequences(user.id) == []
    end
  end

  # ---------------------------------------------------------------------------
  # list_user_sequences/1
  # ---------------------------------------------------------------------------

  describe "list_user_sequences/1" do
    test "returns all sequences for the given user" do
      user = insert(:user)
      s1 = insert(:sequence, user: user, name: "Sequência 1")
      s2 = insert(:sequence, user: user, name: "Sequência 2")

      results = Sequences.list_user_sequences(user.id)
      ids = Enum.map(results, & &1.id)

      assert s1.id in ids
      assert s2.id in ids
    end

    test "does not return sequences belonging to another user" do
      user_a = insert(:user)
      user_b = insert(:user)

      _seq_b = insert(:sequence, user: user_b, name: "Sequência de B")

      assert Sequences.list_user_sequences(user_a.id) == []
    end

    test "returns empty list when user has no sequences" do
      user = insert(:user)

      assert Sequences.list_user_sequences(user.id) == []
    end

    test "preloads sequence_steps with step" do
      user = insert(:user)
      step = insert(:step, code: "BF", name: "Base Frontal")
      sequence = insert(:sequence, user: user)
      insert(:sequence_step, sequence: sequence, step: step, position: 1)

      [result] = Sequences.list_user_sequences(user.id)

      assert [seq_step] = result.sequence_steps
      assert seq_step.step.code == "BF"
    end
  end

  # ---------------------------------------------------------------------------
  # get_sequence/1
  # ---------------------------------------------------------------------------

  describe "get_sequence/1" do
    test "returns the sequence with preloaded steps" do
      user = insert(:user)
      step = insert(:step, code: "BF", name: "Base Frontal")
      sequence = insert(:sequence, user: user, name: "Sequência Específica")
      insert(:sequence_step, sequence: sequence, step: step, position: 1)

      result = Sequences.get_sequence(sequence.id)

      assert result.id == sequence.id
      assert result.name == "Sequência Específica"
      assert [seq_step] = result.sequence_steps
      assert seq_step.step.code == "BF"
    end

    test "returns nil when sequence does not exist" do
      assert is_nil(Sequences.get_sequence(Ecto.UUID.generate()))
    end
  end

  # ---------------------------------------------------------------------------
  # delete_sequence/1
  # ---------------------------------------------------------------------------

  describe "delete_sequence/1" do
    test "removes the sequence from the database" do
      user = insert(:user)
      sequence = insert(:sequence, user: user)

      assert {:ok, _} = Sequences.delete_sequence(sequence)

      assert is_nil(Sequences.get_sequence(sequence.id))
    end

    test "cascades deletion of sequence_steps" do
      user = insert(:user)
      step = insert(:step)
      sequence = insert(:sequence, user: user)
      _seq_step = insert(:sequence_step, sequence: sequence, step: step, position: 1)

      {:ok, _} = Sequences.delete_sequence(sequence)

      # Verify sequence is gone
      assert is_nil(Sequences.get_sequence(sequence.id))

      # Verify sequence_steps are gone (cascade)
      count =
        Forrozin.Repo.aggregate(
          Ecto.Query.from(ss in Forrozin.Sequences.SequenceStep,
            where: ss.sequence_id == ^sequence.id
          ),
          :count
        )

      assert count == 0
    end
  end

  # ---------------------------------------------------------------------------
  # update_sequence/2
  # ---------------------------------------------------------------------------

  describe "update_sequence/2" do
    test "updates the sequence name" do
      user = insert(:user)
      sequence = insert(:sequence, user: user, name: "Nome Antigo")

      assert {:ok, updated} = Sequences.update_sequence(sequence, %{name: "Nome Novo"})

      assert updated.name == "Nome Novo"
    end

    test "updates allow_repeats" do
      user = insert(:user)
      sequence = insert(:sequence, user: user, allow_repeats: false)

      assert {:ok, updated} = Sequences.update_sequence(sequence, %{allow_repeats: true})

      assert updated.allow_repeats == true
    end

    test "returns error changeset when name is blank" do
      user = insert(:user)
      sequence = insert(:sequence, user: user, name: "Válido")

      assert {:error, changeset} = Sequences.update_sequence(sequence, %{name: ""})

      assert %{name: [_]} = errors_on(changeset)
    end
  end
end
