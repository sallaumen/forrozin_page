defmodule OGrupoDeEstudosWeb.StepPillStateTest do
  @moduledoc """
  O chip do passo diz, pela cor, se a pessoa já sabe aquilo.

  Antes todo chip era âmbar, independente do estado: olhar a anotação de uma
  aula não contava nada sobre o próprio aprendizado, e para saber era preciso
  abrir passo por passo.

  Verde claro para o que já se sabe, âmbar para o que ainda não. A folha que
  abre a partir do chip usa a mesma cor: ela é o chip aberto, e trocar de cor
  no meio do caminho quebraria a ligação entre o que se clicou e o que abriu.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Engagement, Study, Workshops}

  setup do
    aluna = insert(:user)
    sabido = insert(:step, code: "IV", name: "Inversão base")
    novo = insert(:step, code: "SC", name: "Sacada simples")

    {:ok, :learned} = Engagement.toggle_learned(aluna.id, sabido.id)

    %{aluna: aluna, sabido: sabido, novo: novo}
  end

  describe "no diário" do
    setup ctx do
      {:ok, _} =
        Study.upsert_personal_note(ctx.aluna, Date.utc_today(), %{
          content: "Aula de hoje.",
          step_ids: [ctx.sabido.id, ctx.novo.id]
        })

      ctx
    end

    test "o passo que ela já sabe vem verde", ctx do
      {:ok, _lv, html} = live(log_in_user(build_conn(), ctx.aluna), ~p"/study")

      assert chip_de(html, "IV") =~ "accent-green"
    end

    test "o passo que ela ainda não sabe fica âmbar", ctx do
      {:ok, _lv, html} = live(log_in_user(build_conn(), ctx.aluna), ~p"/study")

      assert chip_de(html, "SC") =~ "accent-orange"
      refute chip_de(html, "SC") =~ "accent-green"
    end

    test "marcar pela folha vira o chip de cor na hora", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.aluna), ~p"/study")

      render_click(lv, "open_step_sheet", %{"code" => "SC"})
      html = render_click(lv, "toggle_step_learned", %{"code" => "SC"})

      # Sem isso a pessoa marcaria, fecharia a folha e veria o chip antigo,
      # sem saber se funcionou.
      assert chip_de(html, "SC") =~ "accent-green"
    end
  end

  describe "na página do workshop" do
    test "os passos da aula também mudam de cor", ctx do
      dono = insert(:user)
      workshop = insert(:workshop, organizer: dono)
      {:ok, _} = Workshops.enroll(workshop, ctx.aluna)
      {:ok, _} = Workshops.add_step(workshop, dono, ctx.sabido.id)
      {:ok, _} = Workshops.add_step(workshop, dono, ctx.novo.id)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.aluna), ~p"/workshops/#{workshop.slug}")

      assert chip_de(html, "IV") =~ "accent-green"
      assert chip_de(html, "SC") =~ "accent-orange"
    end
  end

  describe "a folha é o chip aberto" do
    test "abrir um passo já sabido traz a folha verde", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.aluna), ~p"/study")

      html = render_click(lv, "open_step_sheet", %{"code" => "IV"})

      assert html =~ "Você já sabe este passo"
      assert folha(html) =~ "accent-green"
    end

    test "abrir um passo novo traz a folha âmbar", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.aluna), ~p"/study")

      html = render_click(lv, "open_step_sheet", %{"code" => "SC"})

      assert html =~ "Já sei este passo"
      assert folha(html) =~ "accent-orange"
    end
  end

  # A cor mora no elemento que embrulha o chip, e entre ele e o código há um
  # ícone: casar isso com regex de aninhamento é frágil. Pegar a janela de
  # HTML logo ANTES do código é estável e diz a mesma coisa.
  defp chip_de(html, code) do
    case :binary.match(html, ">#{code}</code>") do
      {inicio, _} -> binary_part(html, max(inicio - 400, 0), min(400, inicio))
      :nomatch -> flunk("não achei o chip de #{code}")
    end
  end

  defp folha(html) do
    case Regex.run(~r/id="step-sheet".{0,3000}/s, html) do
      [trecho] -> trecho
      nil -> flunk("folha não está aberta")
    end
  end
end
