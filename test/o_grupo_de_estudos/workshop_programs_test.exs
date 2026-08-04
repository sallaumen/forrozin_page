defmodule OGrupoDeEstudos.WorkshopProgramsTest do
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
    %{owner: insert(:user)}
  end

  describe "create_program/2" do
    test "creates with a readable slug and a suffix", %{owner: owner} do
      assert {:ok, program} =
               Workshops.create_program(owner, %{
                 title: "Fim de semana de forró roots",
                 description: "Quinta e sexta.",
                 location: "Curitiba"
               })

      assert program.owner_id == owner.id
      assert program.status == :draft
      assert program.slug =~ ~r/^fim-de-semana-de-forro-roots-[a-z0-9]+$/
    end

    test "requires a title", %{owner: owner} do
      assert {:error, %Ecto.Changeset{}} =
               Workshops.create_program(owner, %{description: "só isso"})
    end
  end

  describe "attach_workshop/3" do
    setup %{owner: owner} do
      {:ok, program} = Workshops.create_program(owner, %{title: "Meu fim de semana"})
      %{program: program, workshop: insert(:workshop, organizer: owner)}
    end

    test "admin of both sides attaches the workshop", ctx do
      assert {:ok, updated} =
               Workshops.attach_workshop(ctx.program, ctx.owner, ctx.workshop.id)

      assert updated.program_id == ctx.program.id
      assert [w] = Workshops.list_program_workshops(ctx.program)
      assert w.id == ctx.workshop.id
    end

    test "workshop co-organizer also attaches when they own the program", ctx do
      partner = insert(:user)
      {:ok, program_dele} = Workshops.create_program(partner, %{title: "Festival"})
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.owner, partner.id)

      assert {:ok, _} = Workshops.attach_workshop(program_dele, partner, ctx.workshop.id)
    end

    test "does not attach a workshop they do not administer", ctx do
      alheio = insert(:workshop)

      assert {:error, :unauthorized} =
               Workshops.attach_workshop(ctx.program, ctx.owner, alheio.id)
    end

    test "does not attach to someone else's program", ctx do
      assert {:error, :unauthorized} =
               Workshops.attach_workshop(ctx.program, insert(:user), ctx.workshop.id)
    end

    test "made-up id finds nothing", ctx do
      assert {:error, :not_found} =
               Workshops.attach_workshop(ctx.program, ctx.owner, Ecto.UUID.generate())
    end

    test "detach releases the workshop without deleting it", ctx do
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.owner, ctx.workshop.id)

      assert {:ok, solto} = Workshops.detach_workshop(ctx.program, ctx.owner, ctx.workshop.id)
      assert is_nil(solto.program_id)
      assert Workshops.get_workshop(ctx.workshop.id)
    end
  end

  describe "list_program_workshops/2" do
    setup %{owner: owner} do
      {:ok, program} = Workshops.create_program(owner, %{title: "Dois dias"})
      %{program: program}
    end

    test "returns workshops ordered by date, earliest first", ctx do
      friday = insert(:workshop, organizer: ctx.owner, starts_at: at_day(8, 20))
      thursday = insert(:workshop, organizer: ctx.owner, starts_at: at_day(7, 19))

      for w <- [friday, thursday], do: Workshops.attach_workshop(ctx.program, ctx.owner, w.id)

      assert [first, second] = Workshops.list_program_workshops(ctx.program)
      assert first.id == thursday.id
      assert second.id == friday.id
    end

    test "draft stays out for plain visitors", ctx do
      published = insert(:workshop, organizer: ctx.owner)
      draft = insert(:workshop, organizer: ctx.owner, status: :draft)

      for w <- [published, draft], do: Workshops.attach_workshop(ctx.program, ctx.owner, w.id)

      assert [visible] = Workshops.list_program_workshops(ctx.program)
      assert visible.id == published.id

      assert length(Workshops.list_program_workshops(ctx.program, include_drafts: true)) == 2
    end

    test "cancelled stays in the list: enrolled people need to know", ctx do
      cancelled = insert(:workshop, organizer: ctx.owner, status: :cancelled)
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.owner, cancelled.id)

      assert [w] = Workshops.list_program_workshops(ctx.program)
      assert w.status == :cancelled
    end
  end

  describe "publish_program/2 e cancel_program/2" do
    setup %{owner: owner} do
      {:ok, program} = Workshops.create_program(owner, %{title: "Publicável"})
      %{program: program}
    end

    test "dono publica e cancela", ctx do
      assert {:ok, %{status: :published}} = Workshops.publish_program(ctx.owner, ctx.program)
      assert {:ok, %{status: :cancelled}} = Workshops.cancel_program(ctx.owner, ctx.program)
    end

    test "outsider does not change it", ctx do
      assert {:error, :unauthorized} = Workshops.publish_program(insert(:user), ctx.program)
      assert {:error, :unauthorized} = Workshops.cancel_program(insert(:user), ctx.program)
    end
  end

  describe "program_summaries/1" do
    test "aggregates count and date range without N+1", %{owner: owner} do
      {:ok, program} = Workshops.create_program(owner, %{title: "Festival"})

      first = insert(:workshop, organizer: owner, starts_at: at_day(10, 14))
      last = insert(:workshop, organizer: owner, starts_at: at_day(12, 14))
      for w <- [first, last], do: Workshops.attach_workshop(program, owner, w.id)

      summary = Workshops.program_summaries([program.id]) |> Map.fetch!(program.id)
      assert summary.count == 2
      assert DateTime.compare(summary.starts_at, first.starts_at) == :eq
      assert DateTime.compare(summary.ends_at, last.starts_at) == :eq
    end

    test "empty program does not show up in the summary", %{owner: owner} do
      {:ok, vazia} = Workshops.create_program(owner, %{title: "Sem nada"})

      assert Workshops.program_summaries([vazia.id]) == %{}
    end
  end
end
