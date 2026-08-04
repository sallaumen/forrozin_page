defmodule OGrupoDeEstudos.SequencesInStudyTest do
  @moduledoc """
  Sequences cited from the study side: a workshop, a teacher lesson, a diary note.

  A sequence belongs to the person who built it, never to the class. On a workshop
  only whoever teaches attaches one; a student takes it by favoriting, which is the
  gesture that already exists for everything else in the app.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.{Study, Workshops}

  setup do
    owner = insert(:user)

    %{
      owner: owner,
      workshop: insert(:workshop, organizer: owner, status: :published),
      sequence: insert(:sequence, user: owner, name: "Entrada de sacada"),
      other_sequence: insert(:sequence, user: owner, name: "Aquecimento de pisada")
    }
  end

  describe "sequences of a workshop" do
    test "the teacher attaches one", ctx do
      assert {:ok, _} = Workshops.add_sequence(ctx.workshop, ctx.owner, ctx.sequence.id)

      assert [cited] = Workshops.list_sequences(ctx.workshop.id)
      assert cited.sequence_id == ctx.sequence.id
      assert cited.name == "Entrada de sacada"
    end

    test "carries the step count, so the card says something without a second query", ctx do
      step_1 = insert(:step)
      step_2 = insert(:step)
      insert(:sequence_step, sequence: ctx.sequence, step: step_1)
      insert(:sequence_step, sequence: ctx.sequence, step: step_2)

      {:ok, _} = Workshops.add_sequence(ctx.workshop, ctx.owner, ctx.sequence.id)

      assert [%{step_count: 2}] = Workshops.list_sequences(ctx.workshop.id)
    end

    test "a co-organizer attaches too", ctx do
      partner = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.owner, partner.id)

      assert {:ok, _} = Workshops.add_sequence(ctx.workshop, partner, ctx.sequence.id)
    end

    test "an enrolled student does not attach: they favorite instead", ctx do
      student = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, student)

      assert {:error, :unauthorized} =
               Workshops.add_sequence(ctx.workshop, student, ctx.sequence.id)
    end

    test "an outsider does not attach", ctx do
      assert {:error, :unauthorized} =
               Workshops.add_sequence(ctx.workshop, insert(:user), ctx.sequence.id)
    end

    test "the same sequence does not go in twice", ctx do
      {:ok, _} = Workshops.add_sequence(ctx.workshop, ctx.owner, ctx.sequence.id)

      assert {:error, :already_added} =
               Workshops.add_sequence(ctx.workshop, ctx.owner, ctx.sequence.id)

      assert length(Workshops.list_sequences(ctx.workshop.id)) == 1
    end

    test "a sequence that does not exist is not attached", ctx do
      assert {:error, :not_found} =
               Workshops.add_sequence(ctx.workshop, ctx.owner, Ecto.UUID.generate())
    end

    test "an invalid id does not crash", ctx do
      assert {:error, :not_found} = Workshops.add_sequence(ctx.workshop, ctx.owner, "nao-e-uuid")
    end

    test "the teacher detaches it, and the sequence itself survives", ctx do
      {:ok, _} = Workshops.add_sequence(ctx.workshop, ctx.owner, ctx.sequence.id)

      assert {:ok, _} = Workshops.remove_sequence(ctx.workshop, ctx.owner, ctx.sequence.id)
      assert Workshops.list_sequences(ctx.workshop.id) == []
      assert OGrupoDeEstudos.Sequences.get_sequence(ctx.sequence.id)
    end

    test "an outsider does not detach", ctx do
      {:ok, _} = Workshops.add_sequence(ctx.workshop, ctx.owner, ctx.sequence.id)

      assert {:error, :unauthorized} =
               Workshops.remove_sequence(ctx.workshop, insert(:user), ctx.sequence.id)
    end

    test "detaching what was never attached reports not_found", ctx do
      assert {:error, :not_found} =
               Workshops.remove_sequence(ctx.workshop, ctx.owner, ctx.sequence.id)
    end

    test "deleting the workshop takes the citation with it, not the sequence", ctx do
      {:ok, _} = Workshops.add_sequence(ctx.workshop, ctx.owner, ctx.sequence.id)

      draft = insert(:workshop, organizer: ctx.owner, status: :draft)
      {:ok, _} = Workshops.add_sequence(draft, ctx.owner, ctx.sequence.id)
      {:ok, _} = Workshops.delete_workshop(ctx.owner, draft)

      assert OGrupoDeEstudos.Sequences.get_sequence(ctx.sequence.id)
      assert [_] = Workshops.list_sequences(ctx.workshop.id)
    end
  end

  describe "sequences of a diary note" do
    setup ctx do
      {:ok, note} =
        Study.upsert_personal_note(ctx.owner, Date.utc_today(), %{content: "Aula de hoje."})

      Map.put(ctx, :note, note)
    end

    test "the note cites the sequences it was given", ctx do
      Study.replace_note_sequences(ctx.note, [ctx.sequence.id, ctx.other_sequence.id])

      assert [first, second] = Study.note_sequences(ctx.note.id)
      assert first.name == "Entrada de sacada"
      assert second.name == "Aquecimento de pisada"
    end

    test "replacing swaps the whole set, like the step chips already do", ctx do
      Study.replace_note_sequences(ctx.note, [ctx.sequence.id])
      Study.replace_note_sequences(ctx.note, [ctx.other_sequence.id])

      assert [%{name: "Aquecimento de pisada"}] = Study.note_sequences(ctx.note.id)
    end

    test "an id that does not exist is dropped instead of aborting the whole write", ctx do
      Study.replace_note_sequences(ctx.note, [ctx.sequence.id, Ecto.UUID.generate()])

      assert [%{name: "Entrada de sacada"}] = Study.note_sequences(ctx.note.id)
    end

    test "an empty list clears the citations", ctx do
      Study.replace_note_sequences(ctx.note, [ctx.sequence.id])
      Study.replace_note_sequences(ctx.note, [])

      assert Study.note_sequences(ctx.note.id) == []
    end
  end

  describe "sequences of a teacher lesson" do
    setup ctx do
      student = insert(:user)
      teacher = insert(:user, is_teacher: true)
      link = insert(:teacher_student_link, teacher: teacher, student: student, active: true)

      {:ok, lesson, _count} =
        Study.broadcast_lesson(teacher, %{title: "Pisada", content: "Conteúdo"}, [link.id])

      ctx |> Map.put(:lesson, lesson) |> Map.put(:teacher, teacher)
    end

    test "the lesson cites the sequences it was given", ctx do
      sequence = insert(:sequence, user: ctx.teacher, name: "Base da pisada")

      Study.replace_lesson_sequences(ctx.lesson, [sequence.id])

      assert [%{name: "Base da pisada"}] = Study.lesson_sequences(ctx.lesson.id)
    end

    test "deleting the lesson takes the citation, not the sequence", ctx do
      sequence = insert(:sequence, user: ctx.teacher, name: "Base da pisada")
      Study.replace_lesson_sequences(ctx.lesson, [sequence.id])

      {:ok, _} = Study.delete_lesson(ctx.teacher, ctx.lesson)

      assert OGrupoDeEstudos.Sequences.get_sequence(sequence.id)
    end
  end
end
