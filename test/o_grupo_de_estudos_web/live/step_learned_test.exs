defmodule OGrupoDeEstudosWeb.StepLearnedTest do
  @moduledoc """
  Marcar "já sei este passo" onde a pessoa está.

  O botão existia num lugar só do app: dentro do mapa, no grafo. Quem via um
  passo na aula tinha que sair da aula, abrir o mapa, achar o nó e marcar lá.
  Um aluno reclamou disso por escrito, e ele tinha razão.

  Agora o gesto mora no `step_detail`, que é o mesmo componente da página do
  passo e do drawer do acervo: um lugar só, três telas resolvidas.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Engagement

  setup do
    %{step: insert(:step, code: "IV", name: "Inversão base"), user: insert(:user)}
  end

  describe "na página do passo" do
    test "oferece o gesto de marcar", ctx do
      {:ok, _lv, html} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      assert html =~ "Já sei este passo"
    end

    test "marcar registra o aprendizado", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      html = render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})

      assert Engagement.learned?(ctx.user.id, ctx.step.id)
      assert html =~ "Você já sabe"
    end

    test "clicar de novo desmarca: é um gesto reversível", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})
      render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})

      refute Engagement.learned?(ctx.user.id, ctx.step.id)
    end

    test "quem já sabe vê o estado ao abrir, sem precisar clicar", ctx do
      {:ok, :learned} = Engagement.toggle_learned(ctx.user.id, ctx.step.id)

      {:ok, _lv, html} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      assert html =~ "Você já sabe"
    end
  end

  describe "no acervo, pelo drawer" do
    test "o mesmo gesto, no mesmo componente", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.user), ~p"/collection")

      html = render_click(lv, "open_step", %{"code" => ctx.step.code})
      assert html =~ "Já sei este passo"

      render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})
      assert Engagement.learned?(ctx.user.id, ctx.step.id)
    end
  end

  describe "o efeito colateral que precisa aparecer na tela" do
    test "marcar como aprendido também favorita, e o botão de favorito acompanha", ctx do
      # `toggle_learned` roda um Multi que garante o favorito junto. Se a tela
      # não refletisse isso, a estrela acenderia sozinha no próximo reload e
      # ninguém entenderia por quê.
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      html = render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})

      assert Engagement.favorited?(ctx.user.id, "step", ctx.step.id)
      assert html =~ "Favoritado"
    end

    test "desmarcar aprendido NÃO desfavorita", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})
      render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})

      # Favoritar é escolha de quem favoritou: desfazer o aprendizado não pode
      # apagar uma decisão que a pessoa tomou por outro motivo.
      assert Engagement.favorited?(ctx.user.id, "step", ctx.step.id)
    end
  end

  describe "código que não existe" do
    test "não derruba a página", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      assert render_click(lv, "toggle_step_learned", %{"code" => "NAO-EXISTE"})
    end
  end
end
