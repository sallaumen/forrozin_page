defmodule OGrupoDeEstudosWeb.StudySharedLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Study

  describe "shared diary" do
    test "linked users can open and edit today's shared note", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, pending_link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(pending_link, teacher)

      conn = log_in_user(conn, teacher)
      {:ok, lv, _html} = live(conn, ~p"/study/shared/#{link.id}")

      html =
        lv
        |> form("#shared-note-form", %{"shared_note" => %{"content" => "Treinamos sacadas hoje"}})
        |> render_change()

      assert html =~ "Treinamos sacadas hoje"

      assert Study.get_shared_note(link.id, OGrupoDeEstudos.Brazil.today()).content ==
               "Treinamos sacadas hoje"
    end

    test "ended links remain visible but readonly", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, pending_link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(pending_link, teacher)
      assert {:ok, _link} = Study.end_link(link, teacher)

      conn = log_in_user(conn, student)
      {:ok, _lv, html} = live(conn, ~p"/study/shared/#{link.id}")

      assert html =~ "vínculo foi encerrado"
      assert html =~ "somente leitura"
    end

    test "can search and add related steps to the shared diary", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)

      step =
        insert(:step,
          code: "BF",
          name: "Base frontal",
          approved: true,
          wip: false,
          status: "published"
        )

      {:ok, pending_link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(pending_link, teacher)
      conn = log_in_user(conn, teacher)
      {:ok, lv, _html} = live(conn, ~p"/study/shared/#{link.id}")

      assert render_change(lv, "search_shared_step", %{"term" => "base"}) =~ "Base frontal"

      lv
      |> element("#add-shared-step-#{step.id}")
      |> render_click()

      assert has_element?(lv, "#shared-related-step-#{step.id}")
    end
  end
end
