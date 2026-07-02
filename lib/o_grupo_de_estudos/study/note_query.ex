defmodule OGrupoDeEstudos.Study.NoteQuery do
  @moduledoc """
  Query module for study `Note` and `NoteStep`.

  Owns every read on diary notes, including the step-frequency ranking
  (which joins the encyclopedia's Step for code/name projection).
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Encyclopedia.Step
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Study.{Note, NoteStep}

  @doc "Returns the personal note of a user on a date (steps preloaded), or `nil`."
  @spec get_personal(Ecto.UUID.t(), Date.t()) :: Note.t() | nil
  def get_personal(user_id, date) do
    Repo.get_by(Note, kind: "personal", owner_user_id: user_id, note_date: date)
    |> preload_steps()
  end

  @doc "Returns the shared note of a link on a date (steps preloaded), or `nil`."
  @spec get_shared(Ecto.UUID.t(), Date.t()) :: Note.t() | nil
  def get_shared(link_id, date) do
    Repo.get_by(Note, kind: "shared", teacher_student_link_id: link_id, note_date: date)
    |> preload_steps()
  end

  @doc "Returns true if a shared note exists for the given link and date."
  @spec shared_exists?(Ecto.UUID.t(), Date.t()) :: boolean()
  def shared_exists?(link_id, date) do
    from(n in Note,
      where: n.teacher_student_link_id == ^link_id and n.note_date == ^date and n.kind == "shared"
    )
    |> Repo.exists?()
  end

  @doc "MapSet of link ids (among the given ones) that have a shared note on the date."
  @spec shared_link_ids_on([Ecto.UUID.t()], Date.t()) :: MapSet.t()
  def shared_link_ids_on(link_ids, date) when is_list(link_ids) do
    from(n in Note,
      where:
        n.teacher_student_link_id in ^link_ids and n.note_date == ^date and n.kind == "shared",
      select: n.teacher_student_link_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  @doc "Personal notes of a user, newest first, steps preloaded."
  @spec list_personal_history(Ecto.UUID.t()) :: [Note.t()]
  def list_personal_history(user_id) do
    from(n in Note,
      where: n.kind == "personal" and n.owner_user_id == ^user_id,
      order_by: [desc: n.note_date]
    )
    |> Repo.all()
    |> Repo.preload(:related_steps)
  end

  @doc "Shared notes of a link, newest first, steps preloaded."
  @spec list_shared_history(Ecto.UUID.t()) :: [Note.t()]
  def list_shared_history(link_id) do
    from(n in Note,
      where: n.kind == "shared" and n.teacher_student_link_id == ^link_id,
      order_by: [desc: n.note_date]
    )
    |> Repo.all()
    |> Repo.preload(:related_steps)
  end

  @doc "Counts personal notes of a user within the inclusive date range."
  @spec count_personal_between(Ecto.UUID.t(), Date.t(), Date.t()) :: non_neg_integer()
  def count_personal_between(user_id, from_date, to_date) do
    from(n in Note,
      where: n.kind == "personal" and n.owner_user_id == ^user_id,
      where: n.note_date >= ^from_date and n.note_date <= ^to_date
    )
    |> Repo.aggregate(:count)
  end

  @doc "Steps most practiced in the personal diary, with counts, most frequent first."
  @spec step_frequency(:personal | :shared, Ecto.UUID.t()) :: [map()]
  def step_frequency(:personal, user_id) do
    base_frequency_query()
    |> where([_ns, n], n.owner_user_id == ^user_id and n.kind == "personal")
    |> Repo.all()
  end

  def step_frequency(:shared, link_id) do
    base_frequency_query()
    |> where([_ns, n], n.teacher_student_link_id == ^link_id and n.kind == "shared")
    |> Repo.all()
  end

  defp base_frequency_query do
    from(ns in NoteStep,
      join: n in Note,
      on: ns.study_note_id == n.id,
      join: s in Step,
      on: ns.step_id == s.id,
      group_by: [s.id, s.code, s.name],
      select: %{step_id: s.id, code: s.code, name: s.name, count: count(ns.id)},
      order_by: [desc: count(ns.id)]
    )
  end

  defp preload_steps(nil), do: nil
  defp preload_steps(%Note{} = note), do: Repo.preload(note, :related_steps)
end
