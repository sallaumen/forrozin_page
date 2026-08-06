defmodule OGrupoDeEstudos.PackageAccountingTest do
  @moduledoc """
  One payment for a package must show up once, in the right places.

  The package is paid on the program, and each workshop it covers reads as paid
  and keeps only its slice of the amount. What the organizer must never be able
  to do is charge the same person twice for the same money.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  defp at_day(days, hour) do
    OGrupoDeEstudos.Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(Time.new!(hour, 0, 0), "Etc/UTC")
    |> OGrupoDeEstudos.Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  setup do
    owner = insert(:user)

    {:ok, program} =
      Workshops.create_program(owner, %{title: "Fim de semana", price_cents: 9000})

    workshops =
      for day <- [7, 8] do
        insert(:workshop, organizer: owner, starts_at: at_day(day, 19), price_cents: 5000)
      end

    for w <- workshops, do: Workshops.attach_workshop(program, owner, w.id)
    {:ok, program} = Workshops.publish_program(owner, program)

    %{owner: owner, program: program, workshops: workshops, student: insert(:user)}
  end

  defp mark_package_paid(ctx, student) do
    {:ok, membership} = Workshops.enroll_in_package(ctx.program, student)
    {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, membership.id, :paid)
    membership
  end

  defp roster(ctx, workshop) do
    {:ok, enrollments} = Workshops.list_enrollments_for_organizer(workshop, ctx.owner)
    enrollments
  end

  defp summary(ctx, workshop) do
    {:ok, summary} = Workshops.payment_summary(workshop, ctx.owner)
    summary
  end

  describe "paying the package" do
    test "marks the person as paid in every workshop it covers", ctx do
      mark_package_paid(ctx, ctx.student)

      for workshop <- ctx.workshops do
        assert [row] = roster(ctx, workshop)
        assert row.payment_status == :paid
      end
    end

    test "says the payment came from the program, so the organizer knows why", ctx do
      mark_package_paid(ctx, ctx.student)

      assert [row] = roster(ctx, hd(ctx.workshops))
      assert row.covered_by_package?
      assert row.program_title == "Fim de semana"
    end

    test "attributes to each workshop only its slice of the package", ctx do
      mark_package_paid(ctx, ctx.student)

      for workshop <- ctx.workshops do
        assert [row] = roster(ctx, workshop)
        assert row.package_share_cents == 4500
      end
    end

    test "the workshop counts the slice, not its own price", ctx do
      mark_package_paid(ctx, ctx.student)

      assert summary(ctx, hd(ctx.workshops)).revenue_cents == 4500
    end

    test "the slices of one package add up to exactly what was paid", ctx do
      mark_package_paid(ctx, ctx.student)

      total = ctx.workshops |> Enum.map(&summary(ctx, &1).revenue_cents) |> Enum.sum()

      assert total == 9000
    end

    test "going back to pending takes the payment off the workshops too", ctx do
      membership = mark_package_paid(ctx, ctx.student)
      {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, membership.id, :pending)

      assert [row] = roster(ctx, hd(ctx.workshops))
      assert row.payment_status == :pending
      assert summary(ctx, hd(ctx.workshops)).revenue_cents == 0
    end

    test "a waived package leaves the workshops waived and charges nothing", ctx do
      {:ok, membership} = Workshops.enroll_in_package(ctx.program, ctx.student)
      {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, membership.id, :waived)

      assert [row] = roster(ctx, hd(ctx.workshops))
      assert row.payment_status == :waived
      assert summary(ctx, hd(ctx.workshops)).revenue_cents == 0
    end
  end

  describe "charging the same money twice" do
    test "the organizer cannot mark payment on an enrollment the package covers", ctx do
      mark_package_paid(ctx, ctx.student)
      workshop = hd(ctx.workshops)
      [row] = roster(ctx, workshop)

      assert {:error, :covered_by_package} =
               Workshops.set_payment_status(workshop, ctx.owner, row.id, :paid)
    end

    test "someone who paid the workshop and then buys the package counts once", ctx do
      workshop = hd(ctx.workshops)
      {:ok, _} = Workshops.enroll(workshop, ctx.student)
      [row] = roster(ctx, workshop)
      {:ok, _} = Workshops.set_payment_status(workshop, ctx.owner, row.id, :paid)

      mark_package_paid(ctx, ctx.student)

      assert summary(ctx, workshop).revenue_cents == 4500
    end
  end

  describe "seeing how the package price divides" do
    test "gives each workshop of the program its slice", ctx do
      assert {:ok, shares} = Workshops.package_shares(ctx.program, ctx.owner)

      assert Enum.map(shares, & &1.share_cents) == [4500, 4500]
      assert Enum.map(shares, & &1.id) == Enum.map(ctx.workshops, & &1.id)
    end

    test "the slices add up to the package price", ctx do
      {:ok, shares} = Workshops.package_shares(ctx.program, ctx.owner)

      assert shares |> Enum.map(& &1.share_cents) |> Enum.sum() == 9000
    end

    test "only whoever owns the program sees it", ctx do
      assert {:error, :unauthorized} =
               Workshops.package_shares(ctx.program, insert(:user))
    end
  end

  describe "workshops paid one by one" do
    test "still count their own full price", ctx do
      workshop = hd(ctx.workshops)
      {:ok, _} = Workshops.enroll(workshop, ctx.student)
      [row] = roster(ctx, workshop)
      {:ok, _} = Workshops.set_payment_status(workshop, ctx.owner, row.id, :paid)

      assert summary(ctx, workshop).revenue_cents == 5000
      refute hd(roster(ctx, workshop)).covered_by_package?
    end

    test "add up alongside the package slices in the same workshop", ctx do
      workshop = hd(ctx.workshops)
      avulso = insert(:user)
      {:ok, _} = Workshops.enroll(workshop, avulso)
      [row] = roster(ctx, workshop)
      {:ok, _} = Workshops.set_payment_status(workshop, ctx.owner, row.id, :paid)

      mark_package_paid(ctx, ctx.student)

      assert summary(ctx, workshop).revenue_cents == 9500
      assert summary(ctx, workshop).paid == 2
    end
  end
end
