defmodule OGrupoDeEstudos.Study.LessonStepsTest do
  @moduledoc """
  Linking encyclopedia steps to a teacher's lesson, mirroring `study_note_steps`.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Study

  setup do
    teacher = insert(:user, is_teacher: true)

    %{
      teacher: teacher,
      link: insert(:teacher_student_link, teacher: teacher, active: true),
      step: insert(:step, code: "IV", name: "Inversão base"),
      other_step: insert(:step, code: "SCSP", name: "Sacada com sacada de perna")
    }
  end

  defp lesson_attrs(attrs \\ %{}) do
    Map.merge(%{title: "Aula de sacadas", content: "O que vimos hoje."}, attrs)
  end

  describe "linking steps when creating a lesson" do
    test "keeps the chosen steps on the lesson", ctx do
      assert {:ok, _lesson, _delivered} =
               Study.broadcast_lesson(
                 ctx.teacher,
                 lesson_attrs(%{step_ids: [ctx.step.id, ctx.other_step.id]}),
                 [ctx.link.id]
               )

      assert [lesson] = Study.list_lessons_for_teacher(ctx.teacher.id)
      assert ["IV", "SCSP"] = lesson.steps |> Enum.map(& &1.code) |> Enum.sort()
    end

    test "a lesson without steps is still a lesson", ctx do
      assert {:ok, _lesson, _} =
               Study.broadcast_lesson(ctx.teacher, lesson_attrs(), [ctx.link.id])

      assert [lesson] = Study.list_lessons_for_teacher(ctx.teacher.id)
      assert lesson.steps == []
    end

    test "a repeated step is stored once", ctx do
      {:ok, _lesson, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          lesson_attrs(%{step_ids: [ctx.step.id, ctx.step.id]}),
          [ctx.link.id]
        )

      assert [%{steps: [step]}] = Study.list_lessons_for_teacher(ctx.teacher.id)
      assert step.code == "IV"
    end

    test "an unknown step id does not abort the lesson", ctx do
      assert {:ok, _lesson, _} =
               Study.broadcast_lesson(
                 ctx.teacher,
                 lesson_attrs(%{step_ids: [Ecto.UUID.generate()]}),
                 [ctx.link.id]
               )

      assert [%{steps: []}] = Study.list_lessons_for_teacher(ctx.teacher.id)
    end
  end

  describe "steps reach the reader" do
    test "the student receives the lesson with its steps", ctx do
      {:ok, _lesson, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          lesson_attrs(%{step_ids: [ctx.step.id]}),
          [ctx.link.id]
        )

      assert [lesson] = Study.list_lessons_for_link(ctx.link.id)
      assert [%{code: "IV", name: "Inversão base"}] = lesson.steps
    end

    test "each lesson carries only its own steps", ctx do
      {:ok, _, _} =
        Study.broadcast_lesson(ctx.teacher, lesson_attrs(%{step_ids: [ctx.step.id]}), [
          ctx.link.id
        ])

      {:ok, _, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          lesson_attrs(%{title: "Outra aula", step_ids: [ctx.other_step.id]}),
          [ctx.link.id]
        )

      codes =
        ctx.link.id
        |> Study.list_lessons_for_link()
        |> Map.new(&{&1.title, Enum.map(&1.steps, fn s -> s.code end)})

      assert codes == %{"Aula de sacadas" => ["IV"], "Outra aula" => ["SCSP"]}
    end
  end

  describe "editing lesson steps" do
    setup ctx do
      {:ok, lesson, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          lesson_attrs(%{step_ids: [ctx.step.id]}),
          [ctx.link.id]
        )

      Map.put(ctx, :lesson, lesson)
    end

    test "replacing steps applies to everyone who received the lesson", ctx do
      assert {:ok, _} =
               Study.update_lesson(ctx.teacher, ctx.lesson, %{
                 title: ctx.lesson.title,
                 content: ctx.lesson.content,
                 step_ids: [ctx.other_step.id]
               })

      assert [%{steps: [step]}] = Study.list_lessons_for_link(ctx.link.id)
      assert step.code == "SCSP"
    end

    test "editing only the text keeps the steps", ctx do
      assert {:ok, _} =
               Study.update_lesson(ctx.teacher, ctx.lesson, %{
                 title: ctx.lesson.title,
                 content: "Texto corrigido."
               })

      assert [%{steps: [%{code: "IV"}]}] = Study.list_lessons_for_link(ctx.link.id)
    end

    test "an empty list removes every step", ctx do
      assert {:ok, _} =
               Study.update_lesson(ctx.teacher, ctx.lesson, %{
                 title: ctx.lesson.title,
                 content: ctx.lesson.content,
                 step_ids: []
               })

      assert [%{steps: []}] = Study.list_lessons_for_link(ctx.link.id)
    end

    test "only the lesson owner can change its steps", ctx do
      stranger = insert(:user, is_teacher: true)

      assert {:error, :unauthorized} =
               Study.update_lesson(stranger, ctx.lesson, %{step_ids: [ctx.other_step.id]})

      assert [%{steps: [%{code: "IV"}]}] = Study.list_lessons_for_link(ctx.link.id)
    end

    test "deleting the lesson cascades its step links", ctx do
      assert {:ok, _} = Study.delete_lesson(ctx.teacher, ctx.lesson)

      assert Study.list_lessons_for_teacher(ctx.teacher.id) == []
    end
  end

  describe "reading the steps of one lesson" do
    test "returns the linked steps", ctx do
      {:ok, lesson, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          lesson_attrs(%{step_ids: [ctx.step.id]}),
          [ctx.link.id]
        )

      assert [%{code: "IV", name: "Inversão base"}] = Study.lesson_steps(lesson.id)
    end

    test "returns an empty list for a lesson without steps", ctx do
      {:ok, lesson, _} = Study.broadcast_lesson(ctx.teacher, lesson_attrs(), [ctx.link.id])

      assert Study.lesson_steps(lesson.id) == []
    end
  end
end
