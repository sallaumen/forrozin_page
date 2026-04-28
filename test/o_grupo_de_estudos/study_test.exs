defmodule OGrupoDeEstudos.StudyTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Study

  describe "accept_invite/2" do
    test "creates a pending teacher-student link from the teacher invite slug" do
      teacher = insert(:user, is_teacher: true, invite_slug: "prof-lia")
      student = insert(:user)

      assert {:ok, link} = Study.accept_invite(student, "prof-lia")
      assert link.teacher_id == teacher.id
      assert link.student_id == student.id
      assert link.pending == true
      assert link.active == false
      assert link.ended_at == nil
    end
  end

  describe "upsert_personal_note/3" do
    test "does not persist blank notes" do
      user = insert(:user)
      today = Date.utc_today()

      assert {:ok, nil} = Study.upsert_personal_note(user, today, %{content: "", step_ids: []})
      assert Study.get_personal_note(user.id, today) == nil
    end
  end

  describe "search_related_steps/1" do
    test "returns public steps by code or name" do
      insert(:step,
        code: "SC",
        name: "Sacada simples",
        approved: true,
        wip: false,
        status: "published"
      )

      assert [%{code: "SC"} | _] = Study.search_related_steps("sac")
    end
  end

  describe "study dashboard helpers" do
    test "counts the last seven days of personal study" do
      user = insert(:user)
      today = ~D[2026-04-21]

      assert {:ok, _note} =
               Study.upsert_personal_note(user, today, %{content: "Treinei base", step_ids: []})

      assert {:ok, _note} =
               Study.upsert_personal_note(user, Date.add(today, -2), %{
                 content: "Revisei giros",
                 step_ids: []
               })

      assert 2 == Study.personal_note_week_count(user.id, today)
    end

    test "builds shared movement cards for the user" do
      teacher = insert(:user, is_teacher: true, name: "Ana", username: "ana")
      student = insert(:user, name: "Lia", username: "lia")
      today = ~D[2026-04-21]

      {:ok, link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(link, teacher)

      assert {:ok, _note} =
               Study.upsert_shared_note(link, today, %{
                 content: "Professora deixou uma observação importante",
                 step_ids: []
               })

      [movement] = Study.list_shared_activity_for_user(student.id, today)

      assert movement.link_id == link.id
      assert movement.counterpart.username == "ana"
      assert movement.has_today_note?
      assert movement.active
      assert movement.last_note_preview == "Professora deixou uma observação importante"
    end
  end
end
