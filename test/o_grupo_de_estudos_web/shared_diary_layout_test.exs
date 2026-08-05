defmodule OGrupoDeEstudosWeb.SharedDiaryLayoutTest do
  @moduledoc """
  The shared diary in the same language as the rest of the study area.

  It is the place "Abrir diário" leads to, so it is a place and not a task: the
  tab bar belongs here. Inside, it still carried the vocabulary the other pages
  dropped, and it showed the same ranking of steps twice in the same column.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Study

  setup %{conn: conn} do
    teacher = insert(:user, is_teacher: true, name: "Penélope Fernandes")
    student = insert(:user, name: "Marina Kienteca")
    {:ok, pending} = Study.accept_invite(student, teacher.invite_slug)
    {:ok, link} = Study.accept_link_request(pending, teacher)

    %{conn: conn, teacher: teacher, student: student, link: link}
  end

  defp open(ctx, user),
    do: live(log_in_user(ctx.conn, user), ~p"/study/shared/#{ctx.link.id}")

  describe "the app around the diary" do
    test "the tab bar stays, because you got here by tapping a person", ctx do
      {:ok, _lv, html} = open(ctx, ctx.teacher)

      assert html =~ ~s(data-ui="bottom-nav")
      refute html =~ ~s(data-ui="back-button")
    end
  end

  describe "who the diary is with" do
    test "the name comes whole and the relation is a word, not a caps badge", ctx do
      {:ok, _lv, html} = open(ctx, ctx.teacher)

      assert html =~ "Marina Kienteca"
      assert html =~ "seu aluno"
      refute html =~ "uppercase tracking-wide"
    end

    test "the student sees the teacher named the same way", ctx do
      {:ok, _lv, html} = open(ctx, ctx.student)

      assert html =~ "Penélope Fernandes"
      assert html =~ "seu professor"
    end
  end

  describe "the vocabulary of the page" do
    test "no card wears a coloured rail down its side", ctx do
      {:ok, _lv, html} = open(ctx, ctx.teacher)

      refute html =~ "border-l-accent"
    end

    test "the counts read as a sentence instead of two boxes", ctx do
      {:ok, _lv, html} = open(ctx, ctx.teacher)

      assert html =~ "aulas"
      refute html =~ "rounded-2xl border p-3.5 text-center"
    end
  end

  describe "a lesson longer than the three lines it shows" do
    test "always offers the way to open it, at the width of a phone", ctx do
      _ =
        Study.broadcast_lesson(
          ctx.teacher,
          %{
            title: "Workshop de sacadas",
            content:
              "Sacada simples, sacada com peso e a saída pelo lado de dentro. " <>
                "Revisar em casa devagar, contando o tempo. Se a trava escapar, " <>
                "o problema costuma ser o centro de massa chegando tarde."
          },
          [ctx.link.id]
        )

      {:ok, _lv, html} = open(ctx, ctx.student)

      assert html =~ "line-clamp-3"
      assert html =~ "toggle_lesson_expansion"
    end
  end

  describe "the sidebar" do
    test "the ranking of steps is shown once, not twice in the same column", ctx do
      {:ok, _lv, html} = open(ctx, ctx.teacher)

      refute html =~ "Estudados recentemente"
    end
  end
end
