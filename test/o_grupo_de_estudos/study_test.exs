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

  describe "goals" do
    test "create_goal/1 creates a personal goal" do
      user = insert(:user)

      assert {:ok, goal} = Study.create_goal(%{body: "Praticar sacada", owner_user_id: user.id})
      assert goal.body == "Praticar sacada"
      assert goal.completed == false
      assert goal.owner_user_id == user.id
    end

    test "create_goal/1 creates a shared goal" do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(link, teacher)

      assert {:ok, goal} =
               Study.create_goal(%{body: "Revisar giro", teacher_student_link_id: link.id})

      assert goal.teacher_student_link_id == link.id
    end

    test "toggle_goal/1 toggles completed status" do
      user = insert(:user)
      {:ok, goal} = Study.create_goal(%{body: "Meta teste", owner_user_id: user.id})
      assert goal.completed == false

      {:ok, toggled} = Study.toggle_goal(goal.id)
      assert toggled.completed == true

      {:ok, untoggled} = Study.toggle_goal(goal.id)
      assert untoggled.completed == false
    end

    test "delete_goal/1 removes a goal" do
      user = insert(:user)
      {:ok, goal} = Study.create_goal(%{body: "Deletar", owner_user_id: user.id})

      assert {:ok, _} = Study.delete_goal(goal.id)
      assert Study.list_personal_goals(user.id) == []
    end

    test "list_personal_goals/1 returns pending goals before completed ones" do
      user = insert(:user)
      {:ok, g1} = Study.create_goal(%{body: "A", owner_user_id: user.id})
      {:ok, g2} = Study.create_goal(%{body: "B", owner_user_id: user.id})
      Study.toggle_goal(g1.id)

      goals = Study.list_personal_goals(user.id)
      # g2 (not completed) must come before g1 (completed)
      assert hd(goals).id == g2.id
    end
  end

  describe "step_frequency_ranking/2" do
    test "counts step occurrences across personal notes, highest first" do
      user = insert(:user)
      section = insert(:section)
      step1 = insert(:step, section: section, code: "RNK-A")
      step2 = insert(:step, section: section, code: "RNK-B")
      today = OGrupoDeEstudos.Brazil.today()

      # step1 appears in two notes, step2 in one
      {:ok, _} =
        Study.upsert_personal_note(user, today, %{
          content: "Dia 1",
          step_ids: [step1.id, step2.id]
        })

      {:ok, _} =
        Study.upsert_personal_note(user, Date.add(today, -1), %{
          content: "Dia 2",
          step_ids: [step1.id]
        })

      ranking = Study.step_frequency_ranking(:personal, user.id)

      assert length(ranking) == 2
      first = hd(ranking)
      assert first.code == "RNK-A"
      assert first.count == 2
    end

    test "returns an empty list when the user has no personal notes" do
      user = insert(:user)
      assert Study.step_frequency_ranking(:personal, user.id) == []
    end
  end

  describe "suggest_teachers/2" do
    test "returns teachers not yet linked, excludes already-linked teacher" do
      student = insert(:user)
      teacher1 = insert(:user, is_teacher: true)
      teacher2 = insert(:user, is_teacher: true)
      already_linked = insert(:user, is_teacher: true)

      # Create a pending link so already_linked is excluded
      {:ok, _link} = Study.accept_invite(student, already_linked.invite_slug)

      suggestions = Study.suggest_teachers(student, limit: 10)
      suggestion_ids = Enum.map(suggestions, & &1.id)

      assert teacher1.id in suggestion_ids
      assert teacher2.id in suggestion_ids
      refute already_linked.id in suggestion_ids
    end

    test "returns an empty list when no unlinked teachers exist" do
      student = insert(:user)
      assert Study.suggest_teachers(student, limit: 5) == []
    end
  end
end
