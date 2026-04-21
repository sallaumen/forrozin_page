defmodule OGrupoDeEstudosWeb.StudyLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Study

  describe "access" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/study")
    end
  end

  describe "study home" do
    test "shows diary and sections for authenticated user", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      {:ok, lv, html} = live(conn, ~p"/study")

      assert has_element?(lv, "#study-home-shell")
      assert has_element?(lv, "#study-diary-panel")
      assert html =~ "Meus professores"
      assert html =~ "Sem registro ainda"
    end

    test "hides students section when user is not a teacher", %{conn: conn} do
      user = insert(:user, is_teacher: false)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/study")

      refute html =~ "Meus alunos"
    end

    test "shows students section when user is a teacher", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, link} = Study.accept_invite(student, teacher.invite_slug)
      conn = log_in_user(conn, teacher)

      {:ok, lv, _html} = live(conn, ~p"/study")

      # Expand students section
      html = render_click(lv, "toggle_section", %{"section" => "students"})

      assert html =~ "Meus alunos"
      assert html =~ student.name
      assert html =~ "/study/shared/#{link.id}"
    end

    test "can search and add related steps to the personal diary", %{conn: conn} do
      user = insert(:user)

      step =
        insert(:step,
          code: "SC",
          name: "Sacada simples",
          approved: true,
          wip: false,
          status: "published"
        )

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/study")

      assert render_change(lv, "search_personal_step", %{"term" => "sac"}) =~ "Sacada simples"

      lv
      |> element("#add-personal-step-#{step.id}")
      |> render_click()

      assert has_element?(lv, "#personal-related-step-#{step.id}")
    end

    test "shows movement and clickable profile links when there is shared activity", %{conn: conn} do
      teacher = insert(:user, is_teacher: true, name: "Ana", username: "ana")
      student = insert(:user, name: "Lia", username: "lia")
      {:ok, link} = Study.accept_invite(student, teacher.invite_slug)

      assert {:ok, _note} =
               Study.upsert_shared_note(link, Date.utc_today(), %{
                 content: "Professora deixou um comentário novo",
                 step_ids: []
               })

      conn = log_in_user(conn, student)
      {:ok, lv, _html} = live(conn, ~p"/study")

      assert has_element?(lv, "#study-home-shell")
      assert has_element?(lv, "#study-diary-panel")
      assert has_element?(lv, "#study-movement-panel")
      assert has_element?(lv, "#study-movement-card-#{link.id}")
      assert has_element?(lv, "#study-overview-grid")
      assert has_element?(lv, "#study-people-panel")
      assert has_element?(lv, "#study-history-panel")
      assert has_element?(lv, "#study-diary-form")
      assert has_element?(lv, "#study-related-steps-panel")

      assert has_element?(
               lv,
               "#study-profile-link-#{teacher.username}[href='/users/#{teacher.username}']"
             )

      assert has_element?(
               lv,
               "#study-open-shared-note-#{link.id}[href='/study/shared/#{link.id}']"
             )
    end

    test "shows weekly study summary in the hero area", %{conn: conn} do
      user = insert(:user)

      assert {:ok, _note} =
               Study.upsert_personal_note(user, Date.utc_today(), %{
                 content: "Treino",
                 step_ids: []
               })

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/study")

      assert has_element?(lv, "#study-weekly-summary")
    end
  end
end
