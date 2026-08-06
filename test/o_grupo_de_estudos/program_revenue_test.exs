defmodule OGrupoDeEstudos.ProgramRevenueTest do
  @moduledoc """
  The balance of a program is the whole of it: what was bought as a package plus
  what each person paid for a single workshop.

  Whoever organizes needs to see one number per workshop and one number for the
  event, without adding it up by hand across panels.
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

    %{owner: owner, program: program, workshops: workshops}
  end

  defp buy_package(ctx, student) do
    {:ok, membership} = Workshops.enroll_in_package(ctx.program, student)
    {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, membership.id, :paid)
    membership
  end

  defp pay_single(ctx, workshop, student) do
    {:ok, _} = Workshops.enroll(workshop, student)
    {:ok, rows} = Workshops.list_enrollments_for_organizer(workshop, ctx.owner)
    row = Enum.find(rows, &(&1.user.id == student.id))
    {:ok, _} = Workshops.set_payment_status(workshop, ctx.owner, row.id, :paid)
  end

  defp balance(ctx), do: Workshops.program_revenue(ctx.program, ctx.owner)

  describe "program_revenue/2" do
    test "separates what came from packages and what came one workshop at a time", ctx do
      buy_package(ctx, insert(:user))
      pay_single(ctx, hd(ctx.workshops), insert(:user))

      {:ok, balance} = balance(ctx)

      assert [saturday, sunday] = balance.workshops
      assert saturday.package_cents == 4500
      assert saturday.individual_cents == 5000
      assert saturday.total_cents == 9500
      assert sunday.package_cents == 4500
      assert sunday.individual_cents == 0
      assert sunday.total_cents == 4500
    end

    test "the total of the event is the package money plus the individual money", ctx do
      buy_package(ctx, insert(:user))
      pay_single(ctx, hd(ctx.workshops), insert(:user))

      {:ok, balance} = balance(ctx)

      assert balance.package_cents == 9000
      assert balance.individual_cents == 5000
      assert balance.total_cents == 14_000
    end

    test "each workshop line adds up to the total of the event", ctx do
      buy_package(ctx, insert(:user))
      buy_package(ctx, insert(:user))
      pay_single(ctx, List.last(ctx.workshops), insert(:user))

      {:ok, balance} = balance(ctx)

      assert balance.workshops |> Enum.map(& &1.total_cents) |> Enum.sum() ==
               balance.total_cents
    end

    test "the package money never exceeds what the packages actually paid", ctx do
      buy_package(ctx, insert(:user))
      buy_package(ctx, insert(:user))

      {:ok, balance} = balance(ctx)

      assert balance.package_cents == 18_000
    end

    test "an event where nobody paid is all zeros, not a blank", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, insert(:user))

      {:ok, balance} = balance(ctx)

      assert balance.total_cents == 0
      assert Enum.map(balance.workshops, & &1.total_cents) == [0, 0]
    end

    test "a waived package brings in nothing", ctx do
      student = insert(:user)
      {:ok, membership} = Workshops.enroll_in_package(ctx.program, student)
      {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, membership.id, :waived)

      {:ok, balance} = balance(ctx)

      assert balance.total_cents == 0
    end

    test "names each workshop, so the line can be read without another query", ctx do
      {:ok, balance} = balance(ctx)

      assert Enum.map(balance.workshops, & &1.title) == Enum.map(ctx.workshops, & &1.title)
    end

    test "counts how many paid each workshop, whatever the path was", ctx do
      buy_package(ctx, insert(:user))
      pay_single(ctx, hd(ctx.workshops), insert(:user))

      {:ok, balance} = balance(ctx)

      assert hd(balance.workshops).paid == 2
      assert List.last(balance.workshops).paid == 1
    end

    test "only whoever owns the program sees the balance", ctx do
      assert {:error, :unauthorized} = Workshops.program_revenue(ctx.program, insert(:user))
    end
  end
end
