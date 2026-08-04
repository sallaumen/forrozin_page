defmodule OGrupoDeEstudosWeb.CollectionSeenIconTest do
  @moduledoc """
  O acervo lembra onde a pessoa esteve.

  O card do passo já dizia se tem vídeo e se veio da comunidade, mas nada
  dizia se aquele passo passou pela aula dela. Agora diz — e diz separado de
  "aprendido": aprendido é decisão da pessoa, visto em aula é o que aconteceu.
  Um passo pode ser visto sem ser aprendido, e é justamente esse o passo que
  ela precisa reencontrar.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Engagement, Workshops}

  @visto "Você viu este passo em aula"
  @aprendido "Você já sabe este passo"

  setup %{conn: conn} do
    section = insert(:section, code: "TEST", title: "Bases")
    passo = insert(:step, section: section, code: "IV", name: "Inversão base")
    aluna = insert(:user)

    %{conn: log_in_user(conn, aluna), aluna: aluna, section: section, passo: passo}
  end

  defp abrir_secao(ctx) do
    {:ok, lv, _html} = live(ctx.conn, ~p"/collection")
    render_click(lv, "enter_section", %{"section_id" => ctx.section.id})
  end

  defp dar_workshop_para(aluna, passo) do
    dono = insert(:user)
    workshop = insert(:workshop, organizer: dono)
    {:ok, _} = Workshops.enroll(workshop, aluna)
    {:ok, _} = Workshops.add_step(workshop, dono, passo.id)
  end

  describe "ícone de passo visto em aula" do
    test "não aparece em passo que a pessoa nunca viu", ctx do
      refute abrir_secao(ctx) =~ @visto
    end

    test "aparece depois de um workshop que a pessoa fez", ctx do
      dar_workshop_para(ctx.aluna, ctx.passo)

      assert abrir_secao(ctx) =~ @visto
    end

    test "aparece por passo anotado no diário", ctx do
      {:ok, _} =
        OGrupoDeEstudos.Study.upsert_personal_note(ctx.aluna, Date.utc_today(), %{
          content: "Treinei inversão.",
          step_ids: [ctx.passo.id]
        })

      assert abrir_secao(ctx) =~ @visto
    end

    test "workshop de outra pessoa não acende o ícone", ctx do
      dono = insert(:user)
      workshop = insert(:workshop, organizer: dono)
      {:ok, _} = Workshops.add_step(workshop, dono, ctx.passo.id)

      refute abrir_secao(ctx) =~ @visto
    end
  end

  describe "visto e aprendido são coisas diferentes" do
    test "visto em aula não marca como aprendido", ctx do
      dar_workshop_para(ctx.aluna, ctx.passo)
      html = abrir_secao(ctx)

      assert html =~ @visto
      refute html =~ @aprendido
      refute Engagement.learned?(ctx.aluna.id, ctx.passo.id)
    end

    test "aprendido sem ter visto em aula mostra só o ícone de aprendido", ctx do
      Engagement.toggle_learned(ctx.aluna.id, ctx.passo.id)
      html = abrir_secao(ctx)

      assert html =~ @aprendido
      refute html =~ @visto
    end

    test "os dois convivem no mesmo card", ctx do
      dar_workshop_para(ctx.aluna, ctx.passo)
      Engagement.toggle_learned(ctx.aluna.id, ctx.passo.id)
      html = abrir_secao(ctx)

      assert html =~ @visto
      assert html =~ @aprendido
    end
  end

  describe "na busca do acervo" do
    test "o resultado da busca também mostra o histórico", ctx do
      dar_workshop_para(ctx.aluna, ctx.passo)

      {:ok, lv, _} = live(ctx.conn, ~p"/collection")
      html = render_change(lv, "search", %{"term" => "Inversão"})

      assert html =~ @visto
    end
  end
end
