defmodule OGrupoDeEstudos.WorkshopJoinRequestTest do
  @moduledoc """
  A private workshop is visible to everyone and entry goes through approval:
  the visitor asks, the organizer decides, and approving already enrolls.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Workshops

  setup do
    owner = insert(:user)

    %{
      owner: owner,
      private_workshop: insert(:workshop, organizer: owner, visibility: :private),
      public_workshop: insert(:workshop, organizer: owner),
      student: insert(:user)
    }
  end

  describe "what each visitor sees of a private workshop" do
    test "workshop privado APARECE na agenda", ctx do
      ids = [period: :upcoming] |> Workshops.list_agenda() |> Enum.map(& &1.id)

      assert ctx.private_workshop.id in ids
      assert ctx.public_workshop.id in ids
    end

    test "page of a private workshop opens for outsiders and for anonymous visitors", ctx do
      assert Workshops.can_see_page?(ctx.private_workshop, insert(:user))
      assert Workshops.can_see_page?(ctx.private_workshop, nil)
    end

    test "inside stays closed until approval", ctx do
      refute Workshops.liberado?(ctx.private_workshop, ctx.student)
      refute Workshops.liberado?(ctx.private_workshop, nil)
    end

    test "public workshop is open inside for anyone with an account", ctx do
      assert Workshops.liberado?(ctx.public_workshop, ctx.student)
    end

    test "admin sees the inside of their own private workshop without asking", ctx do
      assert Workshops.liberado?(ctx.private_workshop, ctx.owner)
    end
  end

  describe "asking to join" do
    test "creates a pending request and notifies the organizer", ctx do
      Repo.delete_all(Notification)

      assert {:ok, request} = Workshops.request_join(ctx.private_workshop, ctx.student)
      assert request.status == :pending

      assert [aviso] = Repo.all(from n in Notification, where: n.user_id == ^ctx.owner.id)
      assert aviso.action == :workshop_join_requested
    end

    test "asking does not enroll: the seat only exists after approval", ctx do
      {:ok, _} = Workshops.request_join(ctx.private_workshop, ctx.student)

      assert Workshops.count_enrollments(ctx.private_workshop.id) == 0
      refute Workshops.liberado?(ctx.private_workshop, ctx.student)
    end

    test "asking twice does not duplicate the queue", ctx do
      {:ok, _} = Workshops.request_join(ctx.private_workshop, ctx.student)

      assert {:error, :already_requested} =
               Workshops.request_join(ctx.private_workshop, ctx.student)

      assert length(Workshops.list_pending_requests(ctx.private_workshop)) == 1
    end

    test "public workshop has no queue and enrolls right away", ctx do
      assert {:error, :not_private} = Workshops.request_join(ctx.public_workshop, ctx.student)
    end

    test "anonymous visitor does not ask to join", ctx do
      assert {:error, :unauthorized} = Workshops.request_join(ctx.private_workshop, nil)
    end
  end

  describe "aprovar" do
    setup ctx do
      {:ok, request} = Workshops.request_join(ctx.private_workshop, ctx.student)
      Map.put(ctx, :request, request)
    end

    test "approving already enrolls, with no second action", ctx do
      assert {:ok, _} = Workshops.approve_join(ctx.private_workshop, ctx.owner, ctx.request.id)

      assert Workshops.count_enrollments(ctx.private_workshop.id) == 1
      assert Workshops.liberado?(ctx.private_workshop, ctx.student)
    end

    test "requester is notified of the answer", ctx do
      Repo.delete_all(Notification)
      {:ok, _} = Workshops.approve_join(ctx.private_workshop, ctx.owner, ctx.request.id)

      assert [aviso] = Repo.all(from n in Notification, where: n.user_id == ^ctx.student.id)
      assert aviso.action == :workshop_join_approved
    end

    test "leaves the queue once answered", ctx do
      {:ok, _} = Workshops.approve_join(ctx.private_workshop, ctx.owner, ctx.request.id)

      assert Workshops.list_pending_requests(ctx.private_workshop) == []
    end

    test "co-organizer also approves", ctx do
      partner = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.private_workshop, ctx.owner, partner.id)

      assert {:ok, _} = Workshops.approve_join(ctx.private_workshop, partner, ctx.request.id)
    end

    test "outsider does not approve", ctx do
      assert {:error, :unauthorized} =
               Workshops.approve_join(ctx.private_workshop, insert(:user), ctx.request.id)
    end

    test "full class does not block approval: fitting one more is the teacher's call", ctx do
      {:ok, full_workshop} =
        Workshops.update_workshop(ctx.owner, ctx.private_workshop, %{capacity: 1})

      {:ok, _} = Workshops.enroll(full_workshop, insert(:user))

      assert Workshops.passaria_do_limite?(full_workshop)
      assert {:ok, _} = Workshops.approve_join(full_workshop, ctx.owner, ctx.request.id)
      assert Workshops.count_enrollments(full_workshop.id) == 2
    end
  end

  describe "recusar" do
    setup ctx do
      {:ok, request} = Workshops.request_join(ctx.private_workshop, ctx.student)
      Map.put(ctx, :request, request)
    end

    test "rejecting removes from the queue and does not enroll", ctx do
      assert {:ok, _} = Workshops.reject_join(ctx.private_workshop, ctx.owner, ctx.request.id)

      assert Workshops.list_pending_requests(ctx.private_workshop) == []
      assert Workshops.count_enrollments(ctx.private_workshop.id) == 0
      refute Workshops.liberado?(ctx.private_workshop, ctx.student)
    end

    test "asking again is allowed after a rejection", ctx do
      {:ok, _} = Workshops.reject_join(ctx.private_workshop, ctx.owner, ctx.request.id)

      assert {:ok, new_request} = Workshops.request_join(ctx.private_workshop, ctx.student)
      assert new_request.status == :pending
    end

    test "outsider does not reject", ctx do
      assert {:error, :unauthorized} =
               Workshops.reject_join(ctx.private_workshop, insert(:user), ctx.request.id)
    end
  end

  describe "request state for the page" do
    test "reports where the request stands so the page picks what to show", ctx do
      assert Workshops.join_status(ctx.private_workshop, ctx.student) == :none

      {:ok, request} = Workshops.request_join(ctx.private_workshop, ctx.student)
      assert Workshops.join_status(ctx.private_workshop, ctx.student) == :pending

      {:ok, _} = Workshops.approve_join(ctx.private_workshop, ctx.owner, request.id)
      assert Workshops.join_status(ctx.private_workshop, ctx.student) == :approved
    end

    test "anonymous visitor has no request at all", ctx do
      assert Workshops.join_status(ctx.private_workshop, nil) == :none
    end
  end
end
