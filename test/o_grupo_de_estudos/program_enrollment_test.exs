defmodule OGrupoDeEstudos.ProgramEnrollmentTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement.Notifications.Notification
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
    {:ok, program} = Workshops.create_program(owner, %{title: "Dois dias"})

    thursday = insert(:workshop, organizer: owner, title: "Quinta", starts_at: at_day(7, 19))
    friday = insert(:workshop, organizer: owner, title: "Sexta", starts_at: at_day(8, 19))
    for w <- [thursday, friday], do: Workshops.attach_workshop(program, owner, w.id)

    %{owner: owner, program: program, thursday: thursday, friday: friday, student: insert(:user)}
  end

  describe "enroll_many/3" do
    test "enrolls in both workshops at once", ctx do
      assert {:ok, result} =
               Workshops.enroll_many(ctx.program, ctx.student, [ctx.thursday.id, ctx.friday.id])

      assert length(result.enrolled) == 2
      assert result.failed == []

      enrolled_ids = Workshops.enrolled_workshop_ids(ctx.student.id)
      assert MapSet.member?(enrolled_ids, ctx.thursday.id)
      assert MapSet.member?(enrolled_ids, ctx.friday.id)
    end

    test "one full workshop does not block the others", ctx do
      full_workshop =
        insert(:workshop,
          organizer: ctx.owner,
          title: "Lotado",
          capacity: 1,
          starts_at: at_day(9, 19)
        )

      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.owner, full_workshop.id)
      {:ok, _} = Workshops.enroll(full_workshop, insert(:user))

      assert {:ok, result} =
               Workshops.enroll_many(ctx.program, ctx.student, [
                 ctx.thursday.id,
                 full_workshop.id,
                 ctx.friday.id
               ])

      assert length(result.enrolled) == 2
      assert [{workshop, :full}] = result.failed
      assert workshop.id == full_workshop.id
    end

    test "already enrolled counts as success, not as failure", ctx do
      {:ok, _} = Workshops.enroll(ctx.thursday, ctx.student)

      assert {:ok, result} =
               Workshops.enroll_many(ctx.program, ctx.student, [ctx.thursday.id, ctx.friday.id])

      assert length(result.enrolled) == 2
      assert result.failed == []
    end

    test "ignores workshop id from another program", ctx do
      alheio = insert(:workshop)

      assert {:ok, result} =
               Workshops.enroll_many(ctx.program, ctx.student, [ctx.thursday.id, alheio.id])

      assert length(result.enrolled) == 1
      refute MapSet.member?(Workshops.enrolled_workshop_ids(ctx.student.id), alheio.id)
    end

    test "non-uuid id does not crash", ctx do
      assert {:ok, result} =
               Workshops.enroll_many(ctx.program, ctx.student, ["; drop table", ctx.thursday.id])

      assert length(result.enrolled) == 1
    end

    test "draft workshop inside the program rejects enrollment", ctx do
      draft = insert(:workshop, organizer: ctx.owner, status: :draft, starts_at: at_day(9, 19))
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.owner, draft.id)

      assert {:error, :none_selected} =
               Workshops.enroll_many(ctx.program, ctx.student, [draft.id])
    end

    test "draft in the middle of the list does not block the published ones", ctx do
      draft = insert(:workshop, organizer: ctx.owner, status: :draft, starts_at: at_day(9, 19))
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.owner, draft.id)

      assert {:ok, result} =
               Workshops.enroll_many(ctx.program, ctx.student, [draft.id, ctx.thursday.id])

      assert length(result.enrolled) == 1
    end

    test "empty selection returns its own error", ctx do
      assert {:error, :none_selected} = Workshops.enroll_many(ctx.program, ctx.student, [])
    end

    test "organizer does not enroll in their own workshops", ctx do
      assert {:ok, result} =
               Workshops.enroll_many(ctx.program, ctx.owner, [ctx.thursday.id, ctx.friday.id])

      assert result.enrolled == []
      assert length(result.failed) == 2
      assert Enum.all?(result.failed, fn {_w, reason} -> reason == :organizer end)
    end
  end

  describe "aviso ao organizador num lote" do
    test "notifies once per person, not once per workshop", ctx do
      {:ok, _} = Workshops.enroll_many(ctx.program, ctx.student, [ctx.thursday.id, ctx.friday.id])

      avisos =
        Notification
        |> Repo.all()
        |> Enum.filter(&(&1.user_id == ctx.owner.id and &1.action == :workshop_enrolled))

      assert length(avisos) == 1
      assert hd(avisos).group_key =~ ctx.program.id
    end

    test "notifies each teacher about their own workshop", ctx do
      joana = insert(:user)
      dela = insert(:workshop, organizer: joana, starts_at: at_day(9, 19))
      {:ok, _} = Workshops.add_admin(dela, joana, ctx.owner.id)
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.owner, dela.id)

      {:ok, _} = Workshops.enroll_many(ctx.program, ctx.student, [ctx.thursday.id, dela.id])

      destinatarios =
        Notification
        |> Repo.all()
        |> Enum.filter(&(&1.action == :workshop_enrolled))
        |> Enum.map(& &1.user_id)
        |> MapSet.new()

      assert MapSet.member?(destinatarios, ctx.owner.id)
      assert MapSet.member?(destinatarios, joana.id)
    end

    test "batch with no enrollment notifies nobody", ctx do
      Repo.delete_all(Notification)

      {:ok, _} = Workshops.enroll_many(ctx.program, ctx.owner, [ctx.thursday.id])

      assert Repo.all(Notification) == []
    end
  end
end
