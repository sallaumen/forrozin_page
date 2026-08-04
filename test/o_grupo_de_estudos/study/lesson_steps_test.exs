defmodule OGrupoDeEstudos.Study.LessonStepsTest do
  @moduledoc """
  Os passos que a lição do professor tratou.

  A lição nasceu com título e conteúdo e nada mais: o professor escrevia
  "trabalhamos inversão hoje" e a palavra inversão morria ali, sem levar a
  lugar nenhum. A nota do diário já vinculava passo desde sempre; a lição,
  que é o material mais deliberado que o professor produz, não vinculava.

  Aqui o vínculo passa a existir, no mesmo molde de `study_note_steps`.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Study

  setup do
    teacher = insert(:user, is_teacher: true)

    %{
      teacher: teacher,
      link: insert(:teacher_student_link, teacher: teacher, active: true),
      passo: insert(:step, code: "IV", name: "Inversão base"),
      outro: insert(:step, code: "SCSP", name: "Sacada com sacada de perna")
    }
  end

  defp lesson_attrs(attrs \\ %{}) do
    Map.merge(%{title: "Aula de sacadas", content: "O que vimos hoje."}, attrs)
  end

  describe "vincular passos ao criar a lição" do
    test "os passos escolhidos ficam na lição", ctx do
      assert {:ok, _lesson, _delivered} =
               Study.broadcast_lesson(
                 ctx.teacher,
                 lesson_attrs(%{step_ids: [ctx.passo.id, ctx.outro.id]}),
                 [ctx.link.id]
               )

      assert [lesson] = Study.list_lessons_for_teacher(ctx.teacher.id)
      assert ["IV", "SCSP"] = lesson.steps |> Enum.map(& &1.code) |> Enum.sort()
    end

    test "lição sem passo nenhum continua sendo lição", ctx do
      assert {:ok, _lesson, _} =
               Study.broadcast_lesson(ctx.teacher, lesson_attrs(), [ctx.link.id])

      assert [lesson] = Study.list_lessons_for_teacher(ctx.teacher.id)
      assert lesson.steps == []
    end

    test "o mesmo passo repetido entra uma vez só", ctx do
      {:ok, _lesson, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          lesson_attrs(%{step_ids: [ctx.passo.id, ctx.passo.id]}),
          [ctx.link.id]
        )

      assert [%{steps: [passo]}] = Study.list_lessons_for_teacher(ctx.teacher.id)
      assert passo.code == "IV"
    end

    test "passo que não existe não derruba o envio da lição", ctx do
      assert {:ok, _lesson, _} =
               Study.broadcast_lesson(
                 ctx.teacher,
                 lesson_attrs(%{step_ids: [Ecto.UUID.generate()]}),
                 [ctx.link.id]
               )

      assert [%{steps: []}] = Study.list_lessons_for_teacher(ctx.teacher.id)
    end
  end

  describe "os passos chegam em quem lê" do
    test "o aluno recebe a lição com os passos", ctx do
      {:ok, _lesson, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          lesson_attrs(%{step_ids: [ctx.passo.id]}),
          [ctx.link.id]
        )

      assert [lesson] = Study.list_lessons_for_link(ctx.link.id)
      assert [%{code: "IV", name: "Inversão base"}] = lesson.steps
    end

    test "cada lição carrega só os próprios passos", ctx do
      {:ok, _, _} =
        Study.broadcast_lesson(ctx.teacher, lesson_attrs(%{step_ids: [ctx.passo.id]}), [
          ctx.link.id
        ])

      {:ok, _, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          lesson_attrs(%{title: "Outra aula", step_ids: [ctx.outro.id]}),
          [ctx.link.id]
        )

      codes =
        ctx.link.id
        |> Study.list_lessons_for_link()
        |> Map.new(&{&1.title, Enum.map(&1.steps, fn s -> s.code end)})

      assert codes == %{"Aula de sacadas" => ["IV"], "Outra aula" => ["SCSP"]}
    end
  end

  describe "editar os passos da lição" do
    setup ctx do
      {:ok, lesson, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          lesson_attrs(%{step_ids: [ctx.passo.id]}),
          [ctx.link.id]
        )

      Map.put(ctx, :lesson, lesson)
    end

    test "trocar os passos vale para todos que receberam", ctx do
      assert {:ok, _} =
               Study.update_lesson(ctx.teacher, ctx.lesson, %{
                 title: ctx.lesson.title,
                 content: ctx.lesson.content,
                 step_ids: [ctx.outro.id]
               })

      assert [%{steps: [passo]}] = Study.list_lessons_for_link(ctx.link.id)
      assert passo.code == "SCSP"
    end

    test "editar só o texto não mexe nos passos", ctx do
      assert {:ok, _} =
               Study.update_lesson(ctx.teacher, ctx.lesson, %{
                 title: ctx.lesson.title,
                 content: "Texto corrigido."
               })

      assert [%{steps: [%{code: "IV"}]}] = Study.list_lessons_for_link(ctx.link.id)
    end

    test "esvaziar a lista tira todos os passos", ctx do
      assert {:ok, _} =
               Study.update_lesson(ctx.teacher, ctx.lesson, %{
                 title: ctx.lesson.title,
                 content: ctx.lesson.content,
                 step_ids: []
               })

      assert [%{steps: []}] = Study.list_lessons_for_link(ctx.link.id)
    end

    test "quem não é dono da lição não troca os passos", ctx do
      estranho = insert(:user, is_teacher: true)

      assert {:error, :unauthorized} =
               Study.update_lesson(estranho, ctx.lesson, %{step_ids: [ctx.outro.id]})

      assert [%{steps: [%{code: "IV"}]}] = Study.list_lessons_for_link(ctx.link.id)
    end

    test "apagar a lição leva os vínculos junto", ctx do
      assert {:ok, _} = Study.delete_lesson(ctx.teacher, ctx.lesson)

      assert Study.list_lessons_for_teacher(ctx.teacher.id) == []
    end
  end

  describe "consultar os passos de uma lição" do
    test "devolve os passos vinculados", ctx do
      {:ok, lesson, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          lesson_attrs(%{step_ids: [ctx.passo.id]}),
          [ctx.link.id]
        )

      assert [%{code: "IV", name: "Inversão base"}] = Study.lesson_steps(lesson.id)
    end

    test "lição sem passos devolve lista vazia", ctx do
      {:ok, lesson, _} = Study.broadcast_lesson(ctx.teacher, lesson_attrs(), [ctx.link.id])

      assert Study.lesson_steps(lesson.id) == []
    end
  end
end
