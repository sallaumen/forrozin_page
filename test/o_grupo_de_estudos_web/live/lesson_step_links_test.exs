defmodule OGrupoDeEstudosWeb.LessonStepLinksTest do
  @moduledoc """
  The teacher links steps in the lesson composer; the student finds them as
  chips that open the step sheet, with the "learned" gesture, without leaving
  the lesson.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Engagement, Study}

  setup %{conn: conn} do
    teacher = insert(:user, is_teacher: true)

    %{
      conn: conn,
      teacher: teacher,
      link: insert(:teacher_student_link, teacher: teacher, active: true),
      step: insert(:step, code: "IV", name: "Inversão base"),
      other_step: insert(:step, code: "SCSP", name: "Sacada com sacada de perna")
    }
  end

  defp add_step_via_search(lv, step) do
    render_change(lv, "search_lesson_step", %{"term" => step.code})
    render_click(lv, "add_lesson_step", %{"id" => step.id, "step-id" => step.id})
  end

  describe "the teacher links steps in the composer" do
    setup ctx do
      {:ok, lv, _html} = live(log_in_user(ctx.conn, ctx.teacher), ~p"/study")
      render_click(lv, "switch_study_tab", %{"tab" => "students"})
      render_click(lv, "open_lesson_composer", %{})

      Map.put(ctx, :lv, lv)
    end

    test "the composer offers the step search field", ctx do
      assert has_element?(ctx.lv, "#lesson-composer-step-search")
    end

    test "searching suggests steps from the collection", ctx do
      html = render_change(ctx.lv, "search_lesson_step", %{"term" => "invers"})

      assert html =~ "Inversão base"
    end

    test "adding puts the chip on the composer", ctx do
      html = add_step_via_search(ctx.lv, ctx.step)

      assert html =~ "IV"
      assert html =~ "Inversão base"
    end

    test "the same step is not added twice", ctx do
      add_step_via_search(ctx.lv, ctx.step)
      html = add_step_via_search(ctx.lv, ctx.step)

      assert html |> String.split("Inversão base") |> length() == 2
    end

    test "removing takes the chip away", ctx do
      add_step_via_search(ctx.lv, ctx.step)
      html = render_click(ctx.lv, "remove_lesson_step", %{"step-id" => ctx.step.id})

      refute html =~ "Inversão base"
    end

    test "submitting the lesson carries the steps", ctx do
      add_step_via_search(ctx.lv, ctx.step)

      render_submit(element(ctx.lv, "#lesson-composer-form"), %{
        "lesson" => %{
          "title" => "Aula de sacadas",
          "content" => "Revisamos a inversão.",
          "student_ids" => [ctx.link.id]
        }
      })

      assert [%{steps: [step]}] = Study.list_lessons_for_link(ctx.link.id)
      assert step.code == "IV"
    end

    test "reopening the composer starts with no steps", ctx do
      add_step_via_search(ctx.lv, ctx.step)
      render_click(ctx.lv, "close_lesson_composer", %{})
      html = render_click(ctx.lv, "open_lesson_composer", %{})

      refute html =~ "Inversão base"
    end

    test "an id missing from the suggestions does not crash the page", ctx do
      assert render_click(ctx.lv, "add_lesson_step", %{
               "id" => "not-a-uuid",
               "step-id" => "not-a-uuid"
             })
    end
  end

  describe "editing a lesson keeps and swaps steps" do
    setup ctx do
      {:ok, lesson, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          %{title: "Aula", content: "Texto", step_ids: [ctx.step.id]},
          [ctx.link.id]
        )

      {:ok, lv, _html} = live(log_in_user(ctx.conn, ctx.teacher), ~p"/study")
      render_click(lv, "switch_study_tab", %{"tab" => "students"})

      ctx |> Map.put(:lv, lv) |> Map.put(:lesson, lesson)
    end

    test "opening for edit loads the steps the lesson already had", ctx do
      html = render_click(ctx.lv, "edit_lesson", %{"id" => ctx.lesson.id})

      assert html =~ "Inversão base"
    end

    test "swapping a step and saving applies to everyone who received it", ctx do
      render_click(ctx.lv, "edit_lesson", %{"id" => ctx.lesson.id})
      render_click(ctx.lv, "remove_lesson_step", %{"step-id" => ctx.step.id})
      add_step_via_search(ctx.lv, ctx.other_step)

      render_submit(element(ctx.lv, "#lesson-composer-form"), %{
        "lesson" => %{"title" => "Aula", "content" => "Texto"}
      })

      assert [%{steps: [step]}] = Study.list_lessons_for_link(ctx.link.id)
      assert step.code == "SCSP"
    end
  end

  describe "the student finds the step in the received lesson" do
    setup ctx do
      {:ok, _lesson, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          %{title: "Aula de sacadas", content: "Revisamos.", step_ids: [ctx.step.id]},
          [ctx.link.id]
        )

      student = ctx.link.student
      {:ok, lv, html} = live(log_in_user(ctx.conn, student), ~p"/study/shared/#{ctx.link.id}")

      ctx |> Map.put(:lv, lv) |> Map.put(:html, html) |> Map.put(:student, student)
    end

    test "the step chip shows up on the lesson", ctx do
      assert ctx.html =~ "Inversão base"
      assert ctx.html =~ "open_step_sheet"
    end

    test "clicking the chip opens the step sheet", ctx do
      html = render_click(ctx.lv, "open_step_sheet", %{"code" => ctx.step.code})

      assert html =~ "Já sei este passo"
    end

    test "marking from the sheet records the learning without leaving the lesson", ctx do
      render_click(ctx.lv, "open_step_sheet", %{"code" => ctx.step.code})
      html = render_click(ctx.lv, "toggle_step_learned", %{"code" => ctx.step.code})

      assert Engagement.learned?(ctx.student.id, ctx.step.id)
      assert html =~ "Aula de sacadas"
    end

    test "the lesson chip turns green after marking", ctx do
      render_click(ctx.lv, "open_step_sheet", %{"code" => ctx.step.code})
      html = render_click(ctx.lv, "toggle_step_learned", %{"code" => ctx.step.code})

      assert html =~ "accent-green"
    end
  end
end
