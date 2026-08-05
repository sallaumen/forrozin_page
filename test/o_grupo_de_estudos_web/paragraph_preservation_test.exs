defmodule OGrupoDeEstudosWeb.ParagraphPreservationTest do
  @moduledoc """
  Text written in paragraphs reads back in paragraphs.

  Whoever writes a long bio, a real comment or a note in the diary breaks it into
  paragraphs. HTML collapses the line breaks unless the page says otherwise, so
  the text came back as one clump, and rereading what you wrote felt broken.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Brazil, Engagement, Study, Workshops}

  @paragraphs "Primeiro parágrafo do texto.\n\nSegundo parágrafo, separado de propósito."

  describe "the teacher bio on the invite page" do
    test "keeps its paragraphs", %{conn: conn} do
      teacher = insert(:user, is_teacher: true, bio: @paragraphs)

      {:ok, lv, _} =
        live(log_in_user(conn, insert(:user)), ~p"/study/invite/#{teacher.invite_slug}")

      assert has_element?(lv, "p.whitespace-pre-line", "Primeiro parágrafo")
    end
  end

  describe "a comment in the conversation" do
    test "keeps its paragraphs", %{conn: conn} do
      organizer = insert(:user, is_teacher: true)

      {:ok, workshop} =
        Workshops.create_workshop(organizer, %{
          title: "Workshop de sacadas",
          description: "Conteúdo.",
          starts_at: Brazil.today() |> Date.add(7) |> DateTime.new!(~T[20:00:00], "Etc/UTC")
        })

      {:ok, workshop} = Workshops.publish_workshop(organizer, workshop)
      {:ok, _} = Engagement.create_workshop_comment(organizer, workshop.id, %{body: @paragraphs})

      {:ok, lv, _} = live(log_in_user(conn, organizer), ~p"/workshops/#{workshop.slug}")

      assert has_element?(lv, "p.whitespace-pre-line", "Primeiro parágrafo")
    end
  end

  describe "a diary note read back later" do
    test "keeps its paragraphs in the history", %{conn: conn} do
      student = insert(:user)
      yesterday = Date.add(Brazil.today(), -1)
      {:ok, _} = Study.upsert_personal_note(student, yesterday, %{content: @paragraphs})

      {:ok, lv, _} = live(log_in_user(conn, student), ~p"/study")

      assert has_element?(lv, "p.whitespace-pre-line", "Primeiro parágrafo")
    end
  end

  describe "the mechanics note of a step" do
    test "keeps its paragraphs", %{conn: conn} do
      step = insert(:step, code: "IV", name: "Inversão", note: @paragraphs)

      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/steps/#{step.code}")

      assert has_element?(lv, "p.whitespace-pre-line", "Primeiro parágrafo")
    end
  end
end
