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
        |> form("#shared-diary-form", %{"shared_note" => %{"content" => "Treinamos sacadas hoje"}})
        |> render_change()

      _ = :sys.get_state(lv.pid)

      assert html =~ "Treinamos sacadas hoje"

      assert Study.get_shared_note(link.id, OGrupoDeEstudos.Brazil.today()).content ==
               "Treinamos sacadas hoje"
    end

    test "non-member is redirected away from a shared diary (IDOR)", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, pending_link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(pending_link, teacher)

      stranger = insert(:user)
      conn = log_in_user(conn, stranger)

      assert {:error, {:live_redirect, %{to: "/study"}}} =
               live(conn, ~p"/study/shared/#{link.id}")
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

    test "can add a step to a historical shared note via inline editor", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)

      step =
        insert(:step,
          code: "SSIV",
          name: "Inversao",
          approved: true,
          wip: false,
          status: :published
        )

      {:ok, pending_link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(pending_link, teacher)

      past_date = Date.add(OGrupoDeEstudos.Brazil.today(), -1)

      assert {:ok, _note} =
               Study.upsert_shared_note(link, past_date, %{
                 content: "Ontem",
                 step_ids: []
               })

      conn = log_in_user(conn, teacher)
      {:ok, lv, _html} = live(conn, ~p"/study/shared/#{link.id}")

      note = Study.list_shared_note_history(link.id) |> hd()

      render_click(lv, "edit_history_steps", %{"note-id" => note.id})

      assert render_change(lv, "search_history_step", %{"term" => "inver"}) =~ "Inversao"

      render_click(lv, "add_history_step", %{"note-id" => note.id, "step-id" => step.id})

      updated = Study.list_shared_note_history(link.id) |> hd()
      assert Enum.any?(updated.related_steps, &(&1.id == step.id))
    end

    test "can remove a step from a historical shared note via inline editor", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)

      step =
        insert(:step,
          code: "SSSC",
          name: "Sacada circular",
          approved: true,
          wip: false,
          status: :published
        )

      {:ok, pending_link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(pending_link, teacher)

      past_date = Date.add(OGrupoDeEstudos.Brazil.today(), -1)

      assert {:ok, _note} =
               Study.upsert_shared_note(link, past_date, %{
                 content: "Ontem",
                 step_ids: [step.id]
               })

      conn = log_in_user(conn, teacher)
      {:ok, lv, _html} = live(conn, ~p"/study/shared/#{link.id}")

      note = Study.list_shared_note_history(link.id) |> hd()

      render_click(lv, "edit_history_steps", %{"note-id" => note.id})
      render_click(lv, "remove_history_step", %{"note-id" => note.id, "step-id" => step.id})

      updated = Study.list_shared_note_history(link.id) |> hd()
      refute Enum.any?(updated.related_steps, &(&1.id == step.id))
    end

    test "can search and add related steps to the shared diary", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)

      step =
        insert(:step,
          code: "SSBF",
          name: "Base frontal",
          approved: true,
          wip: false,
          status: :published
        )

      {:ok, pending_link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(pending_link, teacher)
      conn = log_in_user(conn, teacher)
      {:ok, lv, _html} = live(conn, ~p"/study/shared/#{link.id}")

      assert render_change(lv, "search_shared_step", %{"term" => "base"}) =~ "Base frontal"

      html = render_click(lv, "add_shared_step", %{"id" => step.id})

      assert html =~ step.code
      assert has_element?(lv, "[phx-click='remove_shared_step'][phx-value-id='#{step.id}']")
    end
  end

  describe "expansao de notas longas no historico compartilhado" do
    test "nota longa usa phx-click toggle, nao <details>", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, pending_link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(pending_link, teacher)

      past_date = Date.add(OGrupoDeEstudos.Brazil.today(), -1)
      long_content = String.duplicate("a", 151)

      {:ok, _note} =
        Study.upsert_shared_note(link, past_date, %{content: long_content, step_ids: []})

      conn = log_in_user(conn, teacher)
      {:ok, lv, _html} = live(conn, ~p"/study/shared/#{link.id}")

      assert has_element?(lv, "[phx-click='toggle_note_expansion']")
      refute has_element?(lv, "article details")
    end

    test "toggle_note_expansion expande e colapsa nota longa", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, pending_link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(pending_link, teacher)

      past_date = Date.add(OGrupoDeEstudos.Brazil.today(), -1)
      long_content = String.duplicate("a", 151)

      {:ok, note} =
        Study.upsert_shared_note(link, past_date, %{content: long_content, step_ids: []})

      conn = log_in_user(conn, teacher)
      {:ok, lv, _html} = live(conn, ~p"/study/shared/#{link.id}")

      assert has_element?(lv, "[phx-click='toggle_note_expansion']", "ver mais")

      render_click(lv, "toggle_note_expansion", %{"id" => note.id})

      assert has_element?(lv, "[phx-click='toggle_note_expansion']", "ver menos")

      render_click(lv, "toggle_note_expansion", %{"id" => note.id})

      assert has_element?(lv, "[phx-click='toggle_note_expansion']", "ver mais")
    end
  end

  describe "save_teacher_note — erro visível" do
    test "aluno não salva anotação do professor e vê o motivo", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      link = insert(:teacher_student_link, teacher: teacher, student: student)

      {:ok, lv, _html} = live(log_in_user(conn, student), ~p"/study/shared/#{link.id}")

      html = render_submit(lv, "save_teacher_note", %{"note" => "tentativa"})

      assert html =~ "Sem permissão para editar esta anotação."
    end
  end
end
