defmodule OGrupoDeEstudos.Study.LessonsTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Study

  defp lesson_ids_of(link) do
    link.id |> Study.list_lessons_for_link() |> Enum.map(& &1.id)
  end

  defp teacher_with_students(count) do
    teacher = insert(:user, is_teacher: true)

    links =
      for _ <- 1..count do
        insert(:teacher_student_link, teacher: teacher, active: true)
      end

    {teacher, links}
  end

  describe "broadcast_lesson/3" do
    test "cria a lição e entrega para os vínculos selecionados" do
      {teacher, [link_a, link_b, link_c]} = teacher_with_students(3)

      assert {:ok, lesson, _delivered} =
               Study.broadcast_lesson(
                 teacher,
                 %{title: "Workshop de sacadas", content: "Conteúdo do workshop."},
                 [link_a.id, link_b.id]
               )

      assert lesson.title == "Workshop de sacadas"
      assert lesson.teacher_id == teacher.id

      delivered_ids = Study.list_lessons_for_link(link_a.id) |> Enum.map(& &1.id)
      assert lesson.id in delivered_ids
      assert Study.list_lessons_for_link(link_c.id) == []
    end

    test "ignora ids de vínculos que não pertencem ao professor" do
      {teacher, [link]} = teacher_with_students(1)
      foreign_link = insert(:teacher_student_link, active: true)

      assert {:ok, lesson, _delivered} =
               Study.broadcast_lesson(
                 teacher,
                 %{title: "Aula", content: "Texto"},
                 [link.id, foreign_link.id]
               )

      assert [%{id: _}] = Study.list_lessons_for_link(link.id)
      assert Study.list_lessons_for_link(foreign_link.id) == []
      assert lesson.id
    end

    test "ignora vínculos inativos do próprio professor" do
      {teacher, [active_link]} = teacher_with_students(1)
      inactive = insert(:teacher_student_link, teacher: teacher, active: false)

      assert {:ok, _lesson, _delivered} =
               Study.broadcast_lesson(teacher, %{title: "Aula", content: "Texto"}, [
                 active_link.id,
                 inactive.id
               ])

      assert Study.list_lessons_for_link(inactive.id) == []
    end

    test "sem nenhum vínculo válido retorna erro e não cria a lição" do
      teacher = insert(:user, is_teacher: true)

      assert {:error, :no_students} =
               Study.broadcast_lesson(teacher, %{title: "Aula", content: "Texto"}, [])

      assert Study.list_lessons_for_teacher(teacher.id) == []
    end

    test "valida título e conteúdo obrigatórios" do
      {teacher, [link]} = teacher_with_students(1)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Study.broadcast_lesson(teacher, %{title: "", content: ""}, [link.id])

      assert errors_on(changeset).title != []
    end

    test "notifica cada aluno com a ação :lesson_shared" do
      {teacher, [link_a, link_b]} = teacher_with_students(2)

      {:ok, lesson, _delivered} =
        Study.broadcast_lesson(teacher, %{title: "Aula", content: "Texto"}, [
          link_a.id,
          link_b.id
        ])

      notified =
        OGrupoDeEstudos.Engagement.list_notifications(link_a.student_id)
        |> Enum.filter(&(&1.action == :lesson_shared))

      assert [notification] = notified
      assert notification.target_id == lesson.id
      assert notification.parent_id == link_a.id
    end
  end

  describe "list_lessons_for_link/1" do
    test "retorna lições com read_at da entrega, mais recentes primeiro" do
      {teacher, [link]} = teacher_with_students(1)

      {:ok, older, _delivered} =
        Study.broadcast_lesson(teacher, %{title: "Um", content: "A"}, [link.id])

      {:ok, newer, _delivered} =
        Study.broadcast_lesson(teacher, %{title: "Dois", content: "B"}, [link.id])

      assert [first, second] = Study.list_lessons_for_link(link.id)
      assert first.id == newer.id
      assert second.id == older.id
      assert first.read_at == nil
    end
  end

  describe "mark_lessons_read/2" do
    test "aluno marca as entregas do vínculo como lidas" do
      {teacher, [link]} = teacher_with_students(1)

      {:ok, _, _delivered} =
        Study.broadcast_lesson(teacher, %{title: "Aula", content: "Texto"}, [link.id])

      student = link.student
      assert {:ok, 1} = Study.mark_lessons_read(link, student, lesson_ids_of(link))

      assert [%{read_at: %DateTime{}}] = Study.list_lessons_for_link(link.id)
      assert {:ok, 0} = Study.mark_lessons_read(link, student, lesson_ids_of(link))
    end

    test "professor não marca como lida (só o aluno do vínculo)" do
      {teacher, [link]} = teacher_with_students(1)

      {:ok, _, _delivered} =
        Study.broadcast_lesson(teacher, %{title: "Aula", content: "Texto"}, [link.id])

      assert {:error, :unauthorized} = Study.mark_lessons_read(link, teacher, lesson_ids_of(link))
      assert [%{read_at: nil}] = Study.list_lessons_for_link(link.id)
    end
  end

  describe "list_lessons_for_teacher/1" do
    test "retorna lições com contagens de entrega e leitura, sem N+1" do
      {teacher, [link_a, link_b]} = teacher_with_students(2)

      {:ok, lesson, _delivered} =
        Study.broadcast_lesson(teacher, %{title: "Aula", content: "Texto"}, [
          link_a.id,
          link_b.id
        ])

      {:ok, 1} = Study.mark_lessons_read(link_a, link_a.student, lesson_ids_of(link_a))

      assert [row] = Study.list_lessons_for_teacher(teacher.id)
      assert row.lesson.id == lesson.id
      assert row.delivered_count == 2
      assert row.read_count == 1
    end
  end

  describe "update_lesson/3 e delete_lesson/2" do
    test "professor edita a própria lição (uma escrita corrige todas as entregas)" do
      {teacher, [link]} = teacher_with_students(1)

      {:ok, lesson, _delivered} =
        Study.broadcast_lesson(teacher, %{title: "Aula", content: "V1"}, [link.id])

      assert {:ok, updated} = Study.update_lesson(teacher, lesson, %{content: "V2 corrigida"})
      assert updated.content == "V2 corrigida"

      assert [%{content: "V2 corrigida"}] = Study.list_lessons_for_link(link.id)
    end

    test "outro usuário não edita nem deleta" do
      {teacher, [link]} = teacher_with_students(1)

      {:ok, lesson, _delivered} =
        Study.broadcast_lesson(teacher, %{title: "Aula", content: "X"}, [link.id])

      other = insert(:user, is_teacher: true)

      assert {:error, :unauthorized} = Study.update_lesson(other, lesson, %{content: "hack"})
      assert {:error, :unauthorized} = Study.delete_lesson(other, lesson)
    end

    test "delete remove a lição e as entregas" do
      {teacher, [link]} = teacher_with_students(1)

      {:ok, lesson, _delivered} =
        Study.broadcast_lesson(teacher, %{title: "Aula", content: "X"}, [link.id])

      assert {:ok, _} = Study.delete_lesson(teacher, lesson)
      assert Study.list_lessons_for_link(link.id) == []
      assert Study.list_lessons_for_teacher(teacher.id) == []
    end
  end

  describe "links_with_unread_lessons/1" do
    test "MapSet dos vínculos com lição não lida (batch, para a lista de professores)" do
      {teacher, [link_a, link_b]} = teacher_with_students(2)

      {:ok, _, _delivered} =
        Study.broadcast_lesson(teacher, %{title: "Aula", content: "X"}, [link_a.id])

      unread = Study.unread_lesson_link_ids([link_a.id, link_b.id])
      assert MapSet.member?(unread, link_a.id)
      refute MapSet.member?(unread, link_b.id)
    end
  end

  describe "count_unread_lessons/1" do
    test "conta entregas não lidas do aluno em todos os vínculos; zera ao ler" do
      student = insert(:user)
      teacher_a = insert(:user, is_teacher: true)
      teacher_b = insert(:user, is_teacher: true)
      link_a = insert(:teacher_student_link, teacher: teacher_a, student: student, active: true)
      link_b = insert(:teacher_student_link, teacher: teacher_b, student: student, active: true)

      {:ok, _, _delivered} =
        Study.broadcast_lesson(teacher_a, %{title: "A", content: "x"}, [link_a.id])

      {:ok, _, _delivered} =
        Study.broadcast_lesson(teacher_b, %{title: "B", content: "y"}, [link_b.id])

      assert Study.count_unread_lessons(student.id) == 2

      {:ok, 1} = Study.mark_lessons_read(link_a, student, lesson_ids_of(link_a))
      assert Study.count_unread_lessons(student.id) == 1
    end

    test "não conta entregas de outros alunos" do
      {teacher, [link]} = teacher_with_students(1)
      {:ok, _, 1} = Study.broadcast_lesson(teacher, %{title: "A", content: "x"}, [link.id])
      outro = insert(:user)

      assert Study.count_unread_lessons(outro.id) == 0
      assert Study.count_unread_lessons(link.student_id) == 1
    end
  end

  describe "achados da revisão — recibo honesto e vínculo encerrado" do
    test "broadcast publica {:lesson_published} no tópico de cada vínculo" do
      {teacher, [link]} = teacher_with_students(1)
      Phoenix.PubSub.subscribe(OGrupoDeEstudos.PubSub, Study.note_topic(link.id))

      {:ok, _, 1} = Study.broadcast_lesson(teacher, %{title: "A", content: "x"}, [link.id])

      assert_receive {:lesson_published, link_id}
      assert link_id == link.id
    end

    test "update e delete também publicam para quem recebeu" do
      {teacher, [link]} = teacher_with_students(1)
      {:ok, lesson, 1} = Study.broadcast_lesson(teacher, %{title: "A", content: "x"}, [link.id])

      Phoenix.PubSub.subscribe(OGrupoDeEstudos.PubSub, Study.note_topic(link.id))

      {:ok, _} = Study.update_lesson(teacher, lesson, %{content: "x2"})
      assert_receive {:lesson_published, _}

      {:ok, _} = Study.delete_lesson(teacher, lesson)
      assert_receive {:lesson_published, _}
    end

    test "mark_lessons_read é escopado: não marca lição fora da lista" do
      {teacher, [link]} = teacher_with_students(1)
      {:ok, primeira, 1} = Study.broadcast_lesson(teacher, %{title: "1", content: "a"}, [link.id])
      {:ok, _segunda, 1} = Study.broadcast_lesson(teacher, %{title: "2", content: "b"}, [link.id])

      assert {:ok, 1} = Study.mark_lessons_read(link, link.student, [primeira.id])

      by_title = Map.new(Study.list_lessons_for_link(link.id), &{&1.title, &1.read_at})
      assert %DateTime{} = by_title["1"]
      assert by_title["2"] == nil
    end

    test "vínculo encerrado sai do contador e do MapSet de não lidas" do
      {teacher, [link]} = teacher_with_students(1)
      {:ok, _, 1} = Study.broadcast_lesson(teacher, %{title: "A", content: "x"}, [link.id])
      student = link.student

      assert Study.count_unread_lessons(student.id) == 1

      {:ok, _} = Study.end_link(link, student)

      assert Study.count_unread_lessons(student.id) == 0
      assert Study.unread_lesson_link_ids([link.id]) == MapSet.new()
    end

    test "get_lesson com id malformado retorna nil sem crash" do
      assert Study.get_lesson("nao-e-uuid") == nil
    end

    test "notifica os dois alunos, cada um com a sua entrega" do
      {teacher, [link_a, link_b]} = teacher_with_students(2)

      {:ok, lesson, 2} =
        Study.broadcast_lesson(teacher, %{title: "Aula", content: "x"}, [link_a.id, link_b.id])

      for link <- [link_a, link_b] do
        assert [n] =
                 OGrupoDeEstudos.Engagement.list_notifications(link.student_id)
                 |> Enum.filter(&(&1.action == :lesson_shared))

        assert n.target_id == lesson.id
        assert n.parent_id == link.id
      end
    end
  end
end
