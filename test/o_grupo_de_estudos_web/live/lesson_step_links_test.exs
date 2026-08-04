defmodule OGrupoDeEstudosWeb.LessonStepLinksTest do
  @moduledoc """
  O passo citado na lição vira caminho, dos dois lados.

  Quem dá a aula escreve a lição e vincula os passos que tratou; quem lê
  encontra ali o chip que abre a folha do passo, com o gesto de marcar como
  aprendido. Antes, "trabalhamos inversão hoje" era palavra morta: o aluno
  lia o nome do passo e não tinha como chegar nele.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Engagement, Study}

  setup %{conn: conn} do
    teacher = insert(:user, is_teacher: true)

    %{
      conn: conn,
      teacher: teacher,
      link: insert(:teacher_student_link, teacher: teacher, active: true),
      passo: insert(:step, code: "IV", name: "Inversão base"),
      outro: insert(:step, code: "SCSP", name: "Sacada com sacada de perna")
    }
  end

  # O gesto real: procura no acervo, clica na sugestão.
  defp vincular(lv, passo) do
    render_change(lv, "search_lesson_step", %{"term" => passo.code})
    render_click(lv, "add_lesson_step", %{"id" => passo.id, "step-id" => passo.id})
  end

  describe "o professor vincula passos no composer" do
    setup ctx do
      {:ok, lv, _html} = live(log_in_user(ctx.conn, ctx.teacher), ~p"/study")
      render_click(lv, "switch_study_tab", %{"tab" => "students"})
      render_click(lv, "open_lesson_composer", %{})

      Map.put(ctx, :lv, lv)
    end

    test "o composer oferece o campo de vincular passo", ctx do
      assert has_element?(ctx.lv, "#lesson-composer-step-search")
    end

    test "buscar sugere o passo do acervo", ctx do
      html = render_change(ctx.lv, "search_lesson_step", %{"term" => "invers"})

      assert html =~ "Inversão base"
    end

    test "adicionar põe o chip no composer", ctx do
      html = vincular(ctx.lv, ctx.passo)

      assert html =~ "IV"
      assert html =~ "Inversão base"
    end

    test "o mesmo passo não entra duas vezes", ctx do
      vincular(ctx.lv, ctx.passo)
      html = vincular(ctx.lv, ctx.passo)

      assert html |> String.split("Inversão base") |> length() == 2
    end

    test "remover tira o chip", ctx do
      vincular(ctx.lv, ctx.passo)
      html = render_click(ctx.lv, "remove_lesson_step", %{"step-id" => ctx.passo.id})

      refute html =~ "Inversão base"
    end

    test "enviar a lição leva os passos junto", ctx do
      vincular(ctx.lv, ctx.passo)

      render_submit(element(ctx.lv, "#lesson-composer-form"), %{
        "lesson" => %{
          "title" => "Aula de sacadas",
          "content" => "Revisamos a inversão.",
          "student_ids" => [ctx.link.id]
        }
      })

      assert [%{steps: [passo]}] = Study.list_lessons_for_link(ctx.link.id)
      assert passo.code == "IV"
    end

    test "abrir o composer de novo começa sem passo nenhum", ctx do
      vincular(ctx.lv, ctx.passo)
      render_click(ctx.lv, "close_lesson_composer", %{})
      html = render_click(ctx.lv, "open_lesson_composer", %{})

      refute html =~ "Inversão base"
    end

    test "id que não está na busca não derruba a página", ctx do
      assert render_click(ctx.lv, "add_lesson_step", %{
               "id" => "nao-e-uuid",
               "step-id" => "nao-e-uuid"
             })
    end
  end

  describe "editar a lição preserva e troca os passos" do
    setup ctx do
      {:ok, lesson, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          %{title: "Aula", content: "Texto", step_ids: [ctx.passo.id]},
          [ctx.link.id]
        )

      {:ok, lv, _html} = live(log_in_user(ctx.conn, ctx.teacher), ~p"/study")
      render_click(lv, "switch_study_tab", %{"tab" => "students"})

      ctx |> Map.put(:lv, lv) |> Map.put(:lesson, lesson)
    end

    test "abrir para editar carrega os passos que a lição já tinha", ctx do
      html = render_click(ctx.lv, "edit_lesson", %{"id" => ctx.lesson.id})

      assert html =~ "Inversão base"
    end

    test "trocar o passo e salvar vale para quem recebeu", ctx do
      render_click(ctx.lv, "edit_lesson", %{"id" => ctx.lesson.id})
      render_click(ctx.lv, "remove_lesson_step", %{"step-id" => ctx.passo.id})
      vincular(ctx.lv, ctx.outro)

      render_submit(element(ctx.lv, "#lesson-composer-form"), %{
        "lesson" => %{"title" => "Aula", "content" => "Texto"}
      })

      assert [%{steps: [passo]}] = Study.list_lessons_for_link(ctx.link.id)
      assert passo.code == "SCSP"
    end
  end

  describe "o aluno encontra o passo na lição que recebeu" do
    setup ctx do
      {:ok, _lesson, _} =
        Study.broadcast_lesson(
          ctx.teacher,
          %{title: "Aula de sacadas", content: "Revisamos.", step_ids: [ctx.passo.id]},
          [ctx.link.id]
        )

      aluno = ctx.link.student
      {:ok, lv, html} = live(log_in_user(ctx.conn, aluno), ~p"/study/shared/#{ctx.link.id}")

      ctx |> Map.put(:lv, lv) |> Map.put(:html, html) |> Map.put(:aluno, aluno)
    end

    test "o chip do passo aparece na lição", ctx do
      assert ctx.html =~ "Inversão base"
      assert ctx.html =~ "open_step_sheet"
    end

    test "clicar no chip abre a folha do passo", ctx do
      html = render_click(ctx.lv, "open_step_sheet", %{"code" => ctx.passo.code})

      assert html =~ "Já sei este passo"
    end

    test "marcar dali registra o aprendizado sem sair da lição", ctx do
      render_click(ctx.lv, "open_step_sheet", %{"code" => ctx.passo.code})
      html = render_click(ctx.lv, "toggle_step_learned", %{"code" => ctx.passo.code})

      assert Engagement.learned?(ctx.aluno.id, ctx.passo.id)
      assert html =~ "Aula de sacadas"
    end

    test "o chip da lição fica verde depois de marcar", ctx do
      render_click(ctx.lv, "open_step_sheet", %{"code" => ctx.passo.code})
      html = render_click(ctx.lv, "toggle_step_learned", %{"code" => ctx.passo.code})

      # Mesmo código de cor dos chips da nota: verde é "eu sei".
      assert html =~ "accent-green"
    end
  end
end
