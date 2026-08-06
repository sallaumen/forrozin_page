defmodule OGrupoDeEstudos.ProgramAdminsTest do
  @moduledoc """
  Co-organizers of a program.

  Who administers a program used to be one person, the creator. A festival is
  run by more than one, and whoever helps run it needs the financial picture of
  the event without being handed the whole account.

  Administering the program does NOT hand over the workshops inside it: they
  can belong to other teachers, and their money is theirs. Access to a workshop
  keeps being its own invitation.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  setup do
    owner = insert(:user)
    {:ok, program} = Workshops.create_program(owner, %{title: "Festival", price_cents: 9000})

    %{owner: owner, program: program, teacher: insert(:user), stranger: insert(:user)}
  end

  describe "add_program_admin/3" do
    test "the creator promotes someone to co-organizer", ctx do
      assert {:ok, _} = Workshops.add_program_admin(ctx.program, ctx.owner, ctx.teacher.id)

      assert Workshops.program_admin?(ctx.program, ctx.teacher)
    end

    test "the creator administers without a row of their own", ctx do
      assert Workshops.program_admin?(ctx.program, ctx.owner)
      assert Workshops.list_program_admins(ctx.program) == []
    end

    test "a co-organizer cannot promote anyone else: that door is the creator's", ctx do
      {:ok, _} = Workshops.add_program_admin(ctx.program, ctx.owner, ctx.teacher.id)

      assert {:error, :unauthorized} =
               Workshops.add_program_admin(ctx.program, ctx.teacher, ctx.stranger.id)
    end

    test "promoting the same person twice does not duplicate the link", ctx do
      {:ok, _} = Workshops.add_program_admin(ctx.program, ctx.owner, ctx.teacher.id)

      assert {:error, :already_admin} =
               Workshops.add_program_admin(ctx.program, ctx.owner, ctx.teacher.id)
    end

    test "promoting the creator is refused: they already own it", ctx do
      assert {:error, :already_admin} =
               Workshops.add_program_admin(ctx.program, ctx.owner, ctx.owner.id)
    end

    test "an unknown person is not found", ctx do
      assert {:error, :not_found} =
               Workshops.add_program_admin(ctx.program, ctx.owner, Ecto.UUID.generate())
    end
  end

  describe "what a co-organizer reaches" do
    setup ctx do
      {:ok, _} = Workshops.add_program_admin(ctx.program, ctx.owner, ctx.teacher.id)
      ctx
    end

    test "sees the balance of the event", ctx do
      assert {:ok, _balance} = Workshops.program_revenue(ctx.program, ctx.teacher)
    end

    test "sees who bought the package and the payment of each one", ctx do
      assert {:ok, _} = Workshops.list_package_enrollments(ctx.program, ctx.teacher)
      assert {:ok, _} = Workshops.package_summary(ctx.program, ctx.teacher)
    end

    test "marks the package payment", ctx do
      student = insert(:user)
      {:ok, membership} = Workshops.enroll_in_package(ctx.program, student)

      assert {:ok, updated} =
               Workshops.set_package_payment(ctx.program, ctx.teacher, membership.id, :paid)

      assert updated.payment_status == :paid
    end

    test "does not administer the workshops inside the program", ctx do
      other_teacher = insert(:user)
      workshop = insert(:workshop, organizer: other_teacher)
      {:ok, _} = Workshops.add_admin(workshop, other_teacher, ctx.owner.id)
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.owner, workshop.id)

      refute Workshops.admin?(workshop, ctx.teacher)

      assert {:error, :unauthorized} =
               Workshops.list_enrollments_for_organizer(workshop, ctx.teacher)
    end
  end

  describe "someone who administers nothing" do
    test "reaches neither the balance nor the packages", ctx do
      assert {:error, :unauthorized} = Workshops.program_revenue(ctx.program, ctx.stranger)

      assert {:error, :unauthorized} =
               Workshops.list_package_enrollments(ctx.program, ctx.stranger)

      refute Workshops.program_admin?(ctx.program, ctx.stranger)
    end

    test "nobody is an admin of a program when logged out", ctx do
      refute Workshops.program_admin?(ctx.program, nil)
    end
  end

  describe "remove_program_admin/3" do
    setup ctx do
      {:ok, _} = Workshops.add_program_admin(ctx.program, ctx.owner, ctx.teacher.id)
      ctx
    end

    test "the creator removes whoever they promoted", ctx do
      assert {:ok, _} = Workshops.remove_program_admin(ctx.program, ctx.owner, ctx.teacher.id)

      refute Workshops.program_admin?(ctx.program, ctx.teacher)
    end

    test "a co-organizer can step out on their own", ctx do
      assert {:ok, _} = Workshops.remove_program_admin(ctx.program, ctx.teacher, ctx.teacher.id)

      refute Workshops.program_admin?(ctx.program, ctx.teacher)
    end

    test "a co-organizer cannot remove another one", ctx do
      {:ok, _} = Workshops.add_program_admin(ctx.program, ctx.owner, ctx.stranger.id)

      assert {:error, :unauthorized} =
               Workshops.remove_program_admin(ctx.program, ctx.teacher, ctx.stranger.id)
    end

    test "the creator cannot be removed, not even by themselves", ctx do
      assert {:error, :cannot_remove_owner} =
               Workshops.remove_program_admin(ctx.program, ctx.owner, ctx.owner.id)
    end
  end
end
