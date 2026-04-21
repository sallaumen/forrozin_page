defmodule OGrupoDeEstudosWeb.StudySharedLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Study

  describe "shared diary" do
    test "linked users can open and edit today's shared note", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, link} = Study.accept_invite(student, teacher.invite_slug)

      conn = log_in_user(conn, teacher)
      {:ok, lv, _html} = live(conn, ~p"/study/shared/#{link.id}")

      html =
        lv
        |> form("#shared-note-form", %{"shared_note" => %{"content" => "Treinamos sacadas hoje"}})
        |> render_change()

      assert html =~ "Treinamos sacadas hoje"
      assert Study.get_shared_note(link.id, Date.utc_today()).content == "Treinamos sacadas hoje"
    end

    test "ended links remain visible but readonly", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, link} = Study.accept_invite(student, teacher.invite_slug)
      assert {:ok, _link} = Study.end_link(link, teacher)

      conn = log_in_user(conn, student)
      {:ok, _lv, html} = live(conn, ~p"/study/shared/#{link.id}")

      assert html =~ "vínculo foi encerrado"
      assert html =~ "somente leitura"
    end
  end
end
