defmodule OGrupoDeEstudos.Sequences.Scorer do
  @moduledoc """
  Scores and ranks generated sequences by quality criteria.

  Each criterion is an independent pure function that returns a float.
  The final score is the weighted sum of all criteria. Functions are
  public so each can be tested in isolation.

  Usage:
      Scorer.rank(sequences, %{required_ids: MapSet.new([...]), bf_id: "..."})
  """

  @weight_required_position 3.0
  @weight_required_spread 2.0
  @weight_bf_penalty 1.5
  @weight_category_diversity 2.0
  @weight_repetition_penalty 1.0
  @weight_interesting_steps 1.5

  # Steps that make sequences more interesting — bonus per occurrence
  @step_bonuses %{
    "GP" => 0.8,
    "GP-D" => 0.6,
    "SC" => 0.7,
    "IV" => 0.7,
    "TR-ARM" => 0.4
  }

  @type step :: %{id: String.t(), code: String.t(), name: String.t()}
  @type score_opts :: %{required_ids: MapSet.t(), bf_id: String.t() | nil}

  @doc """
  Ranks sequences by quality. Returns `[{sequence, score, breakdown}]`
  sorted by score descending (best first).
  """
  @spec rank([list(step())], score_opts()) :: [{list(step()), float(), map()}]
  def rank(sequences, opts) do
    sequences
    |> Enum.map(fn seq ->
      breakdown = score_breakdown(seq, opts)
      total = Map.values(breakdown) |> Enum.sum()
      {seq, total, breakdown}
    end)
    |> Enum.sort_by(fn {_seq, score, _} -> -score end)
  end

  @doc """
  Returns the individual score for each criterion.
  """
  @spec score_breakdown(list(step()), score_opts()) :: map()
  def score_breakdown(seq, opts) do
    required_ids = Map.get(opts, :required_ids, MapSet.new())
    bf_id = Map.get(opts, :bf_id)

    %{
      required_position: score_required_position(seq, required_ids) * @weight_required_position,
      required_spread: score_required_spread(seq, required_ids) * @weight_required_spread,
      bf_penalty: score_bf_penalty(seq, bf_id) * @weight_bf_penalty,
      category_diversity: score_category_diversity(seq) * @weight_category_diversity,
      repetition_penalty: score_repetition_penalty(seq) * @weight_repetition_penalty,
      interesting_steps: score_interesting_steps(seq) * @weight_interesting_steps
    }
  end

  # ── Individual criteria ──────────────────────────────────────────────

  @doc """
  Scores how close required steps are to the center of the sequence.

  Position 0.5 (center) = 1.0, position 0.0 or 1.0 (edges) = 0.0.
  Returns the average across all required steps found.
  """
  @spec score_required_position(list(step()), MapSet.t()) :: float()
  def score_required_position(_seq, required_ids) when map_size(required_ids) == 0, do: 0.0

  def score_required_position(seq, required_ids) do
    len = length(seq)

    if len <= 1 do
      0.0
    else
      scores =
        seq
        |> Enum.with_index()
        |> Enum.filter(fn {step, _idx} -> MapSet.member?(required_ids, step.id) end)
        |> Enum.map(fn {_step, idx} ->
          normalized = idx / (len - 1)
          1.0 - abs(normalized - 0.5) * 2
        end)

      case scores do
        [] -> 0.0
        _ -> Enum.sum(scores) / length(scores)
      end
    end
  end

  @doc """
  Scores how well-spread required steps are across the sequence.

  Only applies with 2+ required steps. Measures average gap between
  consecutive required positions, normalized to sequence length.
  """
  @spec score_required_spread(list(step()), MapSet.t()) :: float()
  def score_required_spread(_seq, required_ids) when map_size(required_ids) < 2, do: 0.0

  def score_required_spread(seq, required_ids) do
    len = length(seq)

    if len <= 1 do
      0.0
    else
      positions =
        seq
        |> Enum.with_index()
        |> Enum.filter(fn {step, _idx} -> MapSet.member?(required_ids, step.id) end)
        |> Enum.map(fn {_step, idx} -> idx end)
        |> Enum.sort()

      case positions do
        [_ | [_ | _]] ->
          gaps =
            positions
            |> Enum.chunk_every(2, 1, :discard)
            |> Enum.map(fn [a, b] -> b - a end)

          avg_gap = Enum.sum(gaps) / length(gaps)
          ideal_gap = len / (length(positions) + 1)
          min(avg_gap / ideal_gap, 1.0)

        _ ->
          0.0
      end
    end
  end

  @doc """
  Penalizes sequences with excessive BF visits.

  First BF is free (it's typically the start). Each additional BF
  returns -1.0.
  """
  @spec score_bf_penalty(list(step()), String.t() | nil) :: float()
  def score_bf_penalty(_seq, nil), do: 0.0

  def score_bf_penalty(seq, bf_id) do
    bf_count = Enum.count(seq, fn step -> step.id == bf_id end)
    -max(bf_count - 1, 0) * 1.0
  end

  @doc """
  Rewards sequences with diverse step categories.

  Returns ratio of unique categories to total steps.
  Requires steps to have a `:category_id` field (falls back gracefully).
  """
  @spec score_category_diversity(list(step())) :: float()
  def score_category_diversity([]), do: 0.0

  def score_category_diversity(seq) do
    categories =
      seq
      |> Enum.map(&Map.get(&1, :category_id))
      |> Enum.reject(&is_nil/1)

    case categories do
      [] -> 0.0
      cats -> length(Enum.uniq(cats)) / length(cats)
    end
  end

  @doc """
  Penalizes sequences with repeated steps.

  Returns -1.0 for each step that appears more than once (counted once
  per repeated step, not per extra occurrence).
  """
  @spec score_repetition_penalty(list(step())) :: float()
  def score_repetition_penalty(seq) do
    repeated_count =
      seq
      |> Enum.frequencies_by(& &1.id)
      |> Enum.count(fn {_id, count} -> count > 1 end)

    -repeated_count * 1.0
  end

  @doc """
  Rewards sequences that include interesting/versatile steps.

  Certain steps open up richer movement possibilities and make
  sequences more engaging. Each occurrence of a bonus step adds
  its configured value. Bonus steps: GP, GP-D, SC, IV, TR-ARM.
  """
  @spec score_interesting_steps(list(step())) :: float()
  def score_interesting_steps(seq) do
    seq
    |> Enum.map(fn step -> Map.get(@step_bonuses, step.code, 0.0) end)
    |> Enum.sum()
  end
end
