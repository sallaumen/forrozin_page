defmodule OGrupoDeEstudosWeb.DiaryStepSheetTest do
  @moduledoc """
  O passo da nota de aula deixa de ser beco sem saída.

  Antes, o chip do passo vinculado a uma nota era um `<span>` morto: não era
  link, não tinha ação, e o único gesto possível era remover. A pessoa lia na
  própria anotação o passo que viu na aula e não conseguia fazer nada com ele
  dali.

  Agora o chip abre uma folha com o passo e o gesto de marcar. Folha, e não a
  página inteira, para a pessoa não perder de vista a anotação que estava
  lendo.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Engagement, Study}

  setup do
    aluna = insert(:user)
    passo = insert(:step, code: "IV", name: "Inversão base")

    {:ok, _nota} =
      Study.upsert_personal_note(aluna, Date.utc_today(), %{
        content: "Trabalhamos inversão hoje.",
        step_ids: [passo.id]
      })

    %{aluna: aluna, passo: passo}
  end

  describe "no diário pessoal" do
    test "o chip do passo é clicável, não um texto morto", ctx do
      {:ok, _lv, html} = live(log_in_user(build_conn(), ctx.aluna), ~p"/study")

      assert html =~ "open_step_sheet"
      assert html =~ ctx.passo.code
    end

    test "clicar abre a folha com o passo e o gesto de marcar", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.aluna), ~p"/study")

      html = render_click(lv, "open_step_sheet", %{"code" => ctx.passo.code})

      assert html =~ "Inversão base"
      assert html =~ "Já sei este passo"
    end

    test "marcar dali registra o aprendizado, sem sair da anotação", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.aluna), ~p"/study")

      render_click(lv, "open_step_sheet", %{"code" => ctx.passo.code})
      html = render_click(lv, "toggle_step_learned", %{"code" => ctx.passo.code})

      assert Engagement.learned?(ctx.aluna.id, ctx.passo.id)
      assert html =~ "Você já sabe"
      # A anotação continua na tela: a folha é uma camada, não uma viagem.
      assert html =~ "Trabalhamos inversão hoje."
    end

    test "a folha fecha", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.aluna), ~p"/study")

      render_click(lv, "open_step_sheet", %{"code" => ctx.passo.code})
      html = render_click(lv, "close_step_sheet", %{})

      refute html =~ "Já sei este passo"
    end

    test "a folha leva ao passo completo, para quem quer ver conexões e vídeos", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.aluna), ~p"/study")

      html = render_click(lv, "open_step_sheet", %{"code" => ctx.passo.code})

      assert html =~ ~s|href="/steps/#{ctx.passo.code}"|
    end

    test "código que não existe não derruba a página", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.aluna), ~p"/study")

      assert render_click(lv, "open_step_sheet", %{"code" => "NAO-EXISTE"})
    end
  end

  describe "no diário compartilhado com o professor" do
    setup ctx do
      link = insert(:teacher_student_link, student: ctx.aluna)

      {:ok, _} =
        Study.upsert_shared_note(link, Date.utc_today(), %{
          content: "Aula de hoje.",
          step_ids: [ctx.passo.id]
        })

      Map.put(ctx, :link, link)
    end

    test "o passo que o professor marcou também abre", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.aluna), ~p"/study/shared/#{ctx.link.id}")

      html = render_click(lv, "open_step_sheet", %{"code" => ctx.passo.code})

      assert html =~ "Já sei este passo"
    end

    test "e marcar dali funciona", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.aluna), ~p"/study/shared/#{ctx.link.id}")

      render_click(lv, "open_step_sheet", %{"code" => ctx.passo.code})
      render_click(lv, "toggle_step_learned", %{"code" => ctx.passo.code})

      assert Engagement.learned?(ctx.aluna.id, ctx.passo.id)
    end
  end
end
