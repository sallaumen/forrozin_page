defmodule OGrupoDeEstudos.StudyTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Study
  alias OGrupoDeEstudos.Study.{Goal, LinkError, TeacherStudentLink}

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

  describe "link errors are returned as %LinkError{} (domain error data)" do
    test "accept_invite with an unknown slug -> teacher_not_found" do
      assert {:error, %LinkError{code: :teacher_not_found}} =
               Study.accept_invite(insert(:user), "nope")
    end

    test "accept_invite with your own slug -> cannot_link_self" do
      me = insert(:user, is_teacher: true, invite_slug: "eu")
      assert {:error, %LinkError{code: :cannot_link_self}} = Study.accept_invite(me, "eu")
    end

    test "request_teacher_link to yourself -> cannot_link_self" do
      me = insert(:user)
      assert {:error, %LinkError{code: :cannot_link_self}} = Study.request_teacher_link(me, me.id)
    end

    test "request_teacher_link when a request is already pending -> already_pending" do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      assert {:ok, _} = Study.request_teacher_link(student, teacher.id)

      assert {:error, %LinkError{code: :already_pending}} =
               Study.request_teacher_link(student, teacher.id)
    end

    test "invite_student_link from a non-teacher -> not_teacher" do
      assert {:error, %LinkError{code: :not_teacher}} =
               Study.invite_student_link(insert(:user), insert(:user).id)
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
        status: :published
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

    test "toggle_goal/2 toggles completed status for the owner" do
      user = insert(:user)
      {:ok, goal} = Study.create_goal(%{body: "Meta teste", owner_user_id: user.id})
      assert goal.completed == false

      {:ok, toggled} = Study.toggle_goal(user, goal.id)
      assert toggled.completed == true

      {:ok, untoggled} = Study.toggle_goal(user, goal.id)
      assert untoggled.completed == false
    end

    test "delete_goal/2 removes the owner's goal" do
      user = insert(:user)
      {:ok, goal} = Study.create_goal(%{body: "Deletar", owner_user_id: user.id})

      assert {:ok, _} = Study.delete_goal(user, goal.id)
      assert Study.list_personal_goals(user.id) == []
    end

    test "list_personal_goals/1 returns pending goals before completed ones" do
      user = insert(:user)
      {:ok, g1} = Study.create_goal(%{body: "A", owner_user_id: user.id})
      {:ok, g2} = Study.create_goal(%{body: "B", owner_user_id: user.id})
      Study.toggle_goal(user, g1.id)

      goals = Study.list_personal_goals(user.id)
      # g2 (not completed) must come before g1 (completed)
      assert hd(goals).id == g2.id
    end

    test "delete_goal/2 refuses another user's personal goal (IDOR)" do
      owner = insert(:user)
      attacker = insert(:user)
      {:ok, goal} = Study.create_goal(%{body: "Privada", owner_user_id: owner.id})

      assert {:error, :not_found} = Study.delete_goal(attacker, goal.id)
      assert Repo.get(Goal, goal.id), "a meta da vitima deve sobreviver"
    end

    test "toggle_goal/2 refuses another user's personal goal (IDOR)" do
      owner = insert(:user)
      attacker = insert(:user)
      {:ok, goal} = Study.create_goal(%{body: "Privada", owner_user_id: owner.id})

      assert {:error, :not_found} = Study.toggle_goal(attacker, goal.id)
      assert Repo.get(Goal, goal.id).completed == false
    end

    test "toggle_goal/2 allows both members of the link on a shared goal" do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(link, teacher)
      {:ok, goal} = Study.create_goal(%{body: "Compartilhada", teacher_student_link_id: link.id})

      assert {:ok, %{completed: true}} = Study.toggle_goal(teacher, goal.id)
      assert {:ok, %{completed: false}} = Study.toggle_goal(student, goal.id)
    end

    test "delete_goal/2 refuses a shared goal for a non-member (IDOR)" do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      outsider = insert(:user)
      {:ok, link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(link, teacher)
      {:ok, goal} = Study.create_goal(%{body: "Compartilhada", teacher_student_link_id: link.id})

      assert {:error, :not_found} = Study.delete_goal(outsider, goal.id)
      assert Repo.get(Goal, goal.id), "a meta compartilhada deve sobreviver"
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

  describe "teacher_note" do
    setup do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, link} = Study.accept_invite(student, teacher.invite_slug)
      {:ok, link} = Study.accept_link_request(link, teacher)
      %{teacher: teacher, student: student, link: link}
    end

    test "update_teacher_note/3 saves a private note for the link's teacher", ctx do
      {:ok, updated} =
        Study.update_teacher_note(ctx.teacher, ctx.link.id, "Precisa focar em giros")

      assert updated.teacher_note == "Precisa focar em giros"
    end

    test "update_teacher_note/3 refuses anyone who is not the link's teacher (IDOR)", ctx do
      assert {:error, :unauthorized} = Study.update_teacher_note(ctx.student, ctx.link.id, "hack")

      assert {:error, :unauthorized} =
               Study.update_teacher_note(insert(:user), ctx.link.id, "hack")

      refute Repo.get(TeacherStudentLink, ctx.link.id).teacher_note == "hack"
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

  describe "active days (consistência)" do
    test "record_active_day/2 é idempotente por (user, dia)" do
      user = insert(:user)
      today = Date.utc_today()

      assert {:ok, _} = Study.record_active_day(user.id, today)
      assert {:ok, _} = Study.record_active_day(user.id, today)

      assert Study.active_days_between(user.id, today, today) == MapSet.new([today])
    end

    test "active_days_between/3 devolve só os dias dentro do intervalo" do
      user = insert(:user)
      Study.record_active_day(user.id, ~D[2026-06-01])
      Study.record_active_day(user.id, ~D[2026-06-15])
      Study.record_active_day(user.id, ~D[2026-07-01])

      assert Study.active_days_between(user.id, ~D[2026-06-01], ~D[2026-06-30]) ==
               MapSet.new([~D[2026-06-01], ~D[2026-06-15]])
    end
  end

  describe "get_link_between/3" do
    test "finds a link regardless of direction" do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      link = insert(:teacher_student_link, teacher: teacher, student: student)

      assert Study.get_link_between(teacher.id, student.id).id == link.id
      assert Study.get_link_between(student.id, teacher.id).id == link.id
    end

    test "filters by status" do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)

      link =
        insert(:teacher_student_link,
          teacher: teacher,
          student: student,
          pending: true,
          active: false
        )

      assert Study.get_link_between(teacher.id, student.id, status: :pending).id == link.id
      assert Study.get_link_between(teacher.id, student.id, status: :active) == nil
    end

    test "returns nil when there is no link" do
      assert Study.get_link_between(insert(:user).id, insert(:user).id) == nil
    end
  end
end
