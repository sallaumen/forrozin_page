defmodule OGrupoDeEstudos.PackageConversionTest do
  @moduledoc """
  Turning a hand-made pile of daily enrollments into the package it meant to be.

  People enrolled workshop by workshop in programs that sell a discounted
  package. The books then see three full-price daily enrollments where one
  discounted package was actually paid. The organizer needs to see who did this
  and convert them with one action, without touching capacity and without the
  student gaining or losing a class.
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
      Workshops.create_program(owner, %{
        title: "Três dias",
        price_cents: 15_000,
        payment_info: "Pix do festival"
      })

    workshops =
      for {day, price} <- [{7, 6000}, {8, 6000}, {9, 6000}] do
        insert(:workshop, organizer: owner, starts_at: at_day(day, 19), price_cents: price)
      end

    for w <- workshops, do: Workshops.attach_workshop(program, owner, w.id)
    {:ok, program} = Workshops.publish_program(owner, program)

    %{owner: owner, program: program, workshops: workshops}
  end

  defp enroll_in_all(ctx, user) do
    for w <- ctx.workshops, do: {:ok, _} = Workshops.enroll(w, user)
    user
  end

  describe "list_package_candidates/2" do
    test "finds whoever enrolled in every workshop by hand", ctx do
      complete = enroll_in_all(ctx, insert(:user, name: "Completa"))

      assert {:ok, [candidate]} = Workshops.list_package_candidates(ctx.program, ctx.owner)
      assert candidate.user_id == complete.id
      assert candidate.name == "Completa"
    end

    test "someone in only part of the program is not a candidate", ctx do
      partial = insert(:user)
      [first, second, _third] = ctx.workshops
      {:ok, _} = Workshops.enroll(first, partial)
      {:ok, _} = Workshops.enroll(second, partial)

      assert {:ok, []} = Workshops.list_package_candidates(ctx.program, ctx.owner)
    end

    test "whoever bought the package is already accounted for, not a candidate", ctx do
      buyer = insert(:user)
      {:ok, _} = Workshops.enroll_in_package(ctx.program, buyer)

      assert {:ok, []} = Workshops.list_package_candidates(ctx.program, ctx.owner)
    end

    test "the roster of candidates is for whoever runs the program only", ctx do
      enroll_in_all(ctx, insert(:user))

      assert {:error, :unauthorized} =
               Workshops.list_package_candidates(ctx.program, insert(:user))
    end
  end

  describe "convert_to_package/3" do
    test "the daily enrollments become one package, capacity untouched", ctx do
      student = enroll_in_all(ctx, insert(:user))

      assert {:ok, membership} = Workshops.convert_to_package(ctx.program, ctx.owner, student.id)

      assert membership.payment_status == :pending

      for w <- ctx.workshops do
        enrollment = Workshops.get_enrollment(w.id, student.id)
        assert enrollment.program_enrollment_id == membership.id
      end
    end

    test "a converted person stops being a candidate", ctx do
      student = enroll_in_all(ctx, insert(:user))

      {:ok, _} = Workshops.convert_to_package(ctx.program, ctx.owner, student.id)

      assert {:ok, []} = Workshops.list_package_candidates(ctx.program, ctx.owner)
    end

    test "refuses whoever is not in every workshop, enrolling them in nothing", ctx do
      partial = insert(:user)
      [first, _second, third] = ctx.workshops
      {:ok, _} = Workshops.enroll(first, partial)

      assert {:error, :not_fully_enrolled} =
               Workshops.convert_to_package(ctx.program, ctx.owner, partial.id)

      assert Workshops.get_enrollment(third.id, partial.id) == nil
      assert {:ok, []} = Workshops.list_package_enrollments(ctx.program, ctx.owner)
    end

    test "refuses whoever already has the package", ctx do
      buyer = insert(:user)
      {:ok, _} = Workshops.enroll_in_package(ctx.program, buyer)

      assert {:error, :already_enrolled} =
               Workshops.convert_to_package(ctx.program, ctx.owner, buyer.id)
    end

    test "only whoever runs the program converts", ctx do
      student = enroll_in_all(ctx, insert(:user))

      assert {:error, :unauthorized} =
               Workshops.convert_to_package(ctx.program, insert(:user), student.id)

      assert Workshops.get_enrollment(hd(ctx.workshops).id, student.id).program_enrollment_id ==
               nil
    end

    test "a program admin who is not the owner also converts", ctx do
      admin = insert(:user)
      {:ok, _} = Workshops.add_program_admin(ctx.program, ctx.owner, admin.id)
      student = enroll_in_all(ctx, insert(:user))

      assert {:ok, _membership} = Workshops.convert_to_package(ctx.program, admin, student.id)
    end

    test "after conversion the books charge the slice, not three full prices", ctx do
      student = enroll_in_all(ctx, insert(:user))
      [first | _] = ctx.workshops

      # marcada como paga no avulso antes da conversão: era assim que a
      # contabilidade estava errada, três diárias cheias no lugar do pacote
      {:ok, _} =
        Workshops.set_payment_status(first, ctx.owner, enrollment_id(first, student), :paid)

      {:ok, membership} = Workshops.convert_to_package(ctx.program, ctx.owner, student.id)
      {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, membership.id, :paid)

      {:ok, roster} = Workshops.list_enrollments_for_organizer(first, ctx.owner)
      [row] = roster

      assert row.covered_by_package?
      assert row.payment_status == :paid
      assert row.package_share_cents == 5000, "15000 do pacote dividido por três dias iguais"
    end
  end

  defp enrollment_id(workshop, user), do: Workshops.get_enrollment(workshop.id, user.id).id

  # The state found in production on 2026-08-04: the package was bought while
  # the program had no published workshop, so the membership covered nothing;
  # the workshops came later and the person enrolled day by day, unlinked. The
  # person then shows in the package list AND in the candidates at once.
  defp orphan_membership(ctx) do
    {:ok, empty_program} =
      Workshops.create_program(ctx.owner, %{title: "Nasceu vazio", price_cents: 9000})

    student = insert(:user)
    {:ok, membership} = Workshops.enroll_in_package(empty_program, student)

    late = insert(:workshop, organizer: ctx.owner, starts_at: at_day(12, 19), price_cents: 5000)
    {:ok, _} = Workshops.attach_workshop(empty_program, ctx.owner, late.id)
    {:ok, empty_program} = Workshops.publish_program(ctx.owner, empty_program)
    {:ok, enrollment} = Workshops.enroll(late, student)

    # `enroll` now links on its own, so the loose row is built directly: this is
    # the legacy data as found, not a state the public API still produces.
    enrollment
    |> Ecto.Changeset.change(program_enrollment_id: nil)
    |> OGrupoDeEstudos.Repo.update!()

    %{program: empty_program, student: student, membership: membership, workshop: late}
  end

  describe "the membership that covers nothing, next to loose enrollments" do
    test "the person shows as candidate, because their money is miscounted", ctx do
      orphan = orphan_membership(ctx)

      assert {:ok, [candidate]} = Workshops.list_package_candidates(orphan.program, ctx.owner)
      assert candidate.user_id == orphan.student.id
    end

    test "converting adopts the loose enrollments into the membership that exists", ctx do
      orphan = orphan_membership(ctx)

      assert {:ok, adopted} =
               Workshops.convert_to_package(orphan.program, ctx.owner, orphan.student.id)

      assert adopted.id == orphan.membership.id

      enrollment = Workshops.get_enrollment(orphan.workshop.id, orphan.student.id)
      assert enrollment.program_enrollment_id == orphan.membership.id
    end

    test "adopting keeps the payment already recorded on the membership", ctx do
      orphan = orphan_membership(ctx)

      {:ok, _} =
        Workshops.set_package_payment(orphan.program, ctx.owner, orphan.membership.id, :paid)

      {:ok, adopted} = Workshops.convert_to_package(orphan.program, ctx.owner, orphan.student.id)

      assert adopted.payment_status == :paid
      assert {:ok, []} = Workshops.list_package_candidates(orphan.program, ctx.owner)
    end
  end

  describe "enrolling while holding the package" do
    test "a cancelled day re-enrolled comes back linked, not loose", ctx do
      student = insert(:user)
      {:ok, membership} = Workshops.enroll_in_package(ctx.program, student)
      [first | _] = ctx.workshops

      {:ok, _} = Workshops.cancel_enrollment(first, student)
      {:ok, enrollment} = Workshops.enroll(first, student)

      assert enrollment.program_enrollment_id == membership.id
    end

    test "a workshop attached after the purchase also links on enrollment", ctx do
      student = insert(:user)
      {:ok, membership} = Workshops.enroll_in_package(ctx.program, student)

      late = insert(:workshop, organizer: ctx.owner, starts_at: at_day(10, 19), price_cents: 6000)
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.owner, late.id)
      {:ok, enrollment} = Workshops.enroll(late, student)

      assert enrollment.program_enrollment_id == membership.id

      assert {:ok, []} = Workshops.list_package_candidates(ctx.program, ctx.owner)
    end

    test "a workshop outside any program enrolls loose, as always", ctx do
      student = insert(:user)
      {:ok, _} = Workshops.enroll_in_package(ctx.program, student)

      solo = insert(:workshop, organizer: ctx.owner, starts_at: at_day(11, 19))
      {:ok, enrollment} = Workshops.enroll(solo, student)

      assert enrollment.program_enrollment_id == nil
    end
  end
end
