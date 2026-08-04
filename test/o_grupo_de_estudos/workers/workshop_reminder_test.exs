defmodule OGrupoDeEstudos.Workers.WorkshopReminderTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory
  import Swoosh.TestAssertions

  alias OGrupoDeEstudos.{Brazil, Workshops}
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Workers.WorkshopReminder
  alias OGrupoDeEstudos.Workshops.WorkshopEnrollment

  defp tomorrow_at(hour) do
    Brazil.today()
    |> Date.add(1)
    |> DateTime.new!(Time.new!(hour, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp rodar, do: perform_job(WorkshopReminder, %{})

  setup do
    owner = insert(:user)
    student = insert(:user)

    workshop =
      insert(:workshop, organizer: owner, title: "Pisada de amanhã", starts_at: tomorrow_at(20))

    {:ok, _} = Workshops.enroll(workshop, student)

    %{owner: owner, student: student, workshop: workshop}
  end

  describe "day-before reminder" do
    test "notifies whoever has a workshop tomorrow", ctx do
      Repo.delete_all(Notification)

      assert :ok = rodar()

      assert [aviso] = Repo.all(from n in Notification, where: n.action == :workshop_reminder)
      assert aviso.user_id == ctx.student.id
      assert aviso.actor_id == ctx.owner.id
      assert aviso.parent_id == ctx.workshop.id
    end

    test "sends the email with the title and the link", ctx do
      assert :ok = rodar()

      assert_email_sent(fn email ->
        assert email.subject == "Amanhã tem Pisada de amanhã"
        assert {_, endereco} = hd(email.to)
        assert endereco == ctx.student.email
        assert email.text_body =~ ctx.workshop.slug
      end)
    end

    test "running twice on the same day notifies only once", ctx do
      Repo.delete_all(Notification)

      assert :ok = rodar()
      assert :ok = rodar()

      avisos = Repo.all(from n in Notification, where: n.action == :workshop_reminder)
      assert length(avisos) == 1
      assert Repo.get!(WorkshopEnrollment, hd(Repo.all(WorkshopEnrollment)).id).reminded_at
      assert ctx.student
    end

    test "workshop two days out is not notified yet", %{owner: owner} do
      later =
        insert(:workshop,
          organizer: owner,
          title: "Só semana que vem",
          starts_at: DateTime.add(tomorrow_at(20), 5 * 86_400, :second)
        )

      {:ok, _} = Workshops.enroll(later, insert(:user))
      Repo.delete_all(Notification)

      assert :ok = rodar()

      titulos =
        Notification
        |> Repo.all()
        |> Enum.filter(&(&1.action == :workshop_reminder))
        |> Enum.map(& &1.parent_id)

      refute later.id in titulos
    end

    test "workshop cancelled afterwards generates no reminder", ctx do
      {:ok, _} = Workshops.cancel_workshop(ctx.owner, ctx.workshop)
      Repo.delete_all(Notification)

      assert :ok = rodar()

      assert Repo.all(from n in Notification, where: n.action == :workshop_reminder) == []
    end

    test "user who cancelled the enrollment does not receive it", ctx do
      {:ok, _} = Workshops.cancel_enrollment(ctx.workshop, ctx.student)
      Repo.delete_all(Notification)

      assert :ok = rodar()

      assert Repo.all(from n in Notification, where: n.action == :workshop_reminder) == []
    end

    test "draft workshop notifies nobody", %{owner: owner} do
      draft =
        insert(:workshop, organizer: owner, status: :draft, starts_at: tomorrow_at(20))

      Repo.insert!(%WorkshopEnrollment{workshop_id: draft.id, user_id: insert(:user).id})
      Repo.delete_all(Notification)

      assert :ok = rodar()

      avisos =
        Notification
        |> Repo.all()
        |> Enum.filter(&(&1.action == :workshop_reminder and &1.parent_id == draft.id))

      assert avisos == []
    end

    test "explicit day in the args allows resending a specific day", ctx do
      Repo.delete_all(Notification)
      day = ctx.workshop.starts_at |> Brazil.to_local() |> DateTime.to_date()

      assert :ok = perform_job(WorkshopReminder, %{"dia" => Date.to_iso8601(day)})

      assert [_] = Repo.all(from n in Notification, where: n.action == :workshop_reminder)
    end

    test "runs clean with nobody to notify", %{workshop: workshop, student: student} do
      {:ok, _} = Workshops.cancel_enrollment(workshop, student)

      assert :ok = rodar()
    end
  end
end
