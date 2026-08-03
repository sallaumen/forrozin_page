defmodule OGrupoDeEstudos.WorkshopJoinRequestTest do
  @moduledoc """
  Workshop privado: visível para todo mundo, entrada por aprovação.

  A regra antiga escondia o workshop do mundo. A nova troca o eixo: ele
  aparece na agenda como qualquer outro, e o que muda é a porta. Quem quer
  entrar pede; quem organiza decide; aprovar já matricula.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Workshops

  setup do
    dono = insert(:user)

    %{
      dono: dono,
      privado: insert(:workshop, organizer: dono, visibility: :private),
      publico: insert(:workshop, organizer: dono),
      aluna: insert(:user)
    }
  end

  describe "a vitrine: quem vê o quê" do
    test "workshop privado APARECE na agenda", ctx do
      ids = [period: :upcoming] |> Workshops.list_agenda() |> Enum.map(& &1.id)

      assert ctx.privado.id in ids
      assert ctx.publico.id in ids
    end

    test "a página do privado abre para estranho, e para visitante sem conta", ctx do
      # Esconder faria o site parecer vazio. O que se protege é o interior,
      # não a existência.
      assert Workshops.can_see_page?(ctx.privado, insert(:user))
      assert Workshops.can_see_page?(ctx.privado, nil)
    end

    test "mas o interior fica fechado até a aprovação", ctx do
      refute Workshops.liberado?(ctx.privado, ctx.aluna)
      refute Workshops.liberado?(ctx.privado, nil)
    end

    test "workshop público tem o interior aberto para quem tem conta", ctx do
      assert Workshops.liberado?(ctx.publico, ctx.aluna)
    end

    test "quem administra vê o interior do próprio privado sem pedir nada", ctx do
      assert Workshops.liberado?(ctx.privado, ctx.dono)
    end
  end

  describe "pedir para entrar" do
    test "cria pedido pendente e avisa quem organiza", ctx do
      Repo.delete_all(Notification)

      assert {:ok, pedido} = Workshops.request_join(ctx.privado, ctx.aluna)
      assert pedido.status == :pending

      assert [aviso] = Repo.all(from n in Notification, where: n.user_id == ^ctx.dono.id)
      assert aviso.action == :workshop_join_requested
    end

    test "pedir não matricula: a vaga só existe depois do aceite", ctx do
      {:ok, _} = Workshops.request_join(ctx.privado, ctx.aluna)

      assert Workshops.count_enrollments(ctx.privado.id) == 0
      refute Workshops.liberado?(ctx.privado, ctx.aluna)
    end

    test "pedir duas vezes não duplica a fila", ctx do
      {:ok, _} = Workshops.request_join(ctx.privado, ctx.aluna)

      assert {:error, :already_requested} = Workshops.request_join(ctx.privado, ctx.aluna)
      assert length(Workshops.list_pending_requests(ctx.privado)) == 1
    end

    test "workshop público não tem fila: inscreve direto", ctx do
      assert {:error, :not_private} = Workshops.request_join(ctx.publico, ctx.aluna)
    end

    test "visitante sem conta não pede", ctx do
      assert {:error, :unauthorized} = Workshops.request_join(ctx.privado, nil)
    end
  end

  describe "aprovar" do
    setup ctx do
      {:ok, pedido} = Workshops.request_join(ctx.privado, ctx.aluna)
      Map.put(ctx, :pedido, pedido)
    end

    test "aprovar JÁ matricula, sem pedir uma segunda ação", ctx do
      assert {:ok, _} = Workshops.approve_join(ctx.privado, ctx.dono, ctx.pedido.id)

      assert Workshops.count_enrollments(ctx.privado.id) == 1
      assert Workshops.liberado?(ctx.privado, ctx.aluna)
    end

    test "quem pediu é avisado da resposta", ctx do
      Repo.delete_all(Notification)
      {:ok, _} = Workshops.approve_join(ctx.privado, ctx.dono, ctx.pedido.id)

      assert [aviso] = Repo.all(from n in Notification, where: n.user_id == ^ctx.aluna.id)
      assert aviso.action == :workshop_join_approved
    end

    test "sai da fila depois de respondido", ctx do
      {:ok, _} = Workshops.approve_join(ctx.privado, ctx.dono, ctx.pedido.id)

      assert Workshops.list_pending_requests(ctx.privado) == []
    end

    test "co-organizador também aprova", ctx do
      parceiro = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.privado, ctx.dono, parceiro.id)

      assert {:ok, _} = Workshops.approve_join(ctx.privado, parceiro, ctx.pedido.id)
    end

    test "estranho não aprova", ctx do
      assert {:error, :unauthorized} =
               Workshops.approve_join(ctx.privado, insert(:user), ctx.pedido.id)
    end

    test "turma lotada recusa o aceite em vez de estourar a vaga", ctx do
      {:ok, lotado} = Workshops.update_workshop(ctx.dono, ctx.privado, %{capacity: 1})
      {:ok, _} = Workshops.enroll(lotado, insert(:user))

      assert {:error, :full} = Workshops.approve_join(lotado, ctx.dono, ctx.pedido.id)
      # A fila continua de pé: quem organiza pode abrir vaga e aprovar depois.
      assert length(Workshops.list_pending_requests(lotado)) == 1
    end
  end

  describe "recusar" do
    setup ctx do
      {:ok, pedido} = Workshops.request_join(ctx.privado, ctx.aluna)
      Map.put(ctx, :pedido, pedido)
    end

    test "recusar tira da fila e não matricula", ctx do
      assert {:ok, _} = Workshops.reject_join(ctx.privado, ctx.dono, ctx.pedido.id)

      assert Workshops.list_pending_requests(ctx.privado) == []
      assert Workshops.count_enrollments(ctx.privado.id) == 0
      refute Workshops.liberado?(ctx.privado, ctx.aluna)
    end

    test "dá para pedir de novo depois de uma recusa", ctx do
      {:ok, _} = Workshops.reject_join(ctx.privado, ctx.dono, ctx.pedido.id)

      assert {:ok, novo} = Workshops.request_join(ctx.privado, ctx.aluna)
      assert novo.status == :pending
    end

    test "estranho não recusa", ctx do
      assert {:error, :unauthorized} =
               Workshops.reject_join(ctx.privado, insert(:user), ctx.pedido.id)
    end
  end

  describe "estado do pedido para a tela" do
    test "conta em que pé está, para a página escolher o que mostrar", ctx do
      assert Workshops.join_status(ctx.privado, ctx.aluna) == :none

      {:ok, pedido} = Workshops.request_join(ctx.privado, ctx.aluna)
      assert Workshops.join_status(ctx.privado, ctx.aluna) == :pending

      {:ok, _} = Workshops.approve_join(ctx.privado, ctx.dono, pedido.id)
      assert Workshops.join_status(ctx.privado, ctx.aluna) == :approved
    end

    test "visitante sem conta não tem pedido nenhum", ctx do
      assert Workshops.join_status(ctx.privado, nil) == :none
    end
  end
end
