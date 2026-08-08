defmodule OGrupoDeEstudos.Workers.WorkshopReminderTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory
  import Swoosh.TestAssertions

  alias OGrupoDeEstudos.{Brazil, Workshops}
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Workers.WorkshopReminder
  alias OGrupoDeEstudos.Workshops.WorkshopEnrollment

  defp tomorrow_at(hour), do: day_at(1, hour)

  defp day_at(days_ahead, hour) do
    Brazil.today()
    |> Date.add(days_ahead)
    |> DateTime.new!(Time.new!(hour, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp rodar, do: perform_job(WorkshopReminder, %{})

  # Enrollment now confirms by email; the sweep tests care about the sweep
  # emails only, so whatever the setup produced gets flushed.
  defp drain_mailbox do
    receive do
      {:email, _email} -> drain_mailbox()
    after
      0 -> :ok
    end
  end

  setup do
    owner = insert(:user)
    student = insert(:user)

    workshop =
      insert(:workshop, organizer: owner, title: "Pisada de amanhã", starts_at: tomorrow_at(20))

    {:ok, _} = Workshops.enroll(workshop, student)
    drain_mailbox()

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
        assert String.downcase(email.subject) =~ "amanhã"
        assert email.subject =~ "Pisada de amanhã"
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

  describe "teacher summary" do
    defp collect_emails(count) do
      for _ <- 1..count do
        assert_received {:email, email}
        email
      end
    end

    setup %{owner: owner, workshop: workshop} do
      teacher_user = insert(:user, name: "Profe Ana Lima")

      {:ok, _} =
        Workshops.set_teachers(workshop, owner, [
          %{user_id: teacher_user.id},
          %{display_name: "Convidado Sem Conta"}
        ])

      %{teacher_user: teacher_user}
    end

    test "organizer and account-linked teachers get the day-before summary", ctx do
      {:ok, _} = Workshops.cancel_enrollment(ctx.workshop, ctx.student)

      assert :ok = rodar()

      emails = collect_emails(2)
      recipients = Enum.map(emails, fn email -> elem(hd(email.to), 1) end)

      assert Enum.sort(recipients) == Enum.sort([ctx.owner.email, ctx.teacher_user.email])
      assert Enum.all?(emails, &(&1.subject =~ "Amanhã"))
      assert Enum.all?(emails, &(&1.subject =~ "0 inscritos"))
    end

    test "the summary carries the roster and the manage link", ctx do
      assert :ok = rodar()

      emails = collect_emails(3)
      summary = Enum.find(emails, &(&1.subject =~ "1 inscritos"))

      assert summary.html_body =~ ctx.student.name
      assert summary.text_body =~ "/workshops/#{ctx.workshop.slug}/manage"
    end

    test "running twice sends the summary only once", ctx do
      {:ok, _} = Workshops.cancel_enrollment(ctx.workshop, ctx.student)

      assert :ok = rodar()
      collect_emails(2)

      assert :ok = rodar()
      assert_no_email_sent()
    end

    test "a workshop entering the window late gets the today summary", %{owner: owner} = ctx do
      {:ok, _} = Workshops.cancel_enrollment(ctx.workshop, ctx.student)
      second_teacher = insert(:user, name: "Profe Bento Reis")

      workshop_today =
        insert(:workshop, organizer: owner, title: "Aula de hoje", starts_at: day_at(0, 23))

      {:ok, _} = Workshops.set_teachers(workshop_today, owner, [%{user_id: second_teacher.id}])

      assert :ok = rodar()

      emails = collect_emails(4)
      today_summary = Enum.find(emails, &(&1.subject =~ "Aula de hoje"))

      assert today_summary.subject =~ "Hoje"

      assert Enum.any?(emails, fn email ->
               elem(hd(email.to), 1) == second_teacher.email
             end)
    end
  end

  describe "same-day catch-up" do
    setup %{owner: owner} do
      workshop_today =
        insert(:workshop, organizer: owner, title: "Pisada de hoje", starts_at: day_at(0, 23))

      late_student = insert(:user)
      {:ok, _} = Workshops.enroll(workshop_today, late_student)
      drain_mailbox()

      %{workshop_today: workshop_today, late_student: late_student}
    end

    test "enrollment made after the day-before sweep is reminded today", ctx do
      Repo.delete_all(Notification)

      assert :ok = rodar()

      avisos = Repo.all(from n in Notification, where: n.action == :workshop_today_reminder)
      assert [aviso] = avisos
      assert aviso.user_id == ctx.late_student.id
      assert aviso.parent_id == ctx.workshop_today.id
    end

    test "the same-day email says today, with the link", ctx do
      {:ok, _} = Workshops.cancel_enrollment(ctx.workshop, ctx.student)

      assert :ok = rodar()

      emails = collect_emails(3)

      student_email =
        Enum.find(emails, fn email -> elem(hd(email.to), 1) == ctx.late_student.email end)

      assert String.downcase(student_email.subject <> student_email.text_body) =~ "hoje"
      assert student_email.text_body =~ ctx.workshop_today.slug
    end

    test "running twice reminds the late enrollment only once", _ctx do
      Repo.delete_all(Notification)

      assert :ok = rodar()
      assert :ok = rodar()

      avisos = Repo.all(from n in Notification, where: n.action == :workshop_today_reminder)
      assert length(avisos) == 1
    end
  end
end
