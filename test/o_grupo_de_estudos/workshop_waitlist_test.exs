defmodule OGrupoDeEstudos.WorkshopWaitlistTest do
  @moduledoc """
  Where enrollment is automatic the capacity holds and forms a waitlist; where
  a human approves each entry, capacity can be exceeded. A full class with no
  waitlist would hide the demand that justifies opening another class.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory
  import Swoosh.TestAssertions

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

  describe "raising the capacity drains the waitlist" do
    defp all_emails do
      receive do
        {:email, email} -> [email | all_emails()]
      after
        0 -> []
      end
    end

    defp waiting_trio(workshop) do
      trio = for _ <- 1..3, do: insert(:user)
      for pessoa <- trio, do: {:ok, _} = Workshops.join_waitlist(workshop, pessoa)
      trio
    end

    test "promotes whoever fits, in waiting order", ctx do
      lotar(ctx.free_class)
      [primeira, segunda, terceira] = waiting_trio(ctx.free_class)

      {:ok, _} = Workshops.update_workshop(ctx.owner, ctx.free_class, %{capacity: 3})

      enrolled_ids =
        ctx.free_class.id |> Workshops.list_participants() |> Enum.map(& &1.user_id)

      assert primeira.id in enrolled_ids
      assert segunda.id in enrolled_ids
      refute terceira.id in enrolled_ids
      assert Workshops.waitlist_count(ctx.free_class.id) == 1
    end

    test "removing the limit promotes the whole waitlist", ctx do
      lotar(ctx.free_class)
      trio = waiting_trio(ctx.free_class)

      {:ok, _} = Workshops.update_workshop(ctx.owner, ctx.free_class, %{capacity: nil})

      enrolled_ids =
        ctx.free_class.id |> Workshops.list_participants() |> Enum.map(& &1.user_id)

      assert Enum.all?(trio, &(&1.id in enrolled_ids))
      assert Workshops.waitlist_count(ctx.free_class.id) == 0
    end

    test "an update that does not loosen the capacity promotes nobody", ctx do
      lotar(ctx.free_class)
      waiting_trio(ctx.free_class)

      {:ok, _} = Workshops.update_workshop(ctx.owner, ctx.free_class, %{title: "Novo nome"})

      assert Workshops.waitlist_count(ctx.free_class.id) == 3
    end

    test "whoever gets the seat hears the good news by email and by bell", ctx do
      lotar(ctx.free_class)
      [primeira, _segunda, _terceira] = waiting_trio(ctx.free_class)

      {:ok, _} = Workshops.update_workshop(ctx.owner, ctx.free_class, %{capacity: 2})

      good_news =
        Enum.find(all_emails(), fn email -> elem(hd(email.to), 1) == primeira.email end)

      assert good_news.text_body =~ "vagas"
      assert good_news.text_body =~ ctx.free_class.slug

      assert [_] =
               Repo.all(
                 from n in Notification,
                   where: n.action == :workshop_waitlist_promoted and n.user_id == ^primeira.id
               )
    end

    test "the seat freed by a cancellation also emails the promoted person", ctx do
      lotar(ctx.free_class)
      [primeira, _segunda, _terceira] = waiting_trio(ctx.free_class)
      [enrolled] = Workshops.list_participants(ctx.free_class.id)
      desistente = OGrupoDeEstudos.Accounts.get_user_by_id(enrolled.user_id)

      {:ok, _} = Workshops.cancel_enrollment(ctx.free_class, desistente)

      good_news =
        Enum.find(all_emails(), fn email -> elem(hd(email.to), 1) == primeira.email end)

      assert good_news.text_body =~ "vaga"
      assert good_news.text_body =~ ctx.free_class.slug
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
