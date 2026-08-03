defmodule OGrupoDeEstudos.WorkshopWaitlistTest do
  @moduledoc """
  Turma cheia deixa de ser beco sem saída.

  A regra tem um eixo só: **onde a inscrição é automática, o limite vale e
  forma fila; onde tem gente decidindo cada entrada, dá para passar do
  limite**. Turma cheia sem fila perdia de vista quem tinha interesse, que é
  justamente o sinal de que cabe abrir outra turma.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Workshops

  defp lotar(workshop, quantos \\ 1) do
    for _ <- 1..quantos, do: {:ok, _} = Workshops.enroll(workshop, insert(:user))
    workshop
  end

  setup do
    dono = insert(:user)

    %{
      dono: dono,
      # Uma vaga só: fica cheio com uma inscrição.
      gratis: insert(:workshop, organizer: dono, capacity: 1, price_cents: 0),
      pago: insert(:workshop, organizer: dono, capacity: 1, price_cents: 18_000),
      privado: insert(:workshop, organizer: dono, capacity: 1, visibility: :private),
      aluna: insert(:user)
    }
  end

  describe "turma automática: o limite vale" do
    test "grátis lotada não aceita inscrição direta", ctx do
      lotar(ctx.gratis)

      assert {:error, :full} = Workshops.enroll(ctx.gratis, ctx.aluna)
    end

    test "paga lotada também não: ninguém paga por vaga que não existe", ctx do
      lotar(ctx.pago)

      assert {:error, :full} = Workshops.enroll(ctx.pago, ctx.aluna)
    end

    test "sem limite definido, entra todo mundo", ctx do
      sem_limite = insert(:workshop, organizer: ctx.dono, capacity: nil)
      lotar(sem_limite, 5)

      assert {:ok, _} = Workshops.enroll(sem_limite, ctx.aluna)
    end
  end

  describe "turma com aceite do professor: pode passar do limite" do
    test "aprovar passa do limite em vez de recusar", ctx do
      # Overbooking é decisão de quem dá a aula: ela sabe se cabe mais um na
      # sala. O que o sistema não pode é decidir isso sozinho.
      lotar(ctx.privado)
      {:ok, _} = Workshops.request_join(ctx.privado, ctx.aluna)
      [pedido] = Workshops.list_pending_requests(ctx.privado)

      assert {:ok, _} = Workshops.approve_join(ctx.privado, ctx.dono, pedido.id)
      assert Workshops.count_enrollments(ctx.privado.id) == 2
    end

    test "a página avisa quem organiza que vai passar do limite", ctx do
      lotar(ctx.privado)

      assert Workshops.passaria_do_limite?(ctx.privado)
    end

    test "com vaga sobrando, não avisa nada", ctx do
      refute Workshops.passaria_do_limite?(ctx.privado)
    end
  end

  describe "entrar na fila" do
    test "quem chega depois do limite entra na lista de espera", ctx do
      lotar(ctx.gratis)

      assert {:ok, _} = Workshops.join_waitlist(ctx.gratis, ctx.aluna)
      assert Workshops.waitlist_position(ctx.gratis, ctx.aluna) == 1
      assert Workshops.waitlist_count(ctx.gratis.id) == 1
    end

    test "a fila respeita a ordem de chegada", ctx do
      lotar(ctx.gratis)
      primeira = insert(:user)
      {:ok, _} = Workshops.join_waitlist(ctx.gratis, primeira)
      {:ok, _} = Workshops.join_waitlist(ctx.gratis, ctx.aluna)

      assert Workshops.waitlist_position(ctx.gratis, primeira) == 1
      assert Workshops.waitlist_position(ctx.gratis, ctx.aluna) == 2
    end

    test "com vaga sobrando não faz sentido esperar: inscreve", ctx do
      assert {:error, :has_room} = Workshops.join_waitlist(ctx.gratis, ctx.aluna)
    end

    test "quem já está inscrito não entra na própria fila", ctx do
      # A turma está cheia porque foi ela quem ocupou a última vaga: esperar
      # por um lugar que já é seu não faz sentido nenhum.
      {:ok, _} = Workshops.enroll(ctx.gratis, ctx.aluna)

      assert {:error, :already_enrolled} = Workshops.join_waitlist(ctx.gratis, ctx.aluna)
    end

    test "entrar duas vezes não duplica o lugar", ctx do
      lotar(ctx.gratis)
      {:ok, _} = Workshops.join_waitlist(ctx.gratis, ctx.aluna)

      assert {:error, :already_waiting} = Workshops.join_waitlist(ctx.gratis, ctx.aluna)
      assert Workshops.waitlist_count(ctx.gratis.id) == 1
    end

    test "dá para desistir da fila", ctx do
      lotar(ctx.gratis)
      {:ok, _} = Workshops.join_waitlist(ctx.gratis, ctx.aluna)

      assert {:ok, _} = Workshops.leave_waitlist(ctx.gratis, ctx.aluna)
      assert is_nil(Workshops.waitlist_position(ctx.gratis, ctx.aluna))
    end

    test "visitante sem conta não entra na fila", ctx do
      lotar(ctx.gratis)

      assert {:error, :unauthorized} = Workshops.join_waitlist(ctx.gratis, nil)
    end
  end

  describe "a fila anda quando abre vaga" do
    setup ctx do
      inscrita = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.gratis, inscrita)
      {:ok, _} = Workshops.join_waitlist(ctx.gratis, ctx.aluna)
      Map.put(ctx, :inscrita, inscrita)
    end

    test "cancelar promove quem está esperando há mais tempo", ctx do
      {:ok, _} = Workshops.cancel_enrollment(ctx.gratis, ctx.inscrita)

      assert MapSet.member?(Workshops.enrolled_workshop_ids(ctx.aluna.id), ctx.gratis.id)
      assert is_nil(Workshops.waitlist_position(ctx.gratis, ctx.aluna))
    end

    test "quem foi promovido é avisado: ninguém fica sabendo por acaso", ctx do
      Repo.delete_all(Notification)
      {:ok, _} = Workshops.cancel_enrollment(ctx.gratis, ctx.inscrita)

      assert [aviso] = Repo.all(from n in Notification, where: n.user_id == ^ctx.aluna.id)
      assert aviso.action == :workshop_waitlist_promoted
    end

    test "promove UMA pessoa por vaga, não a fila inteira", ctx do
      segunda = insert(:user)
      {:ok, _} = Workshops.join_waitlist(ctx.gratis, segunda)

      {:ok, _} = Workshops.cancel_enrollment(ctx.gratis, ctx.inscrita)

      assert Workshops.count_enrollments(ctx.gratis.id) == 1
      assert Workshops.waitlist_position(ctx.gratis, segunda) == 1
    end

    test "sem ninguém esperando, cancelar só libera a vaga", ctx do
      {:ok, _} = Workshops.leave_waitlist(ctx.gratis, ctx.aluna)

      assert {:ok, _} = Workshops.cancel_enrollment(ctx.gratis, ctx.inscrita)
      assert Workshops.count_enrollments(ctx.gratis.id) == 0
    end
  end

  describe "a demanda que quem organiza enxerga" do
    test "lista quem está esperando, em ordem", ctx do
      lotar(ctx.gratis)
      {:ok, _} = Workshops.join_waitlist(ctx.gratis, insert(:user, name: "Primeira Fila"))
      {:ok, _} = Workshops.join_waitlist(ctx.gratis, insert(:user, name: "Segunda Fila"))

      assert [primeira, segunda] = Workshops.list_waitlist(ctx.gratis.id)
      assert primeira.name == "Primeira Fila"
      assert segunda.name == "Segunda Fila"
    end
  end
end
