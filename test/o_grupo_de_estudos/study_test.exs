defmodule OGrupoDeEstudos.StudyTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Study

  describe "accept_invite/2" do
    test "creates an active teacher-student link from the teacher invite slug" do
      teacher = insert(:user, is_teacher: true, invite_slug: "prof-lia")
      student = insert(:user)

      assert {:ok, link} = Study.accept_invite(student, "prof-lia")
      assert link.teacher_id == teacher.id
      assert link.student_id == student.id
      assert link.active
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
end
