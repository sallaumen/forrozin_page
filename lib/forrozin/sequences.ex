defmodule Forrozin.Sequences do
  @moduledoc """
  Context for managing step sequences.

  Sequences are ordered lists of steps saved by a user, optionally generated
  via the graph traversal algorithm in `Generator`.
  """

  alias Forrozin.Repo
  alias Forrozin.Encyclopedia.StepQuery
  alias Forrozin.Sequences.{Generator, Sequence, SequenceStep, SequenceQuery}

  @doc """
  Generates sequences by traversing the step connection graph.

  Delegates entirely to `Generator.generate/1`. See that module for param docs.
  """
  def generate(params), do: Generator.generate(params)

  @doc """
  Creates a new sequence with its ordered steps inside a single transaction.

  Returns `{:ok, sequence}` with `sequence_steps: :step` preloaded,
  or `{:error, changeset}` if validation fails.
  """
  def create_sequence(user_id, name, step_ids, allow_repeats \\ false) do
    Repo.transaction(fn ->
      changeset =
        Sequence.changeset(%Sequence{}, %{
          name: name,
          user_id: user_id,
          allow_repeats: allow_repeats
        })

      case Repo.insert(changeset) do
        {:ok, sequence} ->
          step_ids
          |> Enum.with_index(1)
          |> Enum.each(fn {step_id, position} ->
            %SequenceStep{}
            |> SequenceStep.changeset(%{
              sequence_id: sequence.id,
              step_id: step_id,
              position: position
            })
            |> Repo.insert!()
          end)

          Repo.preload(sequence, sequence_steps: :step)

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Creates a sequence manually from step codes provided by a user.

  Accepts a map with:
  - `:name` (required)
  - `:description` (optional)
  - `:video_url` (optional)
  - `:step_codes` — list of step codes in order

  Resolves codes to step IDs, then creates the sequence in a transaction.
  Returns `{:ok, sequence}` or `{:error, changeset | :invalid_codes}`.
  """
  def create_manual_sequence(user_id, attrs) do
    step_codes = Map.get(attrs, :step_codes, Map.get(attrs, "step_codes", []))

    steps =
      step_codes
      |> Enum.map(&StepQuery.get_by(code: &1))
      |> Enum.reject(&is_nil/1)

    if length(steps) != length(step_codes) do
      {:error, :invalid_codes}
    else
      Repo.transaction(fn ->
        changeset =
          Sequence.changeset(%Sequence{}, %{
            name: Map.get(attrs, :name, Map.get(attrs, "name", "")),
            user_id: user_id,
            description: Map.get(attrs, :description, Map.get(attrs, "description")),
            video_url: Map.get(attrs, :video_url, Map.get(attrs, "video_url")),
            allow_repeats: true
          })

        case Repo.insert(changeset) do
          {:ok, sequence} ->
            steps
            |> Enum.with_index(1)
            |> Enum.each(fn {step, position} ->
              %SequenceStep{}
              |> SequenceStep.changeset(%{
                sequence_id: sequence.id,
                step_id: step.id,
                position: position
              })
              |> Repo.insert!()
            end)

            Repo.preload(sequence, sequence_steps: :step)

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    end
  end

  @doc "Lists all sequences belonging to a user, with steps preloaded."
  def list_user_sequences(user_id) do
    SequenceQuery.list_by(user_id: user_id, preload: [sequence_steps: :step])
  end

  @doc "Lists all public sequences belonging to a user, with steps preloaded."
  def list_public_user_sequences(user_id) do
    SequenceQuery.list_by(user_id: user_id, public: true, preload: [sequence_steps: :step])
  end

  @doc "Lists all public sequences, with steps and user preloaded."
  def list_all_public_sequences do
    SequenceQuery.list_by(public: true, preload: [:user, sequence_steps: :step])
  end

  @doc "Fetches a single sequence by id, with steps preloaded. Returns `nil` if not found."
  def get_sequence(id) do
    SequenceQuery.get_by(id: id, preload: [sequence_steps: :step])
  end

  @doc "Soft-deletes a sequence by setting deleted_at. The sequence is excluded from all default queries."
  def delete_sequence(%Sequence{} = sequence) do
    utc_now = NaiveDateTime.utc_now()
    now = NaiveDateTime.truncate(utc_now, :second)
    sequence |> Ecto.Changeset.change(deleted_at: now) |> Repo.update()
  end

  @doc "Updates a sequence's attributes."
  def update_sequence(%Sequence{} = sequence, attrs) do
    sequence
    |> Sequence.changeset(attrs)
    |> Repo.update()
  end
end
