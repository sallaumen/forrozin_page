defmodule OGrupoDeEstudos.WorkshopWaitlistTest do
  @moduledoc """
  Where enrollment is automatic the capacity holds and forms a waitlist; where
  a human approves each entry, capacity can be exceeded. A full class with no
  waitlist would hide the demand that justifies opening another class.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Workshops

  defp lotar(workshop, quantos \\ 1) do
    for _ <- 1..quantos, do: {:ok, _} = Workshops.enroll(workshop, insert(:user))
    workshop
  end

  setup do
    owner = insert(:user)

    %{
      owner: owner,
      free_class: insert(:workshop, organizer: owner, capacity: 1, price_cents: 0),
      paid_class: insert(:workshop, organizer: owner, capacity: 1, price_cents: 18_000),
      private_workshop: insert(:workshop, organizer: owner, capacity: 1, visibility: :private),
      student: insert(:user)
    }
  end

  describe "class without approval: the capacity holds" do
    test "full free class does not accept direct enrollment", ctx do
      lotar(ctx.free_class)

      assert {:error, :full} = Workshops.enroll(ctx.free_class, ctx.student)
    end

    test "full paid class does not either: nobody pays for a seat that does not exist", ctx do
      lotar(ctx.paid_class)

      assert {:error, :full} = Workshops.enroll(ctx.paid_class, ctx.student)
    end

    test "without a capacity, everyone gets in", ctx do
      sem_limite = insert(:workshop, organizer: ctx.owner, capacity: nil)
      lotar(sem_limite, 5)

      assert {:ok, _} = Workshops.enroll(sem_limite, ctx.student)
    end
  end

  describe "class with teacher approval: capacity can be exceeded" do
    test "approving exceeds the capacity instead of rejecting", ctx do
      lotar(ctx.private_workshop)
      {:ok, _} = Workshops.request_join(ctx.private_workshop, ctx.student)
      [request] = Workshops.list_pending_requests(ctx.private_workshop)

      assert {:ok, _} = Workshops.approve_join(ctx.private_workshop, ctx.owner, request.id)
      assert Workshops.count_enrollments(ctx.private_workshop.id) == 2
    end

    test "warns the organizer that approving exceeds the capacity", ctx do
      lotar(ctx.private_workshop)

      assert Workshops.passaria_do_limite?(ctx.private_workshop)
    end

    test "no warning while seats are left", ctx do
      refute Workshops.passaria_do_limite?(ctx.private_workshop)
    end
  end

  describe "joining the waitlist" do
    test "whoever arrives past the capacity joins the waitlist", ctx do
      lotar(ctx.free_class)

      assert {:ok, _} = Workshops.join_waitlist(ctx.free_class, ctx.student)
      assert Workshops.waitlist_position(ctx.free_class, ctx.student) == 1
      assert Workshops.waitlist_count(ctx.free_class.id) == 1
    end

    test "waitlist keeps arrival order", ctx do
      lotar(ctx.free_class)
      first = insert(:user)
      {:ok, _} = Workshops.join_waitlist(ctx.free_class, first)
      {:ok, _} = Workshops.join_waitlist(ctx.free_class, ctx.student)

      assert Workshops.waitlist_position(ctx.free_class, first) == 1
      assert Workshops.waitlist_position(ctx.free_class, ctx.student) == 2
    end

    test "enrolls instead of waiting while seats are left", ctx do
      assert {:error, :has_room} = Workshops.join_waitlist(ctx.free_class, ctx.student)
    end

    test "already enrolled user does not join the waitlist", ctx do
      {:ok, _} = Workshops.enroll(ctx.free_class, ctx.student)

      assert {:error, :already_enrolled} = Workshops.join_waitlist(ctx.free_class, ctx.student)
    end

    test "joining twice does not duplicate the position", ctx do
      lotar(ctx.free_class)
      {:ok, _} = Workshops.join_waitlist(ctx.free_class, ctx.student)

      assert {:error, :already_waiting} = Workshops.join_waitlist(ctx.free_class, ctx.student)
      assert Workshops.waitlist_count(ctx.free_class.id) == 1
    end

    test "user leaves the waitlist", ctx do
      lotar(ctx.free_class)
      {:ok, _} = Workshops.join_waitlist(ctx.free_class, ctx.student)

      assert {:ok, _} = Workshops.leave_waitlist(ctx.free_class, ctx.student)
      assert is_nil(Workshops.waitlist_position(ctx.free_class, ctx.student))
    end

    test "anonymous visitor does not join the waitlist", ctx do
      lotar(ctx.free_class)

      assert {:error, :unauthorized} = Workshops.join_waitlist(ctx.free_class, nil)
    end
  end

  describe "the waitlist moves when a seat opens" do
    setup ctx do
      inscrita = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.free_class, inscrita)
      {:ok, _} = Workshops.join_waitlist(ctx.free_class, ctx.student)
      Map.put(ctx, :inscrita, inscrita)
    end

    test "cancelling promotes whoever waited longest", ctx do
      {:ok, _} = Workshops.cancel_enrollment(ctx.free_class, ctx.inscrita)

      assert MapSet.member?(Workshops.enrolled_workshop_ids(ctx.student.id), ctx.free_class.id)
      assert is_nil(Workshops.waitlist_position(ctx.free_class, ctx.student))
    end

    test "promoted user is notified instead of finding out by chance", ctx do
      Repo.delete_all(Notification)
      {:ok, _} = Workshops.cancel_enrollment(ctx.free_class, ctx.inscrita)

      assert [aviso] = Repo.all(from n in Notification, where: n.user_id == ^ctx.student.id)
      assert aviso.action == :workshop_waitlist_promoted
    end

    test "promotes one person per seat, not the whole waitlist", ctx do
      monday = insert(:user)
      {:ok, _} = Workshops.join_waitlist(ctx.free_class, monday)

      {:ok, _} = Workshops.cancel_enrollment(ctx.free_class, ctx.inscrita)

      assert Workshops.count_enrollments(ctx.free_class.id) == 1
      assert Workshops.waitlist_position(ctx.free_class, monday) == 1
    end

    test "with nobody waiting, cancelling only frees the seat", ctx do
      {:ok, _} = Workshops.leave_waitlist(ctx.free_class, ctx.student)

      assert {:ok, _} = Workshops.cancel_enrollment(ctx.free_class, ctx.inscrita)
      assert Workshops.count_enrollments(ctx.free_class.id) == 0
    end
  end

  describe "the demand the organizer sees" do
    test "lists who is waiting, in order", ctx do
      lotar(ctx.free_class)
      {:ok, _} = Workshops.join_waitlist(ctx.free_class, insert(:user, name: "Primeira Fila"))
      {:ok, _} = Workshops.join_waitlist(ctx.free_class, insert(:user, name: "Segunda Fila"))

      assert [first, monday] = Workshops.list_waitlist(ctx.free_class.id)
      assert first.name == "Primeira Fila"
      assert monday.name == "Segunda Fila"
    end
  end
end
