defmodule OGrupoDeEstudos.WorkshopAdminsTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  defp published(organizer) do
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
    %{criador: criador, workshop: published(criador), partner: insert(:user)}
  end

  describe "add_admin/3" do
    test "creator promotes someone to co-organizer", ctx do
      assert {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.partner.id)

      assert Workshops.admin?(ctx.workshop, ctx.partner)
      assert ctx.partner.id in Workshops.admin_ids(ctx.workshop)
    end

    test "creator counts as admin without a row in the table", ctx do
      assert Workshops.admin?(ctx.workshop, ctx.criador)
      assert ctx.criador.id in Workshops.admin_ids(ctx.workshop)
    end

    test "co-organizer does not promote anyone else", ctx do
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.partner.id)

      assert {:error, :unauthorized} =
               Workshops.add_admin(ctx.workshop, ctx.partner, insert(:user).id)
    end

    test "outsider does not promote anyone", ctx do
      assert {:error, :unauthorized} =
               Workshops.add_admin(ctx.workshop, insert(:user), insert(:user).id)
    end

    test "promoting twice does not duplicate", ctx do
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.partner.id)

      assert {:error, :already_admin} =
               Workshops.add_admin(ctx.workshop, ctx.criador, ctx.partner.id)

      assert length(Workshops.admin_ids(ctx.workshop)) == 2
    end

    test "creator does not promote themselves", ctx do
      assert {:error, :already_admin} =
               Workshops.add_admin(ctx.workshop, ctx.criador, ctx.criador.id)
    end
  end

  describe "remove_admin/3" do
    setup ctx do
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.partner.id)
      ctx
    end

    test "creator removes a co-organizer", ctx do
      assert {:ok, _} = Workshops.remove_admin(ctx.workshop, ctx.criador, ctx.partner.id)
      refute Workshops.admin?(ctx.workshop, ctx.partner)
    end

    test "co-organizer removes themselves", ctx do
      assert {:ok, _} = Workshops.remove_admin(ctx.workshop, ctx.partner, ctx.partner.id)
      refute Workshops.admin?(ctx.workshop, ctx.partner)
    end

    test "co-organizer does not remove another co-organizer", ctx do
      other = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, other.id)

      assert {:error, :unauthorized} =
               Workshops.remove_admin(ctx.workshop, ctx.partner, other.id)
    end

    test "creator cannot be removed", ctx do
      assert {:error, :cannot_remove_owner} =
               Workshops.remove_admin(ctx.workshop, ctx.criador, ctx.criador.id)
    end
  end

  describe "what a co-organizer can do" do
    setup ctx do
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.partner.id)
      ctx
    end

    test "edits the workshop", ctx do
      assert {:ok, updated} =
               Workshops.update_workshop(ctx.partner, ctx.workshop, %{title: "Novo título"})

      assert updated.title == "Novo título"
    end

    test "sees the enrollment list and the payment control", ctx do
      student = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, student)

      assert {:ok, [enrollment]} =
               Workshops.list_enrollments_for_organizer(ctx.workshop, ctx.partner)

      assert {:ok, %{total: 1, paid: 0}} = Workshops.payment_summary(ctx.workshop, ctx.partner)

      assert {:ok, _} =
               Workshops.set_payment_status(ctx.workshop, ctx.partner, enrollment.id, :paid)

      assert {:ok, %{paid: 1}} = Workshops.payment_summary(ctx.workshop, ctx.criador)
    end

    test "cancels the workshop", ctx do
      assert {:ok, %{status: :cancelled}} =
               Workshops.cancel_workshop(ctx.partner, ctx.workshop)
    end

    test "does not delete the workshop: only the creator does", ctx do
      {:ok, draft} =
        Workshops.create_workshop(ctx.criador, %{
          title: "Rascunho vazio",
          description: "Nada aqui.",
          starts_at: DateTime.add(DateTime.utc_now(), 5, :day) |> DateTime.truncate(:second)
        })

      {:ok, _} = Workshops.add_admin(draft, ctx.criador, ctx.partner.id)

      assert {:error, :unauthorized} = Workshops.delete_workshop(ctx.partner, draft)
      assert {:ok, _} = Workshops.delete_workshop(ctx.criador, draft)
    end

    test "does not enroll in their own workshop", ctx do
      assert {:error, :organizer} = Workshops.enroll(ctx.workshop, ctx.partner)
    end

    test "sees the workshop in their own agenda", ctx do
      ids = ctx.partner.id |> Workshops.list_for_organizer() |> Enum.map(& &1.id)

      assert ctx.workshop.id in ids
    end
  end

  describe "access_for/2" do
    test "resolves admin and enrolled flags in a single pass", ctx do
      student = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, student)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.partner.id)

      criador = Workshops.access_for(ctx.workshop, ctx.criador)
      assert criador.admin?
      refute criador.enrolled?

      partner = Workshops.access_for(ctx.workshop, ctx.partner)
      assert partner.admin?

      inscrita = Workshops.access_for(ctx.workshop, student)
      refute inscrita.admin?
      assert inscrita.enrolled?

      outsider = Workshops.access_for(ctx.workshop, insert(:user))
      refute outsider.admin?
      refute outsider.enrolled?

      anonimo = Workshops.access_for(ctx.workshop, nil)
      refute anonimo.admin?
      refute anonimo.enrolled?
    end
  end

  describe "enrollment notification with two administrators" do
    test "every administrator receives it", ctx do
      alias OGrupoDeEstudos.Engagement.Notifications.Notification

      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.partner.id)
      {:ok, _} = Workshops.enroll(ctx.workshop, insert(:user))

      destinatarios =
        Notification
        |> Repo.all()
        |> Enum.filter(&(&1.action == :workshop_enrolled))
        |> Enum.map(& &1.user_id)
        |> MapSet.new()

      assert destinatarios == MapSet.new([ctx.criador.id, ctx.partner.id])
    end
  end
end
