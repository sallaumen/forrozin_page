defmodule OGrupoDeEstudos.Sequences.ScorerTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Sequences.Scorer

  # ── Helpers ──────────────────────────────────────────────────────────

  defp step(code, opts) do
    id = Keyword.get(opts, :id, code)
    category_id = Keyword.get(opts, :category_id, "cat-#{code}")

    %{
      id: id,
      code: code,
      name: "Step #{code}",
      category_id: category_id
    }
  end

  defp seq(codes, opts \\ []) do
    Enum.map(codes, fn code ->
      category_id = Keyword.get(opts, :category_id)
      step(code, category_id: category_id || "cat-#{code}")
    end)
  end

  # ── score_required_position ──────────────────────────────────────────

  describe "score_required_position/2" do
    test "returns 0 when no required ids" do
      assert Scorer.score_required_position(seq(~w(A B C)), MapSet.new()) == 0.0
    end

    test "scores 1.0 when required step is exactly in the center" do
      # 5 steps: positions 0,1,2,3,4 — center is position 2
      sequence = seq(~w(A B R C D))
      required = MapSet.new(["R"])
      score = Scorer.score_required_position(sequence, required)
      assert_in_delta score, 1.0, 0.01
    end

    test "scores 0.0 when required step is at the start" do
      sequence = seq(~w(R A B C D))
      required = MapSet.new(["R"])
      score = Scorer.score_required_position(sequence, required)
      assert_in_delta score, 0.0, 0.01
    end

    test "scores 0.0 when required step is at the end" do
      sequence = seq(~w(A B C D R))
      required = MapSet.new(["R"])
      score = Scorer.score_required_position(sequence, required)
      assert_in_delta score, 0.0, 0.01
    end

    test "scores higher for center than for edges" do
      required = MapSet.new(["R"])
      center = Scorer.score_required_position(seq(~w(A B R C D)), required)
      edge = Scorer.score_required_position(seq(~w(A B C D R)), required)
      assert center > edge
    end

    test "averages across multiple required steps" do
      # One in center, one at edge — average should be moderate
      sequence = seq(~w(R1 A B R2 C))
      required = MapSet.new(["R1", "R2"])
      score = Scorer.score_required_position(sequence, required)
      assert score > 0.0 and score < 1.0
    end
  end

  # ── score_required_spread ────────────────────────────────────────────

  describe "score_required_spread/2" do
    test "returns 0 with fewer than 2 required steps" do
      assert Scorer.score_required_spread(seq(~w(A R B)), MapSet.new(["R"])) == 0.0
      assert Scorer.score_required_spread(seq(~w(A B C)), MapSet.new()) == 0.0
    end

    test "scores higher when required steps are spread apart" do
      required = MapSet.new(["R1", "R2"])
      spread = Scorer.score_required_spread(seq(~w(R1 A B C R2)), required)
      close = Scorer.score_required_spread(seq(~w(A R1 R2 B C)), required)
      assert spread > close
    end

    test "returns positive score when well distributed" do
      required = MapSet.new(["R1", "R2"])
      score = Scorer.score_required_spread(seq(~w(A R1 B C R2 D)), required)
      assert score > 0.0
    end
  end

  # ── score_bf_penalty ─────────────────────────────────────────────────

  describe "score_bf_penalty/2" do
    test "returns 0 when no BF id" do
      assert Scorer.score_bf_penalty(seq(~w(A B C)), nil) == 0.0
    end

    test "returns 0 for single BF visit" do
      assert Scorer.score_bf_penalty(seq(~w(BF A B)), "BF") == 0.0
    end

    test "penalizes each extra BF visit" do
      assert Scorer.score_bf_penalty(seq(~w(BF A BF B)), "BF") == -1.0
      assert Scorer.score_bf_penalty(seq(~w(BF A BF B BF)), "BF") == -2.0
    end

    test "no BF at all returns 0" do
      assert Scorer.score_bf_penalty(seq(~w(A B C)), "BF") == 0.0
    end
  end

  # ── score_category_diversity ─────────────────────────────────────────

  describe "score_category_diversity/1" do
    test "returns 0 for empty sequence" do
      assert Scorer.score_category_diversity([]) == 0.0
    end

    test "returns 1.0 when all steps have unique categories" do
      sequence = [
        step("A", category_id: "cat1"),
        step("B", category_id: "cat2"),
        step("C", category_id: "cat3")
      ]

      assert_in_delta Scorer.score_category_diversity(sequence), 1.0, 0.01
    end

    test "returns lower score when categories repeat" do
      all_same = [
        step("A", category_id: "cat1"),
        step("B", category_id: "cat1"),
        step("C", category_id: "cat1")
      ]

      mixed = [
        step("A", category_id: "cat1"),
        step("B", category_id: "cat2"),
        step("C", category_id: "cat1")
      ]

      assert Scorer.score_category_diversity(mixed) > Scorer.score_category_diversity(all_same)
    end
  end

  # ── score_repetition_penalty ─────────────────────────────────────────

  describe "score_repetition_penalty/1" do
    test "returns 0 when no repetitions" do
      assert Scorer.score_repetition_penalty(seq(~w(A B C D))) == 0.0
    end

    test "penalizes repeated steps" do
      assert Scorer.score_repetition_penalty(seq(~w(A B A C))) == -1.0
    end

    test "counts each repeated step once" do
      # A repeats, B repeats — 2 penalties
      assert Scorer.score_repetition_penalty(seq(~w(A B A B C))) == -2.0
    end
  end

  # ── score_interesting_steps ───────────────────────────────────────────

  describe "score_interesting_steps/1" do
    test "returns 0 for steps with no bonuses" do
      assert Scorer.score_interesting_steps(seq(~w(A B C))) == 0.0
    end

    test "gives bonus for GP" do
      score = Scorer.score_interesting_steps(seq(~w(A GP B)))
      assert score > 0.0
    end

    test "gives bonus for SC, IV, TR-ARM" do
      assert Scorer.score_interesting_steps(seq(~w(SC))) > 0.0
      assert Scorer.score_interesting_steps(seq(~w(IV))) > 0.0
      assert Scorer.score_interesting_steps(seq(~w(TR-ARM))) > 0.0
    end

    test "GP has higher bonus than TR-ARM" do
      gp_score = Scorer.score_interesting_steps(seq(~w(GP)))
      tr_score = Scorer.score_interesting_steps(seq(~w(TR-ARM)))
      assert gp_score > tr_score
    end

    test "accumulates bonuses for multiple interesting steps" do
      one = Scorer.score_interesting_steps(seq(~w(A GP B)))
      two = Scorer.score_interesting_steps(seq(~w(A GP B IV)))
      assert two > one
    end
  end

  # ── rank/2 ───────────────────────────────────────────────────────────

  describe "rank/2" do
    test "returns sequences sorted by score descending" do
      # Sequence with required in center should rank higher than at edge
      center_seq = seq(~w(A B R C D))
      edge_seq = seq(~w(A B C D R))

      opts = %{required_ids: MapSet.new(["R"]), bf_id: nil}
      ranked = Scorer.rank([edge_seq, center_seq], opts)

      [{best, _, _} | _] = ranked
      assert Enum.map(best, & &1.code) == ~w(A B R C D)
    end

    test "includes breakdown with individual scores" do
      sequence = seq(~w(BF A R B BF))
      opts = %{required_ids: MapSet.new(["R"]), bf_id: "BF"}
      [{_seq, _total, breakdown}] = Scorer.rank([sequence], opts)

      assert Map.has_key?(breakdown, :required_position)
      assert Map.has_key?(breakdown, :bf_penalty)
      assert Map.has_key?(breakdown, :category_diversity)
      assert Map.has_key?(breakdown, :repetition_penalty)
      assert Map.has_key?(breakdown, :required_spread)
      assert Map.has_key?(breakdown, :interesting_steps)
    end

    test "sequence with fewer BFs ranks higher" do
      few_bf = seq(~w(BF A B C D))
      many_bf = seq(~w(BF A BF B BF))

      opts = %{required_ids: MapSet.new(), bf_id: "BF"}
      [{best, _, _} | _] = Scorer.rank([many_bf, few_bf], opts)

      bf_count = Enum.count(best, &(&1.code == "BF"))
      assert bf_count == 1
    end
  end
end
