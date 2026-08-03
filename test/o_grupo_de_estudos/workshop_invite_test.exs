defmodule OGrupoDeEstudos.WorkshopInviteTest do
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
      convidada: insert(:user)
    }
  end

  describe "invite/3" do
    test "quem administra convida, e a pessoa é avisada", ctx do
      Repo.delete_all(Notification)

      assert {:ok, _} = Workshops.invite(ctx.privado, ctx.dono, ctx.convidada.id)
      assert Workshops.invited?(ctx.privado.id, ctx.convidada.id)

      assert [aviso] = Repo.all(from n in Notification, where: n.user_id == ^ctx.convidada.id)
      assert aviso.action == :workshop_invited
    end

    test "co-organizador também convida", ctx do
      parceiro = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.privado, ctx.dono, parceiro.id)

      assert {:ok, _} = Workshops.invite(ctx.privado, parceiro, ctx.convidada.id)
    end

    test "estranho não convida", ctx do
      assert {:error, :unauthorized} =
               Workshops.invite(ctx.privado, insert(:user), ctx.convidada.id)
    end

    test "convidar duas vezes não duplica", ctx do
      {:ok, _} = Workshops.invite(ctx.privado, ctx.dono, ctx.convidada.id)

      assert {:error, :already_invited} =
               Workshops.invite(ctx.privado, ctx.dono, ctx.convidada.id)

      assert length(Workshops.list_invites(ctx.privado.id)) == 1
    end

    test "usuário que não existe devolve not_found", ctx do
      assert {:error, :not_found} =
               Workshops.invite(ctx.privado, ctx.dono, Ecto.UUID.generate())
    end

    test "revogar tira o acesso", ctx do
      {:ok, _} = Workshops.invite(ctx.privado, ctx.dono, ctx.convidada.id)

      assert {:ok, _} = Workshops.revoke_invite(ctx.privado, ctx.dono, ctx.convidada.id)
      refute Workshops.invited?(ctx.privado.id, ctx.convidada.id)
    end

    test "estranho não revoga", ctx do
      {:ok, _} = Workshops.invite(ctx.privado, ctx.dono, ctx.convidada.id)

      assert {:error, :unauthorized} =
               Workshops.revoke_invite(ctx.privado, insert(:user), ctx.convidada.id)
    end
  end

  describe "can_see_private?/2" do
    test "convidado vê", ctx do
      {:ok, _} = Workshops.invite(ctx.privado, ctx.dono, ctx.convidada.id)

      assert Workshops.can_see_private?(ctx.privado, ctx.convidada)
    end

    test "quem administra vê sem convite", ctx do
      assert Workshops.can_see_private?(ctx.privado, ctx.dono)
    end

    test "quem já se inscreveu continua vendo mesmo se o convite for revogado", ctx do
      {:ok, _} = Workshops.invite(ctx.privado, ctx.dono, ctx.convidada.id)
      {:ok, _} = Workshops.enroll(ctx.privado, ctx.convidada)
      {:ok, _} = Workshops.revoke_invite(ctx.privado, ctx.dono, ctx.convidada.id)

      # Tirar da lista de convidados nao pode expulsar quem ja entrou.
      assert Workshops.can_see_private?(ctx.privado, ctx.convidada)
    end

    test "estranho não vê", ctx do
      refute Workshops.can_see_private?(ctx.privado, insert(:user))
    end

    test "visitante sem conta não vê", ctx do
      refute Workshops.can_see_private?(ctx.privado, nil)
    end
  end

  describe "agenda pública" do
    test "workshop privado nunca aparece no feed", ctx do
      {:ok, _} = Workshops.invite(ctx.privado, ctx.dono, ctx.convidada.id)

      ids = [period: :upcoming] |> Workshops.list_agenda() |> Enum.map(& &1.id)

      refute ctx.privado.id in ids
      assert ctx.publico.id in ids
    end

    test "nem para quem foi convidado: o link é o caminho", ctx do
      {:ok, _} = Workshops.invite(ctx.privado, ctx.dono, ctx.convidada.id)

      ids = [period: :upcoming] |> Workshops.list_agenda() |> Enum.map(& &1.id)

      refute ctx.privado.id in ids
    end
  end

  describe "access_for/2 com visibilidade" do
    test "invited? só é verdade em workshop privado", ctx do
      {:ok, _} = Workshops.invite(ctx.privado, ctx.dono, ctx.convidada.id)

      assert Workshops.access_for(ctx.privado, ctx.convidada).invited?
      # Em workshop publico a pergunta nao se aplica, e nao custa consulta.
      refute Workshops.access_for(ctx.publico, ctx.convidada).invited?
    end
  end
end
