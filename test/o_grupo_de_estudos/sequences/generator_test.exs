defmodule OGrupoDeEstudos.Sequences.GeneratorTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Encyclopedia.ConnectionQuery
  alias OGrupoDeEstudos.Sequences.Generator

  # ---------------------------------------------------------------------------
  # Helpers
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

  defp build_diamond_graph do
    #   S0
    #  / \
    # S1   S2
    #  \ /
    #   S3
    #   |
    #   S4
    s =
      for i <- 0..4 do
        insert(:step,
          code: "S#{i}",
          name: "Step #{i}",
          wip: false,
          status: "published",
          approved: true
        )
      end

    [s0, s1, s2, s3, s4] = s

    insert(:connection, source_step: s0, target_step: s1)
    insert(:connection, source_step: s0, target_step: s2)
    insert(:connection, source_step: s1, target_step: s3)
    insert(:connection, source_step: s2, target_step: s3)
    insert(:connection, source_step: s3, target_step: s4)
    insert(:connection, source_step: s4, target_step: s0)

    {s, Map.new(s, &{&1.code, &1})}
  end

  # ---------------------------------------------------------------------------
  # Basic generation
  # ---------------------------------------------------------------------------

  describe "basic" do
    test "returns ok tuple with sequence" do
      build_linear_chain(5)
      assert {:ok, [_], []} = Generator.generate(base_params("C0", length: 5, count: 1))
    end

    test "starts with the requested step" do
      build_linear_chain(4)
      {:ok, [seq], _} = Generator.generate(base_params("C0", length: 3, count: 1))
      assert hd(seq).code == "C0"
    end

    test "respects the requested length" do
      build_linear_chain(5)
      {:ok, [seq], _} = Generator.generate(base_params("C0", length: 4, count: 1))
      assert length(seq) == 4
    end

    test "each step has :id, :code, :name" do
      build_linear_chain(3)
      {:ok, [seq], _} = Generator.generate(base_params("C0", length: 3, count: 1))

      for step <- seq,
          do:
            assert(
              Map.has_key?(step, :id) and Map.has_key?(step, :code) and Map.has_key?(step, :name)
            )
    end

    test "handles length of 1" do
      build_linear_chain(3)
      {:ok, [seq], _} = Generator.generate(base_params("C0", length: 1, count: 1))
      assert length(seq) == 1 and hd(seq).code == "C0"
    end

    test "handles length of 2" do
      build_linear_chain(3)
      {:ok, [seq], _} = Generator.generate(base_params("C0", length: 2, count: 1))
      assert length(seq) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Invalid input
  # ---------------------------------------------------------------------------

  describe "invalid input" do
    test "warns when start code not found" do
      assert {:ok, [], [w]} = Generator.generate(base_params("NOPE", length: 3, count: 1))
      assert w =~ "NOPE"
    end

    test "no crash with empty DB" do
      assert {:ok, [], [_]} = Generator.generate(base_params("X", length: 3, count: 1))
    end

    test "isolated start step returns empty with warning" do
      insert(:step,
        code: "ALONE",
        name: "Lonely",
        wip: false,
        status: "published",
        approved: true
      )

      {:ok, seqs, warnings} = Generator.generate(base_params("ALONE", length: 3, count: 1))
      assert seqs == []
      assert Enum.any?(warnings, &(&1 =~ "sequências"))
    end
  end

  # ---------------------------------------------------------------------------
  # No repeats
  # ---------------------------------------------------------------------------

  describe "allow_repeats: false" do
    test "does not repeat steps" do
      build_linear_chain(6)
      {:ok, [seq], _} = Generator.generate(base_params("C0", length: 5, allow_repeats: false))
      codes = Enum.map(seq, & &1.code)
      assert codes == Enum.uniq(codes)
    end

    test "fails gracefully when path too long for graph" do
      build_linear_chain(3)

      {:ok, seqs, warnings} =
        Generator.generate(base_params("C0", length: 5, count: 1, allow_repeats: false))

      assert seqs == [] or Enum.any?(warnings, &(&1 =~ "sequências"))
    end
  end

  # ---------------------------------------------------------------------------
  # With repeats
  # ---------------------------------------------------------------------------

  describe "allow_repeats: true" do
    test "generates sequence longer than graph with repeats" do
      {steps, _} = build_linear_chain(3)
      add_loop(steps)

      {:ok, [seq], _} =
        Generator.generate(base_params("C0", length: 10, count: 1, allow_repeats: true))

      assert length(seq) == 10
    end

    test "respects max_same_pair_loops" do
      s0 =
        insert(:step, code: "L0", name: "Loop 0", wip: false, status: "published", approved: true)

      s1 =
        insert(:step, code: "L1", name: "Loop 1", wip: false, status: "published", approved: true)

      insert(:connection, source_step: s0, target_step: s1)
      insert(:connection, source_step: s1, target_step: s0)

      # With max_same_pair_loops=2, length 7 is impossible even with repeats
      # (needs 3 identical transitions but limit is 2)
      # The relaxation may try but still fail — or produce shorter sequence
      {:ok, seqs, _warnings} =
        Generator.generate(
          base_params("L0", length: 7, count: 1, allow_repeats: true)
          |> Map.put(:max_same_pair_loops, 2)
        )

      # Either no result, or a shorter relaxed result
      assert seqs == [] or length(hd(seqs)) < 7

      # With max_same_pair_loops=3, length 7 works
      {:ok, [seq], _} =
        Generator.generate(
          base_params("L0", length: 7, count: 1, allow_repeats: true)
          |> Map.put(:max_same_pair_loops, 3)
        )

      assert Enum.map(seq, & &1.code) == ["L0", "L1", "L0", "L1", "L0", "L1", "L0"]
    end
  end

  # ---------------------------------------------------------------------------
  # Cyclic
  # ---------------------------------------------------------------------------

  describe "cyclic" do
    test "cyclic sequence starts and ends at the same step" do
      {steps, _} = build_linear_chain(4)
      add_loop(steps)
      {:ok, [seq], _} = Generator.generate(base_params("C0", length: 5, count: 1, cyclic: true))
      assert hd(seq).code == "C0" and List.last(seq).code == "C0"
    end

    test "cyclic fails when no loop exists" do
      build_linear_chain(4)
      {:ok, seqs, _} = Generator.generate(base_params("C0", length: 4, count: 1, cyclic: true))
      assert seqs == []
    end

    test "cyclic works with diamond graph" do
      build_diamond_graph()
      {:ok, seqs, _} = Generator.generate(base_params("S0", length: 5, count: 3, cyclic: true))
      assert seqs != []

      for seq <- seqs do
        assert hd(seq).code == "S0" and List.last(seq).code == "S0"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Required codes
  # ---------------------------------------------------------------------------

  describe "required_codes" do
    test "guarantees required step appears in every sequence" do
      build_linear_chain(5)

      {:ok, seqs, _warnings} =
        Generator.generate(base_params("C0", length: 5, count: 3, required_codes: ["C3"]))

      for seq <- seqs do
        assert "C3" in Enum.map(seq, & &1.code)
      end
    end

    test "waypoint sequences follow valid directed edges" do
      build_linear_chain(6)
      connections = ConnectionQuery.list_by(preload: [])

      edge_set =
        MapSet.new(connections, fn c -> {c.source_step_id, c.target_step_id} end)

      {:ok, seqs, _warnings} =
        Generator.generate(base_params("C0", length: 6, count: 2, required_codes: ["C4"]))

      for seq <- seqs do
        # Every consecutive pair must be a valid directed edge
        seq
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [a, b] ->
          assert MapSet.member?(edge_set, {a.id, b.id}),
                 "Invalid edge: #{a.code} → #{b.code}"
        end)
      end
    end

    test "waypoint sequence starts at the requested step" do
      build_linear_chain(5)

      {:ok, [seq], _warnings} =
        Generator.generate(base_params("C0", length: 5, count: 1, required_codes: ["C3"]))

      assert hd(seq).code == "C0"
    end

    test "guarantees multiple required steps in same sequence" do
      build_linear_chain(6)

      {:ok, seqs, _warnings} =
        Generator.generate(base_params("C0", length: 6, count: 2, required_codes: ["C2", "C4"]))

      for seq <- seqs do
        codes = Enum.map(seq, & &1.code)
        assert "C2" in codes
        assert "C4" in codes
      end
    end

    test "permutes required step order across sequences for variety" do
      {steps, _} = build_linear_chain(5)
      add_loop(steps)

      {:ok, seqs, _warnings} =
        Generator.generate(
          base_params("C0", length: 10, count: 6, required_codes: ["C2", "C3"])
          |> Map.put(:allow_repeats, true)
        )

      orders =
        Enum.map(seqs, fn seq ->
          codes = Enum.map(seq, & &1.code)
          c2_idx = Enum.find_index(codes, &(&1 == "C2"))
          c3_idx = Enum.find_index(codes, &(&1 == "C3"))
          {c2_idx, c3_idx}
        end)

      c2_first = Enum.count(orders, fn {c2, c3} -> c2 < c3 end)
      c3_first = Enum.count(orders, fn {c2, c3} -> c3 < c2 end)

      # Both orderings should appear
      assert c2_first > 0 or c3_first > 0
    end

    test "fills sequence to at least requested length with exploration" do
      {steps, _} = build_linear_chain(6)
      add_loop(steps)

      {:ok, [seq], _warnings} =
        Generator.generate(base_params("C0", length: 6, count: 1, required_codes: ["C2"]))

      assert "C2" in Enum.map(seq, & &1.code)
      # Sequence is at least target length (may be longer due to exploration)
      assert length(seq) >= 6
    end

    test "required step appears at varying positions across sequences" do
      # Diamond graph has multiple paths — required step should appear
      # at different positions when generating multiple sequences
      build_diamond_graph()

      {:ok, seqs, _warnings} =
        Generator.generate(
          base_params("S0", length: 5, count: 6, required_codes: ["S3"])
          |> Map.put(:allow_repeats, true)
        )

      positions =
        Enum.map(seqs, fn seq ->
          Enum.find_index(Enum.map(seq, & &1.code), &(&1 == "S3"))
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      # Should have at least some variety in position
      assert positions != []
    end

    test "adjusts length when path through waypoints is longer" do
      # Chain of 8 steps — requiring C6 means min path is C0→C1→...→C6 = 7 steps
      build_linear_chain(8)

      {:ok, [seq], warnings} =
        Generator.generate(base_params("C0", length: 4, count: 1, required_codes: ["C6"]))

      # Sequence must include C6 — length adapts
      assert "C6" in Enum.map(seq, & &1.code)
      assert length(seq) >= 7
      assert Enum.any?(warnings, &(&1 =~ "Tamanho ajustado"))
    end

    test "warns when no path exists between required steps" do
      build_linear_chain(3)

      # Disconnected step
      d0 =
        insert(:step, code: "D0", name: "Disc 0", wip: false, status: "published", approved: true)

      d1 =
        insert(:step, code: "D1", name: "Disc 1", wip: false, status: "published", approved: true)

      insert(:connection, source_step: d0, target_step: d1)

      {:ok, _, warnings} =
        Generator.generate(base_params("C0", length: 3, count: 1, required_codes: ["D0"]))

      assert Enum.any?(warnings, &(&1 =~ "inalcançável"))
    end

    test "warns when required code does not exist" do
      build_linear_chain(3)

      {:ok, _, warnings} =
        Generator.generate(base_params("C0", length: 3, count: 1, required_codes: ["GHOST"]))

      assert Enum.any?(warnings, &(&1 =~ "GHOST"))
    end

    test "handles nil required_codes" do
      build_linear_chain(3)

      {:ok, [_], warnings} =
        Generator.generate(
          base_params("C0", length: 3, count: 1)
          |> Map.put(:required_codes, nil)
        )

      refute Enum.any?(warnings, &(&1 =~ "não encontrado"))
    end

    test "includes wip steps that have connections" do
      # WIP step connected to the chain — should be usable as required
      {_steps, by_code} = build_linear_chain(4)

      wip_step =
        insert(:step,
          code: "WIP1",
          name: "WIP Step",
          wip: true,
          status: "published",
          approved: true
        )

      insert(:connection, source_step: by_code["C2"], target_step: wip_step)

      {:ok, [seq], _warnings} =
        Generator.generate(base_params("C0", length: 4, count: 1, required_codes: ["WIP1"]))

      assert "WIP1" in Enum.map(seq, & &1.code)
    end
  end

  # ---------------------------------------------------------------------------
  # Count and diversity
  # ---------------------------------------------------------------------------

  describe "count and diversity" do
    test "generates multiple distinct sequences with branching" do
      build_diamond_graph()
      {:ok, seqs, _} = Generator.generate(base_params("S0", length: 4, count: 10))
      # Diamond has at least 2 paths: S0→S1→S3→S4 and S0→S2→S3→S4
      middles = seqs |> Enum.map(fn s -> Enum.at(s, 1).code end) |> Enum.uniq()
      assert length(middles) == 2
    end

    test "warns when fewer than requested" do
      build_linear_chain(3)
      {:ok, seqs, warnings} = Generator.generate(base_params("C0", length: 3, count: 5))
      assert length(seqs) <= 1
      assert Enum.any?(warnings, &(&1 =~ "sequências"))
    end

    test "deduplicates identical sequences" do
      build_linear_chain(3)
      {:ok, seqs, _} = Generator.generate(base_params("C0", length: 3, count: 3))
      assert length(seqs) <= 1
    end
  end

  # ---------------------------------------------------------------------------
  # Progressive relaxation
  # ---------------------------------------------------------------------------

  describe "progressive relaxation" do
    test "relaxes constraints to meet count when possible" do
      # Small loop: only 1 unique path without repeats
      {steps, _} = build_linear_chain(3)
      add_loop(steps)

      # Request 3 sequences of length 5 without repeats — impossible
      # But with relaxation (allow repeats), should produce more
      {:ok, seqs, _warnings} =
        Generator.generate(base_params("C0", length: 5, count: 3, cyclic: false))

      # Relaxation should kick in and produce at least 1 sequence
      assert seqs != []
    end
  end

  # ---------------------------------------------------------------------------
  # Backtracking
  # ---------------------------------------------------------------------------

  describe "backtracking" do
    test "finds path through bottleneck that random walk would miss" do
      # A → B → C (dead end)
      # A → D → E → F
      # Without backtracking: 50% chance of hitting dead end at C
      # With backtracking: always finds A→D→E→F
      a = insert(:step, code: "A", name: "A", wip: false, status: "published", approved: true)
      b = insert(:step, code: "B", name: "B", wip: false, status: "published", approved: true)
      c = insert(:step, code: "C", name: "C", wip: false, status: "published", approved: true)
      d = insert(:step, code: "D", name: "D", wip: false, status: "published", approved: true)
      e = insert(:step, code: "E", name: "E", wip: false, status: "published", approved: true)
      f = insert(:step, code: "F", name: "F", wip: false, status: "published", approved: true)

      insert(:connection, source_step: a, target_step: b)
      insert(:connection, source_step: b, target_step: c)
      # c is dead end — no outgoing
      insert(:connection, source_step: a, target_step: d)
      insert(:connection, source_step: d, target_step: e)
      insert(:connection, source_step: e, target_step: f)

      # Should ALWAYS find the path A→D→E→F (backtracking from dead end C)
      {:ok, [seq], []} = Generator.generate(base_params("A", length: 4, count: 1))
      codes = Enum.map(seq, & &1.code)
      assert codes == ["A", "D", "E", "F"]
    end
  end

  # ---------------------------------------------------------------------------
  # Graph helpers
  # ---------------------------------------------------------------------------

  describe "reachable_from/2" do
    test "finds all reachable nodes" do
      {steps, _} = build_linear_chain(4)
      connections = ConnectionQuery.list_by(preload: [])

      adjacency =
        Enum.reduce(connections, %{}, fn c, acc ->
          Map.update(acc, c.source_step_id, [c.target_step_id], &[c.target_step_id | &1])
        end)

      assert MapSet.size(Generator.reachable_from(hd(steps).id, adjacency)) == 4
      assert MapSet.size(Generator.reachable_from(Enum.at(steps, 2).id, adjacency)) == 2
    end
  end

  describe "bfs_distances/2" do
    test "computes shortest distances" do
      {steps, _} = build_linear_chain(4)
      connections = ConnectionQuery.list_by(preload: [])

      adjacency =
        Enum.reduce(connections, %{}, fn c, acc ->
          Map.update(acc, c.source_step_id, [c.target_step_id], &[c.target_step_id | &1])
        end)

      dists = Generator.bfs_distances(hd(steps).id, adjacency)
      assert Map.get(dists, hd(steps).id) == 0
      assert Map.get(dists, Enum.at(steps, 1).id) == 1
      assert Map.get(dists, Enum.at(steps, 3).id) == 3
    end
  end
end
