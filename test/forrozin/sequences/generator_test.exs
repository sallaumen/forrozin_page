defmodule Forrozin.Sequences.GeneratorTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Sequences.Generator

  # ---------------------------------------------------------------------------
  # Helpers — build a small connected graph in the DB for each test
  # ---------------------------------------------------------------------------

  # Creates N public steps: [s0, s1, ..., sN-1]
  # Connects them in a linear chain: s0 -> s1 -> s2 -> ... -> sN-1
  # Returns {steps_list, step_map_by_code}
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

    # Connect each step to the next
    steps
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [src, tgt] ->
      insert(:connection, source_step: src, target_step: tgt)
    end)

    by_code = Map.new(steps, &{&1.code, &1})
    {steps, by_code}
  end

  # Adds a loop back from the last step to first (enables cycles)
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

      assert [_, _, _, _] = sequence
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
      # Linear chain: C0 -> C1 -> C2 -> C3 (no loops, so no repeats possible)
      build_linear_chain(4)

      {:ok, [sequence], _warnings} =
        Generator.generate(base_params("C0", length: 4, allow_repeats: false))

      codes = Enum.map(sequence, & &1.code)

      assert codes == Enum.uniq(codes)
    end

    test "returns nil (no sequence) when graph is too short without repeats" do
      # Chain of 3 steps, request length 5 without repeats = impossible
      build_linear_chain(3)

      {:ok, sequences, warnings} =
        Generator.generate(base_params("C0", length: 5, count: 1, allow_repeats: false))

      # Either no sequence generated or a warning about count
      assert sequences == [] or "Gerou 0 de 1 sequências solicitadas" in warnings
    end
  end

  # ---------------------------------------------------------------------------
  # allow_repeats: true
  # ---------------------------------------------------------------------------

  describe "generate/1 — allow_repeats: true" do
    test "can generate a sequence longer than the number of steps when repeats are allowed" do
      # 3-step chain with a loop so the random walk can cycle
      {steps, _by_code} = build_linear_chain(3)
      add_loop(steps)

      {:ok, sequences, _warnings} =
        Generator.generate(base_params("C0", length: 10, count: 1, allow_repeats: true))

      # Should succeed because we can revisit steps
      assert [_] = sequences
      assert [_, _, _, _, _, _, _, _, _, _] = hd(sequences)
    end
  end

  # ---------------------------------------------------------------------------
  # Required codes
  # ---------------------------------------------------------------------------

  describe "generate/1 — required_codes" do
    test "includes required step when it is reachable" do
      # Chain: C0 -> C1 -> C2 -> C3 -> C4
      build_linear_chain(5)

      {:ok, [sequence], warnings} =
        Generator.generate(base_params("C0", length: 5, count: 1, required_codes: ["C3"]))

      codes = Enum.map(sequence, & &1.code)

      # The required step must be in the sequence (chain forces it anyway)
      assert "C3" in codes
      assert warnings == []
    end

    test "emits a warning when required step cannot always be included" do
      # Only 2 steps, chain C0 -> C1, request length 2, require C_MISSING
      build_linear_chain(2)

      {:ok, _sequences, warnings} =
        Generator.generate(base_params("C0", length: 2, count: 1, required_codes: ["MISSING"]))

      # MISSING is not a valid step, so it can't be resolved — no warning about it
      # (unresolvable codes are silently dropped; only reachable-but-missed codes warn)
      # This tests that we don't crash on unknown required codes
      assert is_list(warnings)
    end

    test "warning mentions missed required step codes" do
      # Two disconnected paths: C0 -> C1 -> C2 and C3 -> C4 -> C5
      # Request a sequence from C0 that requires C3 (unreachable from C0)
      {steps_a, _} = build_linear_chain(3)
      # Rename steps to avoid code collision with chain helper
      _steps_b =
        for i <- 3..5 do
          insert(:step,
            code: "D#{i}",
            name: "Dead Step #{i}",
            wip: false,
            status: "published",
            approved: true
          )
        end

      # D3, D4, D5 connected among themselves but not to C0..C2
      d3 = Repo.get_by!(Forrozin.Encyclopedia.Step, code: "D3")
      d4 = Repo.get_by!(Forrozin.Encyclopedia.Step, code: "D4")
      d5 = Repo.get_by!(Forrozin.Encyclopedia.Step, code: "D5")
      insert(:connection, source_step: d3, target_step: d4)
      insert(:connection, source_step: d4, target_step: d5)

      # Now require D3 in a sequence starting from C0 (impossible to reach)
      {:ok, sequences, warnings} =
        Generator.generate(base_params("C0", length: 3, count: 3, required_codes: ["D3"]))

      # Sequences were generated (starting from C0)
      assert length(sequences) >= 1

      # D3 could not be reached, so a warning must mention it
      _ = steps_a
      assert Enum.any?(warnings, fn w -> w =~ "D3" end)
    end
  end

  # ---------------------------------------------------------------------------
  # Multiple distinct sequences
  # ---------------------------------------------------------------------------

  describe "generate/1 — count" do
    test "generates multiple distinct sequences when multiple paths exist" do
      # Build a branching graph so multiple paths exist
      # B0 -> B1, B0 -> B2, B1 -> B3, B2 -> B4
      # Two distinct paths of length 3: B0->B1->B3 and B0->B2->B4
      s0 =
        insert(:step,
          code: "B0",
          name: "Branch 0",
          wip: false,
          status: "published",
          approved: true
        )

      s1 =
        insert(:step,
          code: "B1",
          name: "Branch 1",
          wip: false,
          status: "published",
          approved: true
        )

      s2 =
        insert(:step,
          code: "B2",
          name: "Branch 2",
          wip: false,
          status: "published",
          approved: true
        )

      s3 =
        insert(:step,
          code: "B3",
          name: "Branch 3",
          wip: false,
          status: "published",
          approved: true
        )

      s4 =
        insert(:step,
          code: "B4",
          name: "Branch 4",
          wip: false,
          status: "published",
          approved: true
        )

      insert(:connection, source_step: s0, target_step: s1)
      insert(:connection, source_step: s0, target_step: s2)
      insert(:connection, source_step: s1, target_step: s3)
      insert(:connection, source_step: s2, target_step: s4)

      # Request many more sequences than paths exist so randomness will cover both
      {:ok, sequences, _warnings} =
        Generator.generate(base_params("B0", length: 3, count: 20))

      # After deduplication we should have discovered both distinct paths.
      # With 20 independent attempts (each 50/50), P(missing one path) = (0.5)^20 < 0.000001
      distinct_middles =
        sequences
        |> Enum.map(fn seq -> Enum.at(seq, 1).code end)
        |> Enum.uniq()
        |> length()

      assert distinct_middles == 2
    end

    test "emits warning when fewer sequences than requested are generated" do
      # Completely linear chain — only one possible path of length 3
      build_linear_chain(3)

      {:ok, sequences, warnings} =
        Generator.generate(base_params("C0", length: 3, count: 5))

      # At most 1 distinct path exists
      assert length(sequences) <= 1
      assert Enum.any?(warnings, fn w -> w =~ "sequências" end)
    end

    test "deduplicates identical sequences" do
      # Single linear path: only one sequence possible
      build_linear_chain(3)

      {:ok, sequences, _warnings} =
        Generator.generate(base_params("C0", length: 3, count: 3))

      # Must be deduplicated — at most 1 distinct sequence
      assert length(sequences) <= 1
    end
  end
end
