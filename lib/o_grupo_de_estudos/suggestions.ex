defmodule OGrupoDeEstudos.Suggestions do
  @moduledoc """
  Wikipedia-style suggestion system. Any user can suggest edits
  to steps (name, note, category) and connections (create, remove).
  Admin approves/rejects. Approved suggestions are applied atomically.
  """

  alias Ecto.Multi
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Admin
  alias OGrupoDeEstudos.Encyclopedia.{Step, StepQuery}
  alias OGrupoDeEstudos.Suggestions.{Suggestion, SuggestionQuery}
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher

  import Ecto.Query, only: [where: 3]

  @doc """
  Creates a pending suggestion authored by the given user.

  Accepts any of the three action types:
  - `"edit_field"` — requires `field`, `old_value`, `new_value`
  - `"create_connection"` — requires `new_value` in "CODE->CODE" format
  - `"remove_connection"` — requires `old_value` with the label
  """
  def create(user, attrs) do
    %Suggestion{}
    |> Suggestion.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  @doc """
  Approves a suggestion atomically: updates status + applies the change + notifies.

  For `edit_field`: updates the step's field, sets `last_edited_by_id` and `last_edited_at`.
  For `create_connection`: creates a new connection between the two steps parsed from "CODE->CODE".
  For `remove_connection`: soft-deletes the connection via `Admin.delete_connection/1`.
  """
  def approve(suggestion, admin) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Multi.new()
    |> Multi.update(:suggestion, Suggestion.review_changeset(suggestion, %{
      status: "approved",
      reviewed_by_id: admin.id,
      reviewed_at: now
    }))
    |> Multi.run(:apply, fn _repo, %{suggestion: s} ->
      apply_suggestion(s)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{suggestion: s}} ->
        safe_notify(:suggestion_reviewed, s, admin)
        {:ok, s}

      {:error, :suggestion, changeset, _} ->
        {:error, changeset}

      {:error, :apply, reason, _} ->
        {:error, reason}
    end
  end

  @doc """
  Rejects a suggestion. Updates status without touching the target entity.
  """
  def reject(suggestion, admin) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    suggestion
    |> Suggestion.review_changeset(%{
      status: "rejected",
      reviewed_by_id: admin.id,
      reviewed_at: now
    })
    |> Repo.update()
    |> case do
      {:ok, s} ->
        safe_notify(:suggestion_reviewed, s, admin)
        {:ok, s}

      error ->
        error
    end
  end

  @doc "Lists pending suggestions, preloading the author and reviewer."
  def list_pending(opts \\ []) do
    SuggestionQuery.list_by([status: "pending", preload: [:user, :reviewed_by]] ++ opts)
  end

  @doc "Lists all suggestions by a specific user, preloading author and reviewer."
  def list_by_user(user_id, opts \\ []) do
    SuggestionQuery.list_by([user_id: user_id, preload: [:user, :reviewed_by]] ++ opts)
  end

  @doc "Counts pending suggestions (for admin nav badge)."
  def count_pending do
    SuggestionQuery.count_by(status: "pending")
  end

  @doc "Lists all suggestions (any status), preloading author and reviewer."
  def list_all(opts \\ []) do
    SuggestionQuery.list_by([preload: [:user, :reviewed_by]] ++ opts)
  end

  @doc """
  Returns a map of step_id => Step for all steps referenced by edit_field suggestions.
  Used by the admin UI to build links to the affected step.
  """
  def steps_for_suggestions(suggestions) do
    ids =
      suggestions
      |> Enum.filter(&(&1.action == "edit_field"))
      |> Enum.map(& &1.target_id)
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    ids
    |> then(fn ids ->
      Step
      |> where([s], s.id in ^ids)
      |> Repo.all()
    end)
    |> Map.new(&{&1.id, &1})
  end

  @doc "Gets a single suggestion by ID with preloaded associations."
  def get(id) do
    SuggestionQuery.get(id)
  end

  # ── Apply suggestion ─────────────────────────────────────

  defp apply_suggestion(%{action: "edit_field"} = s) do
    step = Repo.get(Step, s.target_id)

    if step do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      field_atom = String.to_existing_atom(s.field)

      Admin.update_step(step, %{
        field_atom => s.new_value,
        :last_edited_by_id => s.user_id,
        :last_edited_at => now
      })
    else
      {:error, :step_not_found}
    end
  end

  defp apply_suggestion(%{action: "create_connection"} = s) do
    case String.split(s.new_value, "\u2192") do
      [source_code, target_code] ->
        source = StepQuery.get_by(code: String.trim(source_code))
        target = StepQuery.get_by(code: String.trim(target_code))

        if source && target do
          Admin.create_connection(%{source_step_id: source.id, target_step_id: target.id})
        else
          {:error, :steps_not_found}
        end

      _ ->
        {:error, :invalid_connection_format}
    end
  end

  defp apply_suggestion(%{action: "remove_connection"} = s) do
    Admin.delete_connection(s.target_id)
  end

  defp safe_notify(action, suggestion, admin) do
    Dispatcher.notify_suggestion(action, suggestion, admin)
  rescue
    _ -> :ok
  end
end
