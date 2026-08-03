defmodule OGrupoDeEstudos.Workers.WorkshopReminderTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory
  import Swoosh.TestAssertions

  alias OGrupoDeEstudos.{Brazil, Workshops}
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Workers.WorkshopReminder
  alias OGrupoDeEstudos.Workshops.WorkshopEnrollment

  defp amanha_as(hora) do
    Brazil.today()
    |> Date.add(1)
    |> DateTime.new!(Time.new!(hora, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp rodar, do: perform_job(WorkshopReminder, %{})

  setup do
    dono = insert(:user)
    aluna = insert(:user)

    workshop =
      insert(:workshop, organizer: dono, title: "Pisada de amanhã", starts_at: amanha_as(20))

    {:ok, _} = Workshops.enroll(workshop, aluna)

    %{dono: dono, aluna: aluna, workshop: workshop}
  end

  describe "aviso de véspera" do
    test "avisa quem tem workshop amanhã", ctx do
      Repo.delete_all(Notification)

      assert :ok = rodar()

      assert [aviso] = Repo.all(from n in Notification, where: n.action == :workshop_reminder)
      assert aviso.user_id == ctx.aluna.id
      assert aviso.actor_id == ctx.dono.id
      assert aviso.parent_id == ctx.workshop.id
    end

    test "manda o email com o título e o link", ctx do
      assert :ok = rodar()

      assert_email_sent(fn email ->
        assert email.subject == "Amanhã tem Pisada de amanhã"
        assert {_, endereco} = hd(email.to)
        assert endereco == ctx.aluna.email
        assert email.text_body =~ ctx.workshop.slug
      end)
    end

    test "rodar duas vezes no mesmo dia não avisa duas", ctx do
      Repo.delete_all(Notification)

      assert :ok = rodar()
      assert :ok = rodar()

      avisos = Repo.all(from n in Notification, where: n.action == :workshop_reminder)
      assert length(avisos) == 1
      assert Repo.get!(WorkshopEnrollment, hd(Repo.all(WorkshopEnrollment)).id).reminded_at
      assert ctx.aluna
    end

    test "workshop de depois de amanhã ainda não é avisado", %{dono: dono} do
      depois =
        insert(:workshop,
          organizer: dono,
          title: "Só semana que vem",
          starts_at: DateTime.add(amanha_as(20), 5 * 86_400, :second)
        )

      {:ok, _} = Workshops.enroll(depois, insert(:user))
      Repo.delete_all(Notification)

      assert :ok = rodar()

      titulos =
        Notification
        |> Repo.all()
        |> Enum.filter(&(&1.action == :workshop_reminder))
        |> Enum.map(& &1.parent_id)

      refute depois.id in titulos
    end

    test "workshop cancelado depois não gera aviso", ctx do
      {:ok, _} = Workshops.cancel_workshop(ctx.dono, ctx.workshop)
      Repo.delete_all(Notification)

      assert :ok = rodar()

      # Nada foi agendado la atras, entao nao ha job zumbi: a varredura le o
      # estado de agora.
      assert Repo.all(from n in Notification, where: n.action == :workshop_reminder) == []
    end

    test "quem cancelou a inscrição não recebe", ctx do
      {:ok, _} = Workshops.cancel_enrollment(ctx.workshop, ctx.aluna)
      Repo.delete_all(Notification)

      assert :ok = rodar()

      assert Repo.all(from n in Notification, where: n.action == :workshop_reminder) == []
    end

    test "workshop em rascunho não avisa ninguém", %{dono: dono} do
      rascunho =
        insert(:workshop, organizer: dono, status: :draft, starts_at: amanha_as(20))

      Repo.insert!(%WorkshopEnrollment{workshop_id: rascunho.id, user_id: insert(:user).id})
      Repo.delete_all(Notification)

      assert :ok = rodar()

      avisos =
        Notification
        |> Repo.all()
        |> Enum.filter(&(&1.action == :workshop_reminder and &1.parent_id == rascunho.id))

      assert avisos == []
    end

    test "dia explícito nos args permite reenviar um dia específico", ctx do
      Repo.delete_all(Notification)
      dia = ctx.workshop.starts_at |> Brazil.to_local() |> DateTime.to_date()

      assert :ok = perform_job(WorkshopReminder, %{"dia" => Date.to_iso8601(dia)})

      assert [_] = Repo.all(from n in Notification, where: n.action == :workshop_reminder)
    end

    test "sem ninguém para avisar, roda limpo", %{workshop: workshop, aluna: aluna} do
      {:ok, _} = Workshops.cancel_enrollment(workshop, aluna)

      assert :ok = rodar()
    end
  end
end
