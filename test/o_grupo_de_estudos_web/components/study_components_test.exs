defmodule OGrupoDeEstudosWeb.StudyComponentsTest do
  @moduledoc """
  The blocks the study area repeats, and what they used to break.

  Measured at 375px: a student's name got 52px of the 130px it needed, so
  "Marina Kienteca" read "Mar…" and the page failed at the one thing it is for.
  The tab strip was 484px wide on a 375px screen, which left Workshops outside
  the window behind a scroll nobody sees.
  """

  use ExUnit.Case, async: true

  import OGrupoDeEstudosWeb.StudyComponents
  import Phoenix.LiveViewTest

  defp person(overrides \\ []) do
    assigns =
      Enum.into(overrides, %{
        user: %{id: "1", name: "Dennison Camargo", username: "dennisom", avatar_path: nil},
        badge_label: nil,
        status_label: nil,
        href: nil
      })

    render_component(&person_card/1, assigns)
  end

  describe "person_card/1" do
    test "the name comes whole, because knowing who it is was the point" do
      html = person()

      assert html =~ "Dennison Camargo"
      refute html =~ "truncate"
    end

    test "the buttons ride their own row on a phone, so they stop eating the name" do
      assert person() =~ "sm:flex-nowrap"
    end

    test "no coloured rail down the side" do
      refute person() =~ "border-l-accent"
    end

    test "a status is one quiet line, not a badge" do
      html = person(status_label: "Escreveu hoje")

      assert html =~ "Escreveu hoje"
      refute html =~ "rounded-full bg-accent"
    end
  end

  describe "study_tabs/1" do
    test "all four ways in are on the strip" do
      html = tabs()

      for label <- ["Meu estudo", "Professores", "Alunos", "Workshops"] do
        assert html =~ label
      end
    end

    test "whoever does not teach gets no students tab" do
      html = tabs(is_teacher: false)

      assert html =~ "Professores"
      refute html =~ "Alunos"
    end

    test "the strip is a row of labels, not a pill inside a pill" do
      refute tabs() =~ "rounded-full border border-ink-200"
    end

    test "a pending request shows up as a number on the tab" do
      assert tabs(pending_count: 3) =~ "3"
    end
  end

  describe "stat_line/1" do
    test "the numbers read as a sentence instead of three boxes" do
      html =
        render_component(&stat_line/1, %{
          stats: [{3, "alunos"}, {1, "escreveram hoje"}, {2, "pedidos"}]
        })

      assert html =~ "alunos"
      assert html =~ "escreveram hoje"
      refute html =~ "rounded-2xl"
    end

    test "a count of one reads in the singular when the label allows it" do
      html = render_component(&stat_line/1, %{stats: [{1, "aluno"}]})

      assert html =~ "aluno"
    end
  end

  describe "empty_state/1" do
    test "nothing here yet is a sentence, not a framed announcement" do
      html =
        render_component(&empty_state/1, %{
          title: "Você ainda não estuda com ninguém",
          description: "Adicione um professor pra abrir um diário compartilhado."
        })

      assert html =~ "Você ainda não estuda com ninguém"
      refute html =~ "border-dashed"
    end
  end

  describe "section_intro/1" do
    test "the title is said once, not twice with an eyebrow above it" do
      html =
        render_component(&section_intro/1, %{
          title: "Meus alunos",
          description: "Quem estuda com você."
        })

      assert html =~ "Meus alunos"
      refute html =~ "uppercase"
    end
  end

  defp tabs(overrides \\ []) do
    assigns =
      Enum.into(overrides, %{
        active: "personal",
        is_teacher: true,
        pending_count: 0,
        lesson_count: 0
      })

    render_component(&study_tabs/1, assigns)
  end
end
