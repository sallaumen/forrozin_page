defmodule OGrupoDeEstudos.ProgramPackageTest do
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

    %{owner: owner, program: program, workshops: workshops, student: insert(:user)}
  end

  describe "enroll_in_package/2" do
    test "enrolls in every workshop of the program at once", ctx do
      assert {:ok, matricula} = Workshops.enroll_in_package(ctx.program, ctx.student)

      assert matricula.payment_status == :pending
      enrolled_ids = Workshops.enrolled_workshop_ids(ctx.student.id)
      assert Enum.all?(ctx.workshops, &MapSet.member?(enrolled_ids, &1.id))
    end

    test "enrollments point to the package so the price is charged once", ctx do
      {:ok, matricula} = Workshops.enroll_in_package(ctx.program, ctx.student)

      cobertas =
        ctx.workshops
        |> Enum.map(&Workshops.get_enrollment(&1.id, ctx.student.id))
        |> Enum.map(& &1.program_enrollment_id)

      assert Enum.all?(cobertas, &(&1 == matricula.id))
    end

    test "program without package price does not sell a package", %{
      owner: owner,
      student: student
    } do
      {:ok, without_price} = Workshops.create_program(owner, %{title: "Só avulso"})
      w = insert(:workshop, organizer: owner, starts_at: at_day(7, 19))
      {:ok, _} = Workshops.attach_workshop(without_price, owner, w.id)
      {:ok, without_price} = Workshops.publish_program(owner, without_price)

      assert {:error, :no_package} = Workshops.enroll_in_package(without_price, student)
    end

    test "one full workshop cancels the whole package and leaves no trace", ctx do
      [first, _, terceiro] = ctx.workshops
      {:ok, full_workshop} = Workshops.update_workshop(ctx.owner, terceiro, %{capacity: 1})
      {:ok, _} = Workshops.enroll(full_workshop, insert(:user))

      assert {:error, {:full, workshop}} = Workshops.enroll_in_package(ctx.program, ctx.student)
      assert workshop.id == terceiro.id

      enrolled_ids = Workshops.enrolled_workshop_ids(ctx.student.id)
      refute MapSet.member?(enrolled_ids, first.id)
      assert Workshops.list_package_enrollments(ctx.program, ctx.owner) == {:ok, []}
    end

    test "does not sell the package twice to the same person", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, ctx.student)

      assert {:error, :already_enrolled} = Workshops.enroll_in_package(ctx.program, ctx.student)
    end

    test "organizer does not buy the package of their own event", ctx do
      assert {:error, :organizer} = Workshops.enroll_in_package(ctx.program, ctx.owner)
    end

    test "single enrollment becomes package without duplicating the enrollment", ctx do
      [first | _] = ctx.workshops
      {:ok, _} = Workshops.enroll(first, ctx.student)

      assert {:ok, matricula} = Workshops.enroll_in_package(ctx.program, ctx.student)

      enrollment = Workshops.get_enrollment(first.id, ctx.student.id)
      assert enrollment.program_enrollment_id == matricula.id
      assert length(Workshops.list_participants(first.id)) == 1
    end
  end

  describe "package dashboard" do
    test "organizer sees the buyers and marks them as paid", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, ctx.student)

      assert {:ok, [row]} = Workshops.list_package_enrollments(ctx.program, ctx.owner)
      assert row.name == ctx.student.name
      assert row.payment_status == :pending

      assert {:ok, _} =
               Workshops.set_package_payment(ctx.program, ctx.owner, row.id, :paid)

      assert {:ok, [updated]} = Workshops.list_package_enrollments(ctx.program, ctx.owner)
      assert updated.payment_status == :paid
    end

    test "resumo separa pacote de avulso", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, ctx.student)
      avulsa = insert(:user)
      {:ok, _} = Workshops.enroll(hd(ctx.workshops), avulsa)

      assert {:ok, summary} = Workshops.package_summary(ctx.program, ctx.owner)

      assert summary.packages == 1
      assert summary.paid == 0
      assert summary.revenue_cents == 0
    end

    test "package revenue counts only who paid", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, ctx.student)
      {:ok, [row]} = Workshops.list_package_enrollments(ctx.program, ctx.owner)
      {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, row.id, :paid)

      assert {:ok, %{paid: 1, revenue_cents: 15_000}} =
               Workshops.package_summary(ctx.program, ctx.owner)
    end

    test "outsider neither sees nor changes the package payment", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, ctx.student)
      outsider = insert(:user)

      assert {:error, :unauthorized} =
               Workshops.list_package_enrollments(ctx.program, outsider)

      assert {:error, :unauthorized} = Workshops.package_summary(ctx.program, outsider)

      assert {:error, :unauthorized} =
               Workshops.set_package_payment(ctx.program, outsider, Ecto.UUID.generate(), :paid)
    end

    test "workshop co-organizer does not see the package payment of another program", ctx do
      partner = insert(:user)
      {:ok, _} = Workshops.add_admin(hd(ctx.workshops), ctx.owner, partner.id)

      assert {:error, :unauthorized} =
               Workshops.list_package_enrollments(ctx.program, partner)
    end
  end

  describe "single enrollment keeps working alongside the package" do
    test "single enrollment does not get a package membership", ctx do
      {:ok, _} = Workshops.enroll(hd(ctx.workshops), ctx.student)

      enrollment = Workshops.get_enrollment(hd(ctx.workshops).id, ctx.student.id)
      assert is_nil(enrollment.program_enrollment_id)
    end

    test "workshop dashboard distinguishes who came through the package", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, ctx.student)
      avulsa = insert(:user)
      {:ok, _} = Workshops.enroll(hd(ctx.workshops), avulsa)

      {:ok, rows} = Workshops.list_enrollments_for_organizer(hd(ctx.workshops), ctx.owner)

      pelo_pacote = Enum.find(rows, &(&1.user.id == ctx.student.id))
      assert pelo_pacote.program_enrollment_id

      individual = Enum.find(rows, &(&1.user.id == avulsa.id))
      assert is_nil(individual.program_enrollment_id)
    end
  end
end
