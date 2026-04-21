defmodule OGrupoDeEstudos.Sequences.GeneratorTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Sequences.Generator

  # ---------------------------------------------------------------------------
  # Helpers — build a small connected graph in the DB for each test
  # ---------------------------------------------------------------------------

  defp build_linear_chain(n) when n >= 2 do
    steps =
      for i <- 0..(n - 1) do
        insert(:step,
          code: "C#{i}",
          name: "Chain Step #{i}",
          wip: false,
          status: "published",
          approved: true
        )
      end

    steps
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [src, tgt] ->
      insert(:connection, source_step: src, target_step: tgt)
    end)

    by_code = Map.new(steps, &{&1.code, &1})
    {steps, by_code}
  end

  defp add_loop(steps) do
    insert(:connection, source_step: List.last(steps), target_step: hd(steps))
  end

  defp base_params(start_code, opts) do
    %{
      start_code: start_code,
      length: Keyword.get(opts, :length, 3),
      count: Keyword.get(opts, :count, 1),
      required_codes: Keyword.get(opts, :required_codes, []),
      allow_repeats: Keyword.get(opts, :allow_repeats, false),
      cyclic: Keyword.get(opts, :cyclic, false)
    }
  end

  # ---------------------------------------------------------------------------
  # Basic generation
  # ---------------------------------------------------------------------------

  describe "generate/1 — basic" do
    test "returns ok tuple with sequence and no warnings on valid input" do
      build_linear_chain(5)

      assert {:ok, sequences, warnings} =
               Generator.generate(base_params("C0", length: 5, count: 1))

      assert [_] = sequences
      assert warnings == []
    end

    test "generates a sequence starting with the requested start step" do
      build_linear_chain(4)

      {:ok, [sequence], _warnings} =
        Generator.generate(base_params("C0", length: 3, count: 1))

      assert hd(sequence).code == "C0"
    end

    test "respects the requested sequence length" do
      build_linear_chain(5)

      {:ok, [sequence], _warnings} =
        Generator.generate(base_params("C0", length: 4, count: 1))

      assert length(sequence) == 4
    end

    test "each step in the result has :id, :code, and :name keys" do
      build_linear_chain(3)

      {:ok, [sequence], _warnings} =
        Generator.generate(base_params("C0", length: 3, count: 1))

      for step <- sequence do
        assert Map.has_key?(step, :id)
        assert Map.has_key?(step, :code)
        assert Map.has_key?(step, :name)
      end
    end

    test "uses every public graph step without requiring approval" do
      step_a =
        insert(:step,
          code: "UA",
          name: "Unapproved start",
          wip: false,
          status: "published",
          approved: false
        )

      step_b =
        insert(:step,
          code: "UB",
          name: "Unapproved target",
          wip: false,
          status: "published",
          approved: false
        )

      insert(:connection, source_step: step_a, target_step: step_b)

      {:ok, [sequence], []} =
        Generator.generate(base_params("UA", length: 2, count: 1))

      assert Enum.map(sequence, & &1.code) == ["UA", "UB"]
    end
  end

  # ---------------------------------------------------------------------------
  # Invalid start step
  # ---------------------------------------------------------------------------

  describe "generate/1 — invalid start code" do
    test "returns empty sequences and a warning when start code is not found" do
      assert {:ok, [], [warning]} =
               Generator.generate(base_params("INEXISTENTE", length: 3, count: 1))

      assert warning =~ "INEXISTENTE"
    end

    test "does not crash when there are no steps in the DB" do
      assert {:ok, [], [_warning]} =
               Generator.generate(base_params("NADA", length: 3, count: 1))
    end
  end

  # ---------------------------------------------------------------------------
  # allow_repeats: false (default)
  # ---------------------------------------------------------------------------

  describe "generate/1 — allow_repeats: false" do
    test "does not repeat steps in a sequence" do
      build_linear_chain(4)

      {:ok, [sequence], _warnings} =
        Generator.generate(base_params("C0", length: 4, allow_repeats: false))

      codes = Enum.map(sequence, & &1.code)
      assert codes == Enum.uniq(codes)
    end

    test "returns nil (no sequence) when graph is too short without repeats" do
      build_linear_chain(3)

      {:ok, sequences, warnings} =
        Generator.generate(base_params("C0", length: 5, count: 1, allow_repeats: false))

      assert sequences == [] or "Gerou 0 de 1 sequências solicitadas" in warnings
    end
  end

  # ---------------------------------------------------------------------------
  # allow_repeats: true
  # ---------------------------------------------------------------------------

  describe "generate/1 — allow_repeats: true" do
    test "can generate a sequence longer than the number of steps when repeats are allowed" do
      {steps, _by_code} = build_linear_chain(3)
      add_loop(steps)

      {:ok, sequences, _warnings} =
        Generator.generate(base_params("C0", length: 10, count: 1, allow_repeats: true))

      assert [_] = sequences
      assert length(hd(sequences)) == 10
    end

    test "limits repeated identical transitions when max_same_pair_loops is provided" do
      first =
        insert(:step,
          code: "L0",
          name: "Loop 0",
          wip: false,
          status: "published",
          approved: true
        )

      second =
        insert(:step,
          code: "L1",
          name: "Loop 1",
          wip: false,
          status: "published",
          approved: true
        )

      insert(:connection, source_step: first, target_step: second)
      insert(:connection, source_step: second, target_step: first)

      {:ok, [], warnings} =
        Generator.generate(
          base_params("L0",
            length: 7,
            count: 1,
            allow_repeats: true
          )
          |> Map.put(:max_same_pair_loops, 2)
        )

      assert "Gerou 0 de 1 sequências solicitadas" in warnings

      {:ok, [sequence], _warnings} =
        Generator.generate(
          base_params("L0",
            length: 7,
            count: 1,
            allow_repeats: true
          )
          |> Map.put(:max_same_pair_loops, 3)
        )

      assert Enum.map(sequence, & &1.code) == ["L0", "L1", "L0", "L1", "L0", "L1", "L0"]
    end
  end

  # ---------------------------------------------------------------------------
  # Required codes
  # ---------------------------------------------------------------------------

  describe "generate/1 — required_codes" do
    test "includes required step when it is reachable" do
      build_linear_chain(5)

      {:ok, [sequence], warnings} =
        Generator.generate(base_params("C0", length: 5, count: 1, required_codes: ["C3"]))

      codes = Enum.map(sequence, & &1.code)
      assert "C3" in codes
      assert warnings == []
    end

    test "warns when required code does not exist in the database" do
      build_linear_chain(3)

      {:ok, _sequences, warnings} =
        Generator.generate(base_params("C0", length: 3, count: 1, required_codes: ["FANTASMA"]))

      assert Enum.any?(warnings, &(&1 =~ "FANTASMA"))
      assert Enum.any?(warnings, &(&1 =~ "não encontrado"))
    end

    test "warns when required step is unreachable from start" do
      # Two disconnected components: C0->C1->C2 and D0->D1
      build_linear_chain(3)

      d0 =
        insert(:step,
          code: "D0",
          name: "Disconnected 0",
          wip: false,
          status: "published",
          approved: true
        )

      d1 =
        insert(:step,
          code: "D1",
          name: "Disconnected 1",
          wip: false,
          status: "published",
          approved: true
        )

      insert(:connection, source_step: d0, target_step: d1)

      {:ok, _sequences, warnings} =
        Generator.generate(base_params("C0", length: 3, count: 1, required_codes: ["D0"]))

      assert Enum.any?(warnings, &(&1 =~ "inalcançável"))
      assert Enum.any?(warnings, &(&1 =~ "D0"))
    end

    test "warning mentions missed required step codes for reachable but not included" do
      # Chain: C0 -> C1 -> C2 -> C3 -> C4
      # With length=3, C0->C1->C2 is the only path
      # C4 is reachable but can't fit in length 3
      build_linear_chain(5)

      {:ok, [sequence], warnings} =
        Generator.generate(base_params("C0", length: 3, count: 1, required_codes: ["C4"]))

      codes = Enum.map(sequence, & &1.code)

      # C4 is at position 4 but we only have 3 steps, so it likely won't be included
      if "C4" not in codes do
        assert Enum.any?(warnings, &(&1 =~ "C4"))
      end
    end

    test "handles multiple required codes, some valid and some invalid" do
      build_linear_chain(5)

      {:ok, _sequences, warnings} =
        Generator.generate(
          base_params("C0", length: 5, count: 1, required_codes: ["C2", "INEXISTENTE", "C4"])
        )

      # Should warn about INEXISTENTE being not found
      assert Enum.any?(warnings, &(&1 =~ "INEXISTENTE"))
    end

    test "does not warn about unresolved codes when required_codes is empty" do
      build_linear_chain(3)

      {:ok, [_sequence], warnings} =
        Generator.generate(base_params("C0", length: 3, count: 1, required_codes: []))

      refute Enum.any?(warnings, &(&1 =~ "não encontrado"))
    end
  end

  # ---------------------------------------------------------------------------
  # Cyclic sequences
  # ---------------------------------------------------------------------------

  describe "generate/1 — cyclic" do
    test "cyclic sequence starts and ends with the same step" do
      # C0→C1→C2→C3→C0 needs length=5 to complete the cycle
      {steps, _} = build_linear_chain(4)
      add_loop(steps)

      {:ok, [sequence], _warnings} =
        Generator.generate(base_params("C0", length: 5, count: 1, cyclic: true))

      assert hd(sequence).code == "C0"
      assert List.last(sequence).code == "C0"
    end

    test "cyclic sequence fails when no loop exists" do
      build_linear_chain(4)

      {:ok, sequences, warnings} =
        Generator.generate(base_params("C0", length: 4, count: 1, cyclic: true))

      assert sequences == []
      assert Enum.any?(warnings, &(&1 =~ "sequências"))
    end
  end

  # ---------------------------------------------------------------------------
  # Multiple distinct sequences
  # ---------------------------------------------------------------------------

  describe "generate/1 — count" do
    test "generates multiple distinct sequences when multiple paths exist" do
      s0 = insert(:step, code: "B0", name: "Branch 0", wip: false, status: "published", approved: true)
      s1 = insert(:step, code: "B1", name: "Branch 1", wip: false, status: "published", approved: true)
      s2 = insert(:step, code: "B2", name: "Branch 2", wip: false, status: "published", approved: true)
      s3 = insert(:step, code: "B3", name: "Branch 3", wip: false, status: "published", approved: true)
      s4 = insert(:step, code: "B4", name: "Branch 4", wip: false, status: "published", approved: true)

      insert(:connection, source_step: s0, target_step: s1)
      insert(:connection, source_step: s0, target_step: s2)
      insert(:connection, source_step: s1, target_step: s3)
      insert(:connection, source_step: s2, target_step: s4)

      {:ok, sequences, _warnings} =
        Generator.generate(base_params("B0", length: 3, count: 20))

      distinct_middles =
        sequences
        |> Enum.map(fn seq -> Enum.at(seq, 1).code end)
        |> Enum.uniq()
        |> length()

      assert distinct_middles == 2
    end

    test "emits warning when fewer sequences than requested are generated" do
      build_linear_chain(3)

      {:ok, sequences, warnings} =
        Generator.generate(base_params("C0", length: 3, count: 5))

      assert length(sequences) <= 1
      assert Enum.any?(warnings, fn w -> w =~ "sequências" end)
    end

    test "deduplicates identical sequences" do
      build_linear_chain(3)

      {:ok, sequences, _warnings} =
        Generator.generate(base_params("C0", length: 3, count: 3))

      assert length(sequences) <= 1
    end
  end

  # ---------------------------------------------------------------------------
  # Reachability
  # ---------------------------------------------------------------------------

  describe "reachable_from/2" do
    test "finds all reachable nodes via BFS" do
      {steps, _} = build_linear_chain(4)

      connections = OGrupoDeEstudos.Encyclopedia.ConnectionQuery.list_by(preload: [])
      adjacency = Map.new(connections |> Enum.group_by(& &1.source_step_id), fn {k, v} ->
        {k, Enum.map(v, & &1.target_step_id)}
      end)

      reachable = Generator.reachable_from(hd(steps).id, adjacency)

      # C0 can reach all 4 steps
      assert MapSet.size(reachable) == 4

      # C2 can only reach C2, C3
      reachable_from_c2 = Generator.reachable_from(Enum.at(steps, 2).id, adjacency)
      assert MapSet.size(reachable_from_c2) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases
  # ---------------------------------------------------------------------------

  describe "generate/1 — edge cases" do
    test "handles length of 1 (just the start step)" do
      build_linear_chain(3)

      {:ok, [sequence], _warnings} =
        Generator.generate(base_params("C0", length: 1, count: 1))

      assert length(sequence) == 1
      assert hd(sequence).code == "C0"
    end

    test "handles length of 2" do
      build_linear_chain(3)

      {:ok, [sequence], _warnings} =
        Generator.generate(base_params("C0", length: 2, count: 1))

      assert length(sequence) == 2
      assert hd(sequence).code == "C0"
      assert List.last(sequence).code == "C1"
    end

    test "handles nil required_codes gracefully" do
      build_linear_chain(3)

      {:ok, [_sequence], warnings} =
        Generator.generate(base_params("C0", length: 3, count: 1) |> Map.put(:required_codes, nil))

      refute Enum.any?(warnings, &(&1 =~ "não encontrado"))
    end

    test "start step with no outgoing connections returns empty with warning" do
      # Isolated step with no connections
      insert(:step,
        code: "ALONE",
        name: "Lonely",
        wip: false,
        status: "published",
        approved: true
      )

      {:ok, sequences, warnings} =
        Generator.generate(base_params("ALONE", length: 3, count: 1))

      assert sequences == []
      assert Enum.any?(warnings, &(&1 =~ "sequências"))
    end
  end
end
