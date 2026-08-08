defmodule OGrupoDeEstudos.EnrollmentConfirmationTest do
  @moduledoc """
  Every way into a class confirms by email, once: the direct enrollment
  gets the workshop email, the package and the multi-pick get one email
  listing what was covered, and the waitlist promotion keeps its own
  good-news email instead of a second confirmation.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.{Brazil, Workshops}

  defp at_day(days, hour) do
    Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(Time.new!(hour, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp all_emails do
    receive do
      {:email, email} -> [email | all_emails()]
    after
      0 -> []
    end
  end

  defp emails_to(address) do
    Enum.filter(all_emails(), fn email -> elem(hd(email.to), 1) == address end)
  end

  setup do
    %{owner: insert(:user), student: insert(:user)}
  end

  describe "direct workshop enrollment" do
    test "confirms by email with the workshop details", ctx do
      workshop =
        insert(:workshop,
          organizer: ctx.owner,
          title: "Pisada e Condução",
          starts_at: at_day(7, 19),
          price_cents: 8000,
          payment_info: "Pix: forro@exemplo.com"
        )

      {:ok, _} = Workshops.enroll(workshop, ctx.student)

      assert [email] = emails_to(ctx.student.email)
      assert email.subject =~ "Inscrição confirmada"
      assert email.subject =~ "Pisada e Condução"
      assert email.text_body =~ workshop.slug
      assert email.text_body =~ "R$ 80"
      assert email.text_body =~ "Pix: forro@exemplo.com"
    end

    test "leaving and coming back on the same day does not repeat the confirmation", ctx do
      workshop = insert(:workshop, organizer: ctx.owner, starts_at: at_day(7, 19))

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _} = Workshops.enroll(workshop, ctx.student)
        {:ok, _} = Workshops.cancel_enrollment(workshop, ctx.student)
        {:ok, _} = Workshops.enroll(workshop, ctx.student)

        assert [_only_one] =
                 all_enqueued(worker: OGrupoDeEstudos.Workers.SendWorkshopEnrolledEmail)
      end)
    end

    test "a full class promoting from the waitlist sends the good news, not a second confirmation",
         ctx do
      workshop = insert(:workshop, organizer: ctx.owner, capacity: 1, starts_at: at_day(7, 19))
      {:ok, _} = Workshops.enroll(workshop, ctx.student)
      waiting = insert(:user)
      {:ok, _} = Workshops.join_waitlist(workshop, waiting)

      {:ok, _} = Workshops.cancel_enrollment(workshop, ctx.student)

      assert [email] = emails_to(waiting.email)
      refute email.subject =~ "Inscrição confirmada"
      assert email.text_body =~ "lista de espera"
    end
  end

  describe "program enrollment" do
    setup ctx do
      {:ok, program} =
        Workshops.create_program(ctx.owner, %{title: "Três dias de forró", price_cents: 15_000})

      workshops =
        for day <- [7, 8] do
          insert(:workshop,
            organizer: ctx.owner,
            title: "Aula do dia #{day}",
            starts_at: at_day(day, 19)
          )
        end

      for w <- workshops, do: Workshops.attach_workshop(program, ctx.owner, w.id)
      {:ok, program} = Workshops.publish_program(ctx.owner, program)

      %{program: program, workshops: workshops}
    end

    test "the package sends one email listing every covered workshop", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, ctx.student)

      assert [email] = emails_to(ctx.student.email)
      assert email.subject =~ "Inscrição confirmada"
      assert email.subject =~ "Três dias de forró"
      assert email.text_body =~ "Aula do dia 7"
      assert email.text_body =~ "Aula do dia 8"
    end

    test "picking workshops by hand sends one email with the chosen ones", ctx do
      [first, second] = ctx.workshops

      {:ok, %{enrolled: [_, _]}} =
        Workshops.enroll_many(ctx.program, ctx.student, [first.id, second.id])

      assert [email] = emails_to(ctx.student.email)
      assert email.subject =~ "Inscrição confirmada"
      assert email.text_body =~ first.title
      assert email.text_body =~ second.title
    end
  end
end
