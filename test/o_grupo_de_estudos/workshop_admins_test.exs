defmodule OGrupoDeEstudos.WorkshopAdminsTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  defp publicado(organizer) do
    {:ok, w} =
      Workshops.create_workshop(organizer, %{
        title: "Workshop com dois professores",
        description: "Dividido entre dois.",
        starts_at: DateTime.add(DateTime.utc_now(), 10, :day) |> DateTime.truncate(:second),
        price_cents: 10_000
      })

    {:ok, w} = Workshops.publish_workshop(organizer, w)
    w
  end

  setup do
    criador = insert(:user)
    %{criador: criador, workshop: publicado(criador), parceiro: insert(:user)}
  end

  describe "add_admin/3" do
    test "criador promove alguém a co-organizador", ctx do
      assert {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.parceiro.id)

      assert Workshops.admin?(ctx.workshop, ctx.parceiro)
      assert ctx.parceiro.id in Workshops.admin_ids(ctx.workshop)
    end

    test "o criador conta como admin sem precisar de linha na tabela", ctx do
      assert Workshops.admin?(ctx.workshop, ctx.criador)
      assert ctx.criador.id in Workshops.admin_ids(ctx.workshop)
    end

    test "co-organizador não promove outra pessoa", ctx do
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.parceiro.id)

      # Quem entrou por convite não pode abrir a porta para mais gente: só o
      # criador decide quem vê o controle de pagamento.
      assert {:error, :unauthorized} =
               Workshops.add_admin(ctx.workshop, ctx.parceiro, insert(:user).id)
    end

    test "estranho não promove ninguém", ctx do
      assert {:error, :unauthorized} =
               Workshops.add_admin(ctx.workshop, insert(:user), insert(:user).id)
    end

    test "promover duas vezes não duplica", ctx do
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.parceiro.id)

      assert {:error, :already_admin} =
               Workshops.add_admin(ctx.workshop, ctx.criador, ctx.parceiro.id)

      assert length(Workshops.admin_ids(ctx.workshop)) == 2
    end

    test "criador não se promove", ctx do
      assert {:error, :already_admin} =
               Workshops.add_admin(ctx.workshop, ctx.criador, ctx.criador.id)
    end
  end

  describe "remove_admin/3" do
    setup ctx do
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.parceiro.id)
      ctx
    end

    test "criador remove co-organizador", ctx do
      assert {:ok, _} = Workshops.remove_admin(ctx.workshop, ctx.criador, ctx.parceiro.id)
      refute Workshops.admin?(ctx.workshop, ctx.parceiro)
    end

    test "co-organizador sai sozinho", ctx do
      assert {:ok, _} = Workshops.remove_admin(ctx.workshop, ctx.parceiro, ctx.parceiro.id)
      refute Workshops.admin?(ctx.workshop, ctx.parceiro)
    end

    test "co-organizador não remove outro", ctx do
      outro = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, outro.id)

      assert {:error, :unauthorized} =
               Workshops.remove_admin(ctx.workshop, ctx.parceiro, outro.id)
    end

    test "o criador não pode ser removido", ctx do
      assert {:error, :cannot_remove_owner} =
               Workshops.remove_admin(ctx.workshop, ctx.criador, ctx.criador.id)
    end
  end

  describe "o que o co-organizador pode fazer" do
    setup ctx do
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.parceiro.id)
      ctx
    end

    test "edita o workshop", ctx do
      assert {:ok, atualizado} =
               Workshops.update_workshop(ctx.parceiro, ctx.workshop, %{title: "Novo título"})

      assert atualizado.title == "Novo título"
    end

    test "vê a lista de inscritos e o controle de pagamento", ctx do
      aluna = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, aluna)

      assert {:ok, [inscricao]} =
               Workshops.list_enrollments_for_organizer(ctx.workshop, ctx.parceiro)

      assert {:ok, %{total: 1, paid: 0}} = Workshops.payment_summary(ctx.workshop, ctx.parceiro)

      assert {:ok, _} =
               Workshops.set_payment_status(ctx.workshop, ctx.parceiro, inscricao.id, :paid)

      assert {:ok, %{paid: 1}} = Workshops.payment_summary(ctx.workshop, ctx.criador)
    end

    test "cancela o workshop", ctx do
      assert {:ok, %{status: :cancelled}} =
               Workshops.cancel_workshop(ctx.parceiro, ctx.workshop)
    end

    test "NÃO apaga o workshop: isso é só do criador", ctx do
      # Para o co-organizador a barreira é a permissão, não o estado: mesmo
      # num rascunho vazio, que o criador apagaria, ele não passa.
      {:ok, rascunho} =
        Workshops.create_workshop(ctx.criador, %{
          title: "Rascunho vazio",
          description: "Nada aqui.",
          starts_at: DateTime.add(DateTime.utc_now(), 5, :day) |> DateTime.truncate(:second)
        })

      {:ok, _} = Workshops.add_admin(rascunho, ctx.criador, ctx.parceiro.id)

      assert {:error, :unauthorized} = Workshops.delete_workshop(ctx.parceiro, rascunho)
      assert {:ok, _} = Workshops.delete_workshop(ctx.criador, rascunho)
    end

    test "não se inscreve no próprio workshop", ctx do
      assert {:error, :organizer} = Workshops.enroll(ctx.workshop, ctx.parceiro)
    end

    test "o workshop aparece na agenda dele", ctx do
      ids = ctx.parceiro.id |> Workshops.list_for_organizer() |> Enum.map(& &1.id)

      assert ctx.workshop.id in ids
    end
  end

  describe "access_for/2" do
    test "resolve admin e inscrito numa passada só", ctx do
      aluna = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, aluna)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.parceiro.id)

      criador = Workshops.access_for(ctx.workshop, ctx.criador)
      assert criador.admin?
      refute criador.enrolled?

      parceiro = Workshops.access_for(ctx.workshop, ctx.parceiro)
      assert parceiro.admin?

      inscrita = Workshops.access_for(ctx.workshop, aluna)
      refute inscrita.admin?
      assert inscrita.enrolled?

      estranho = Workshops.access_for(ctx.workshop, insert(:user))
      refute estranho.admin?
      refute estranho.enrolled?

      anonimo = Workshops.access_for(ctx.workshop, nil)
      refute anonimo.admin?
      refute anonimo.enrolled?
    end
  end

  describe "notificação de inscrição com dois administradores" do
    test "todos os administradores recebem", ctx do
      alias OGrupoDeEstudos.Engagement.Notifications.Notification

      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.parceiro.id)
      {:ok, _} = Workshops.enroll(ctx.workshop, insert(:user))

      destinatarios =
        Notification
        |> Repo.all()
        |> Enum.filter(&(&1.action == :workshop_enrolled))
        |> Enum.map(& &1.user_id)
        |> MapSet.new()

      assert destinatarios == MapSet.new([ctx.criador.id, ctx.parceiro.id])
    end
  end
end
