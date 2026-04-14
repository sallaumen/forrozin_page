defmodule Forrozin.Sequences do
  @moduledoc """
  Context for managing step sequences.

  Sequences are ordered lists of steps saved by a user, optionally generated
  via the graph traversal algorithm in `Generator`.
  """

  alias Forrozin.Repo
  alias Forrozin.Sequences.{Generator, Sequence, SequenceStep, SequenceQuery}

  # ---------------------------------------------------------------------------
  # Generation
  # ---------------------------------------------------------------------------

  @doc """
  Generates sequences by traversing the step connection graph.

  Delegates entirely to `Generator.generate/1`. See that module for param docs.
  """
  def generate(params), do: Generator.generate(params)

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

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

  @doc "Lists all sequences belonging to a user, with steps preloaded."
  def list_user_sequences(user_id) do
    SequenceQuery.list_by(user_id: user_id, preload: [sequence_steps: :step])
  end

  @doc "Fetches a single sequence by id, with steps preloaded. Returns `nil` if not found."
  def get_sequence(id) do
    SequenceQuery.get_by(id: id, preload: [sequence_steps: :step])
  end

  @doc "Deletes a sequence (cascade removes sequence_steps via DB constraint)."
  def delete_sequence(%Sequence{} = sequence) do
    Repo.delete(sequence)
  end

  @doc "Updates a sequence's attributes."
  def update_sequence(%Sequence{} = sequence, attrs) do
    sequence
    |> Sequence.changeset(attrs)
    |> Repo.update()
  end
end
