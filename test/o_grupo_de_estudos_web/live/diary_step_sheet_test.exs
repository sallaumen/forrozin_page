defmodule OGrupoDeEstudosWeb.DiaryStepSheetTest do
  @moduledoc """
  The step chip in a study note opens a sheet with the step and the learn
  gesture. A sheet and not the full page, so the note stays on screen.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Engagement, Study}

  setup do
    student = insert(:user)
    step = insert(:step, code: "IV", name: "Inversão base")

    {:ok, _note} =
      Study.upsert_personal_note(student, Date.utc_today(), %{
        content: "Trabalhamos inversão hoje.",
        step_ids: [step.id]
      })

    %{student: student, step: step}
  end

  describe "in the personal diary" do
    test "step chip is clickable, not dead text", ctx do
      {:ok, _lv, html} = live(log_in_user(build_conn(), ctx.student), ~p"/study")

      assert html =~ "open_step_sheet"
      assert html =~ ctx.step.code
    end

    test "clicking opens the sheet with the step and the mark gesture", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.student), ~p"/study")

      html = render_click(lv, "open_step_sheet", %{"code" => ctx.step.code})

      assert html =~ "Inversão base"
      assert html =~ "Já sei este passo"
    end

    test "marking from there records the learning without leaving the note", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.student), ~p"/study")

      render_click(lv, "open_step_sheet", %{"code" => ctx.step.code})
      html = render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})

      assert Engagement.learned?(ctx.student.id, ctx.step.id)
      assert html =~ "Você já sabe"
      assert html =~ "Trabalhamos inversão hoje."
    end

    test "the sheet closes", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.student), ~p"/study")

      render_click(lv, "open_step_sheet", %{"code" => ctx.step.code})
      html = render_click(lv, "close_step_sheet", %{})

      refute html =~ "Já sei este passo"
    end

    test "the sheet leads to the full step, for connections and videos", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.student), ~p"/study")

      html = render_click(lv, "open_step_sheet", %{"code" => ctx.step.code})

      assert html =~ ~s|href="/steps/#{ctx.step.code}"|
    end

    test "unknown code does not crash the page", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.student), ~p"/study")

      assert render_click(lv, "open_step_sheet", %{"code" => "NAO-EXISTE"})
    end
  end

  describe "in the diary shared with the teacher" do
    setup ctx do
      link = insert(:teacher_student_link, student: ctx.student)

      {:ok, _} =
        Study.upsert_shared_note(link, Date.utc_today(), %{
          content: "Aula de hoje.",
          step_ids: [ctx.step.id]
        })

      Map.put(ctx, :link, link)
    end

    test "step marked by the teacher also opens", ctx do
      {:ok, lv, _} =
        live(log_in_user(build_conn(), ctx.student), ~p"/study/shared/#{ctx.link.id}")

      html = render_click(lv, "open_step_sheet", %{"code" => ctx.step.code})

      assert html =~ "Já sei este passo"
    end

    test "e marcar dali funciona", ctx do
      {:ok, lv, _} =
        live(log_in_user(build_conn(), ctx.student), ~p"/study/shared/#{ctx.link.id}")

      render_click(lv, "open_step_sheet", %{"code" => ctx.step.code})
      render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})

      assert Engagement.learned?(ctx.student.id, ctx.step.id)
    end
  end
end
