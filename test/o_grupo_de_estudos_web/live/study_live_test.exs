defmodule OGrupoDeEstudosWeb.StudyLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Repo
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
      assert has_element?(lv, "#personal-diary")
      assert html =~ "Meus professores"
      assert html =~ "O que rolou na prática?"
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
      {:ok, _link} = Study.accept_link_request(link, teacher)
      conn = log_in_user(conn, teacher)

      {:ok, lv, _html} = live(conn, ~p"/study")

      # Switch to students tab
      html = render_click(lv, "switch_study_tab", %{"tab" => "students"})

      assert html =~ "Meus alunos"
      assert html =~ student.name
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

      html = render_click(lv, "add_personal_step", %{"id" => step.id})

      assert html =~ step.code
      assert has_element?(lv, "[phx-click='remove_personal_step'][phx-value-id='#{step.id}']")
    end

    test "shows the teacher in the teachers tab with a link to the shared diary", %{conn: conn} do
      teacher = insert(:user, is_teacher: true, name: "Ana", username: "ana")
      student = insert(:user, name: "Lia", username: "lia")
      {:ok, link} = Study.accept_invite(student, teacher.invite_slug)
      # Accept the pending request so the link becomes active
      {:ok, link} = Study.accept_link_request(link, teacher)

      assert {:ok, _note} =
               Study.upsert_shared_note(link, Date.utc_today(), %{
                 content: "Professora deixou um comentário novo",
                 step_ids: []
               })

      conn = log_in_user(conn, student)
      {:ok, lv, _html} = live(conn, ~p"/study")

      assert has_element?(lv, "#study-home-shell")
      assert has_element?(lv, "#personal-diary")

      html = render_click(lv, "switch_study_tab", %{"tab" => "teachers"})

      assert html =~ teacher.name
      assert has_element?(lv, "a[href='/study/shared/#{link.id}']")
      assert has_element?(lv, "a[href='/users/#{teacher.username}']")
    end

    test "can add a step to a historical note via inline editor", %{conn: conn} do
      user = insert(:user)

      step =
        insert(:step,
          code: "GP",
          name: "Giro paulista",
          approved: true,
          wip: false,
          status: "published"
        )

      past_date = Date.add(OGrupoDeEstudos.Brazil.today(), -1)

      assert {:ok, _note} =
               Study.upsert_personal_note(user, past_date, %{
                 content: "Ontem",
                 step_ids: []
               })

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/study")

      note = Study.list_personal_note_history(user.id) |> hd()

      render_click(lv, "edit_history_steps", %{"note-id" => note.id})

      assert render_change(lv, "search_history_step", %{"term" => "giro"}) =~ "Giro paulista"

      render_click(lv, "add_history_step", %{"note-id" => note.id, "step-id" => step.id})

      updated = Study.list_personal_note_history(user.id) |> hd()
      assert Enum.any?(updated.related_steps, &(&1.id == step.id))
    end

    test "can remove a step from a historical note via inline editor", %{conn: conn} do
      user = insert(:user)

      step =
        insert(:step,
          code: "BL",
          name: "Base lateral",
          approved: true,
          wip: false,
          status: "published"
        )

      past_date = Date.add(OGrupoDeEstudos.Brazil.today(), -1)

      assert {:ok, _note} =
               Study.upsert_personal_note(user, past_date, %{
                 content: "Ontem",
                 step_ids: [step.id]
               })

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/study")

      note = Study.list_personal_note_history(user.id) |> hd()

      render_click(lv, "edit_history_steps", %{"note-id" => note.id})
      render_click(lv, "remove_history_step", %{"note-id" => note.id, "step-id" => step.id})

      updated = Study.list_personal_note_history(user.id) |> hd()
      refute Enum.any?(updated.related_steps, &(&1.id == step.id))
    end

    test "teacher can nudge a student who has not written today", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(link, teacher)

      conn = log_in_user(conn, teacher)
      {:ok, lv, _html} = live(conn, ~p"/study")

      render_click(lv, "switch_study_tab", %{"tab" => "students"})
      assert has_element?(lv, "#study-nudge-student-#{link.id}")

      render_click(lv, "nudge_student", %{"link-id" => link.id})

      notifications =
        Repo.all(
          from n in Notification,
            where: n.user_id == ^student.id and n.action == "study_nudge"
        )

      assert notifications != []
    end

    test "nudge button is not shown when student already wrote today", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(link, teacher)

      # Student writes in the shared diary today
      Study.upsert_shared_note(link, OGrupoDeEstudos.Brazil.today(), %{
        content: "Estudei hoje",
        step_ids: []
      })

      conn = log_in_user(conn, teacher)
      {:ok, lv, _html} = live(conn, ~p"/study")

      render_click(lv, "switch_study_tab", %{"tab" => "students"})
      refute has_element?(lv, "#study-nudge-student-#{link.id}")
    end

    test "shows the monthly consistency summary in the sidebar", %{conn: conn} do
      user = insert(:user)

      assert {:ok, _note} =
               Study.upsert_personal_note(user, OGrupoDeEstudos.Brazil.today(), %{
                 content: "Treino",
                 step_ids: []
               })

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/study")

      assert html =~ "Consistência"
      assert html =~ "registro"
    end
  end

  describe "authorization (IDOR)" do
    test "save_teacher_note refuses a forged link-id from another teacher", %{conn: conn} do
      teacher_a = insert(:user, is_teacher: true)
      teacher_b = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, link} = Study.accept_invite(student, teacher_a.invite_slug)
      {:ok, link} = Study.accept_link_request(link, teacher_a)

      conn = log_in_user(conn, teacher_b)
      {:ok, lv, _html} = live(conn, ~p"/study")

      render_change(lv, "save_teacher_note", %{"link-id" => link.id, "note" => "hack"})

      refute Study.get_link_for_member(link.id, teacher_a.id).teacher_note == "hack"
    end

    test "accept_request refuses another teacher's pending request", %{conn: conn} do
      teacher_a = insert(:user, is_teacher: true)
      teacher_b = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, pending} = Study.accept_invite(student, teacher_a.invite_slug)

      conn = log_in_user(conn, teacher_b)
      {:ok, lv, _html} = live(conn, ~p"/study")

      render_click(lv, "accept_request", %{"id" => pending.id})

      assert Study.get_link_for_member(pending.id, teacher_a.id).pending
    end
  end

  describe "expansao de notas longas no historico pessoal" do
    test "nota longa usa phx-click toggle, nao <details>", %{conn: conn} do
      user = insert(:user)
      past_date = Date.add(OGrupoDeEstudos.Brazil.today(), -1)
      long_content = String.duplicate("a", 151)

      {:ok, _note} =
        Study.upsert_personal_note(user, past_date, %{content: long_content, step_ids: []})

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/study")

      assert has_element?(lv, "[phx-click='toggle_note_expansion']")
      refute has_element?(lv, "article details")
    end

    test "toggle_note_expansion expande e colapsa nota longa", %{conn: conn} do
      user = insert(:user)
      past_date = Date.add(OGrupoDeEstudos.Brazil.today(), -1)
      long_content = String.duplicate("a", 151)

      {:ok, note} =
        Study.upsert_personal_note(user, past_date, %{content: long_content, step_ids: []})

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/study")

      assert has_element?(lv, "[phx-click='toggle_note_expansion']", "ver mais")

      render_click(lv, "toggle_note_expansion", %{"id" => note.id})

      assert has_element?(lv, "[phx-click='toggle_note_expansion']", "ver menos")

      render_click(lv, "toggle_note_expansion", %{"id" => note.id})

      assert has_element?(lv, "[phx-click='toggle_note_expansion']", "ver mais")
    end
  end

  describe "estado vazio motivante" do
    test "exibe headline motivante quando nao ha registro hoje", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/study")

      assert html =~ "Sem registro hoje ainda"
    end

    test "oculta estado vazio quando usuario ja registrou hoje", %{conn: conn} do
      user = insert(:user)

      Study.upsert_personal_note(user, OGrupoDeEstudos.Brazil.today(), %{
        content: "Estudei hoje",
        step_ids: []
      })

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/study")

      refute html =~ "Sem registro hoje ainda"
    end
  end
end
