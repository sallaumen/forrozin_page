defmodule OGrupoDeEstudos.StepsSeenInClassTest do
  @moduledoc """
  Which steps a user saw in class: workshops attended, diary notes, teacher
  lessons. History, unlike the user's own "learned" mark, and only classes
  the user actually took part in count.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.{Study, Workshops}

  setup do
    %{
      step: insert(:step, code: "IV", name: "Inversão base"),
      other_step: insert(:step, code: "SCSP", name: "Sacada com sacada de perna")
    }
  end

  describe "steps seen in workshops" do
    setup ctx do
      owner = insert(:user)
      workshop = insert(:workshop, organizer: owner)
      {:ok, _} = Workshops.add_step(workshop, owner, ctx.step.id)

      ctx |> Map.put(:owner, owner) |> Map.put(:workshop, workshop)
    end

    test "an enrolled user saw the step", ctx do
      student = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, student)

      assert MapSet.member?(Workshops.step_ids_seen_by(student.id), ctx.step.id)
    end

    test "the organizer saw it too", ctx do
      assert MapSet.member?(Workshops.step_ids_seen_by(ctx.owner.id), ctx.step.id)
    end

    test "someone who was not in the class did not see it", _ctx do
      assert Workshops.step_ids_seen_by(insert(:user).id) == MapSet.new()
    end

    test "steps the workshop did not teach are not included", ctx do
      student = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, student)

      refute MapSet.member?(Workshops.step_ids_seen_by(student.id), ctx.other_step.id)
    end

    test "a visitor without an account has no history" do
      assert Workshops.step_ids_seen_by(nil) == MapSet.new()
    end
  end

  describe "steps seen in diary notes" do
    test "a step noted in the user's own diary", ctx do
      student = insert(:user)

      {:ok, _} =
        Study.upsert_personal_note(student, Date.utc_today(), %{
          content: "Treinei inversão.",
          step_ids: [ctx.step.id]
        })

      assert MapSet.member?(Study.step_ids_seen_by(student.id), ctx.step.id)
    end

    test "a step on the shared note counts for both sides of the link", ctx do
      link = insert(:teacher_student_link, active: true)

      {:ok, _} =
        Study.upsert_shared_note(link, Date.utc_today(), %{
          content: "Aula de hoje.",
          step_ids: [ctx.step.id]
        })

      assert MapSet.member?(Study.step_ids_seen_by(link.student_id), ctx.step.id)
      assert MapSet.member?(Study.step_ids_seen_by(link.teacher_id), ctx.step.id)
    end

    test "someone else's note does not count", ctx do
      someone_else = insert(:user)

      {:ok, _} =
        Study.upsert_personal_note(someone_else, Date.utc_today(), %{
          content: "Treinei.",
          step_ids: [ctx.step.id]
        })

      assert Study.step_ids_seen_by(insert(:user).id) == MapSet.new()
    end
  end

  describe "steps seen in teacher lessons" do
    setup ctx do
      teacher = insert(:user, is_teacher: true)
      link = insert(:teacher_student_link, teacher: teacher, active: true)

      {:ok, _lesson, _} =
        Study.broadcast_lesson(
          teacher,
          %{title: "Aula", content: "Texto", step_ids: [ctx.step.id]},
          [link.id]
        )

      ctx |> Map.put(:teacher, teacher) |> Map.put(:link, link)
    end

    test "the student who received the lesson saw the step", ctx do
      assert MapSet.member?(Study.step_ids_seen_by(ctx.link.student_id), ctx.step.id)
    end

    test "the teacher who wrote it saw it too", ctx do
      assert MapSet.member?(Study.step_ids_seen_by(ctx.teacher.id), ctx.step.id)
    end

    test "someone who did not receive the lesson did not see it", _ctx do
      assert Study.step_ids_seen_by(insert(:user).id) == MapSet.new()
    end
  end

  test "a visitor without an account has no study history" do
    assert Study.step_ids_seen_by(nil) == MapSet.new()
  end
end
