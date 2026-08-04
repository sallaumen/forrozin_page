defmodule OGrupoDeEstudos.Sequences.CitationQuery do
  @moduledoc """
  Reads of the sequences cited by a workshop, a lesson or a diary note.

  The three join tables have the same shape, so the projection lives here once:
  every screen that lists cited sequences wants the same row (name, how many steps,
  who owns it) and none of them wants a second query per line to get the count.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Sequences.{Sequence, SequenceStep}
  alias OGrupoDeEstudos.Study.{LessonSequence, NoteSequence}
  alias OGrupoDeEstudos.Workshops.WorkshopSequence

  @type row :: %{
          sequence_id: Ecto.UUID.t(),
          name: String.t(),
          user_id: Ecto.UUID.t(),
          step_count: non_neg_integer()
        }

  @doc "Sequences cited by the workshop, oldest citation first."
  @spec list_for_workshop(Ecto.UUID.t()) :: [row()]
  def list_for_workshop(workshop_id),
    do: list(WorkshopSequence, :workshop_id, workshop_id)

  @doc "Sequences cited by the lesson, oldest citation first."
  @spec list_for_lesson(Ecto.UUID.t()) :: [row()]
  def list_for_lesson(lesson_id),
    do: list(LessonSequence, :lesson_id, lesson_id)

  @doc "Sequences cited by the diary note, oldest citation first."
  @spec list_for_note(Ecto.UUID.t()) :: [row()]
  def list_for_note(note_id),
    do: list(NoteSequence, :study_note_id, note_id)

  defp list(schema, host_field, host_id) do
    from(c in schema,
      join: s in Sequence,
      as: :sequence,
      on: s.id == c.sequence_id,
      where: field(c, ^host_field) == ^host_id,
      where: is_nil(s.deleted_at),
      order_by: [asc: c.inserted_at],
      select: %{
        sequence_id: s.id,
        name: s.name,
        user_id: s.user_id,
        # Counted in the same round trip: one query per listed sequence would be an
        # N+1 on a page that already carries the note, the steps and the comments.
        step_count:
          subquery(
            from(ss in SequenceStep,
              where: ss.sequence_id == parent_as(:sequence).id,
              where: is_nil(ss.deleted_at),
              select: count(ss.id)
            )
          )
      }
    )
    |> Repo.all()
  rescue
    Ecto.Query.CastError -> []
  end
end
