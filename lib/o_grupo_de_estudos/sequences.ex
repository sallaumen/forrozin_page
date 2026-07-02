defmodule OGrupoDeEstudos.Sequences do
  @moduledoc """
  Context for managing step sequences.

  Sequences are ordered lists of steps saved by a user, optionally generated
  via the graph traversal algorithm in `Generator`.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Encyclopedia.StepQuery
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Sequences.{Generator, Sequence, SequenceQuery, SequenceStep}

  @doc """
  Generates sequences by traversing the step connection graph.

  Delegates entirely to `Generator.generate/1`. See that module for param docs.
  """
  def generate(params), do: Generator.generate(params)

  @doc """
  Creates a new sequence with its ordered steps inside a single transaction.

  Returns `{:ok, sequence}` with steps preloaded and ordered by position,
  or `{:error, changeset}` if validation fails.
  """
  def create_sequence(user_id, name, step_ids, allow_repeats \\ false) do
    Repo.transact(fn ->
      changeset =
        Sequence.changeset(%Sequence{}, %{
          name: name,
          user_id: user_id,
          allow_repeats: allow_repeats
        })

      with {:ok, sequence} <- Repo.insert(changeset) do
        insert_sequence_step_ids(sequence, step_ids)
        {:ok, Repo.preload(sequence, steps_preload())}
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

    with {:ok, steps} <- resolve_step_codes(step_codes) do
      Repo.transact(fn ->
        insert_manual_sequence_txn(user_id, attrs, steps)
      end)
    end
  end

  defp update_manual_sequence_txn(sequence, attrs, steps) do
    update_attrs = %{
      name: Map.get(attrs, :name, Map.get(attrs, "name", "")),
      description: Map.get(attrs, :description, Map.get(attrs, "description")),
      video_url: Map.get(attrs, :video_url, Map.get(attrs, "video_url")),
      allow_repeats: true
    }

    with {:ok, updated} <- sequence |> Sequence.changeset(update_attrs) |> Repo.update() do
      from(ss in SequenceStep,
        where: ss.sequence_id == ^sequence.id and is_nil(ss.deleted_at)
      )
      |> Repo.delete_all()

      insert_sequence_steps(sequence, steps)
      {:ok, Repo.preload(updated, steps_preload(), force: true)}
    end
  end

  defp insert_manual_sequence_txn(user_id, attrs, steps) do
    changeset =
      Sequence.changeset(%Sequence{}, %{
        name: Map.get(attrs, :name, Map.get(attrs, "name", "")),
        user_id: user_id,
        description: Map.get(attrs, :description, Map.get(attrs, "description")),
        video_url: Map.get(attrs, :video_url, Map.get(attrs, "video_url")),
        allow_repeats: true
      })

    with {:ok, sequence} <- Repo.insert(changeset) do
      insert_sequence_steps(sequence, steps)
      {:ok, Repo.preload(sequence, steps_preload())}
    end
  end

  @doc """
  Updates a manually managed sequence and replaces its ordered steps.

  Existing `sequence_steps` are replaced inside the same transaction so the
  visible sequence stays in sync with the edited order.
  """
  def update_manual_sequence(%Sequence{} = sequence, attrs) do
    step_codes = Map.get(attrs, :step_codes, Map.get(attrs, "step_codes", []))

    with {:ok, steps} <- resolve_step_codes(step_codes) do
      Repo.transact(fn ->
        update_manual_sequence_txn(sequence, attrs, steps)
      end)
    end
  end

  @doc "Lists all sequences belonging to a user, with steps preloaded."
  def list_user_sequences(user_id) do
    SequenceQuery.list_by(user_id: user_id, preload: steps_preload())
  end

  @doc "Lists all public sequences belonging to a user, with steps preloaded."
  def list_public_user_sequences(user_id) do
    SequenceQuery.list_by(user_id: user_id, public: true, preload: steps_preload())
  end

  @doc "Lists all public sequences, with steps and user preloaded."
  def list_all_public_sequences do
    SequenceQuery.list_by(public: true, preload: [:user | steps_preload()])
  end

  @doc "Fetches a single sequence by id, with steps preloaded. Returns `nil` if not found."
  def get_sequence(id) do
    SequenceQuery.get_by(id: id, preload: steps_preload())
  end

  @doc """
  Fetches a sequence by id only if it is visible to the viewer: public, owned by
  the viewer, or the viewer is an admin. Returns `nil` otherwise. Guards read
  paths (deep links, favoriting) against leaking other users' private sequences.
  """
  def get_sequence_for_viewer(id, viewer_id, is_admin \\ false) do
    case get_sequence(id) do
      nil -> nil
      %Sequence{public: true} = seq -> seq
      %Sequence{user_id: ^viewer_id} = seq -> seq
      seq -> if is_admin, do: seq, else: nil
    end
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

  # ── Private helpers ─────────────────────────────────────────

  @doc "Returns the owner id of a sequence, or nil (lightweight, no preloads)."
  def sequence_owner_id(sequence_id) do
    case SequenceQuery.get_by(id: sequence_id) do
      nil -> nil
      %Sequence{user_id: user_id} -> user_id
    end
  end

  @doc "Returns `%{id => %Sequence{}}` with user and ordered steps preloaded."
  def map_by_ids(ids) when is_list(ids) do
    [ids: ids, preload: [:user] ++ steps_preload()]
    |> SequenceQuery.list_by()
    |> Map.new(&{&1.id, &1})
  end

  @doc "Returns `%{user_id => count}` of public sequences per user."
  defdelegate count_public_by_users(user_ids), to: SequenceQuery, as: :public_counts_by_user

  defp steps_preload do
    ordered = from(ss in SequenceStep, order_by: [asc: ss.position])
    [sequence_steps: {ordered, [step: :category]}]
  end

  defp resolve_step_codes(step_codes) do
    steps =
      step_codes
      |> Enum.map(&StepQuery.get_by(code: &1))
      |> Enum.reject(&is_nil/1)

    if length(steps) == length(step_codes), do: {:ok, steps}, else: {:error, :invalid_codes}
  end

  defp insert_sequence_step_ids(sequence, step_ids) do
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
  end

  defp insert_sequence_steps(sequence, steps) do
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
  end
end
