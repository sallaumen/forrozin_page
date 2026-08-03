defmodule OGrupoDeEstudos.ProgramEnrollmentTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Workshops

  defp em(dias, hora) do
    OGrupoDeEstudos.Brazil.today()
    |> Date.add(dias)
    |> DateTime.new!(Time.new!(hora, 0, 0), "Etc/UTC")
    |> OGrupoDeEstudos.Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  setup do
    dono = insert(:user)
    {:ok, program} = Workshops.create_program(dono, %{title: "Dois dias"})

    quinta = insert(:workshop, organizer: dono, title: "Quinta", starts_at: em(7, 19))
    sexta = insert(:workshop, organizer: dono, title: "Sexta", starts_at: em(8, 19))
    for w <- [quinta, sexta], do: Workshops.attach_workshop(program, dono, w.id)

    %{dono: dono, program: program, quinta: quinta, sexta: sexta, aluna: insert(:user)}
  end

  describe "enroll_many/3" do
    test "inscreve nos dois de uma vez", ctx do
      assert {:ok, resultado} =
               Workshops.enroll_many(ctx.program, ctx.aluna, [ctx.quinta.id, ctx.sexta.id])

      assert length(resultado.enrolled) == 2
      assert resultado.failed == []

      inscritos = Workshops.enrolled_workshop_ids(ctx.aluna.id)
      assert MapSet.member?(inscritos, ctx.quinta.id)
      assert MapSet.member?(inscritos, ctx.sexta.id)
    end

    test "um lotado não derruba os outros", ctx do
      lotado =
        insert(:workshop, organizer: ctx.dono, title: "Lotado", capacity: 1, starts_at: em(9, 19))

      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.dono, lotado.id)
      {:ok, _} = Workshops.enroll(lotado, insert(:user))

      assert {:ok, resultado} =
               Workshops.enroll_many(ctx.program, ctx.aluna, [
                 ctx.quinta.id,
                 lotado.id,
                 ctx.sexta.id
               ])

      # Quem marcou tres e perdeu uma vaga quer as outras duas, nao zero.
      assert length(resultado.enrolled) == 2
      assert [{workshop, :full}] = resultado.failed
      assert workshop.id == lotado.id
    end

    test "quem já estava inscrito conta como sucesso, não como falha", ctx do
      {:ok, _} = Workshops.enroll(ctx.quinta, ctx.aluna)

      assert {:ok, resultado} =
               Workshops.enroll_many(ctx.program, ctx.aluna, [ctx.quinta.id, ctx.sexta.id])

      # A pessoa pediu para estar inscrita nos dois, e esta.
      assert length(resultado.enrolled) == 2
      assert resultado.failed == []
    end

    test "id de workshop de outra programação é ignorado", ctx do
      alheio = insert(:workshop)

      assert {:ok, resultado} =
               Workshops.enroll_many(ctx.program, ctx.aluna, [ctx.quinta.id, alheio.id])

      assert length(resultado.enrolled) == 1
      refute MapSet.member?(Workshops.enrolled_workshop_ids(ctx.aluna.id), alheio.id)
    end

    test "id que não é uuid não quebra", ctx do
      assert {:ok, resultado} =
               Workshops.enroll_many(ctx.program, ctx.aluna, ["; drop table", ctx.quinta.id])

      assert length(resultado.enrolled) == 1
    end

    test "rascunho dentro da programação não aceita inscrição", ctx do
      rascunho = insert(:workshop, organizer: ctx.dono, status: :draft, starts_at: em(9, 19))
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.dono, rascunho.id)

      # Filtrado antes de tentar: nada inscrivel foi de fato selecionado.
      assert {:error, :none_selected} =
               Workshops.enroll_many(ctx.program, ctx.aluna, [rascunho.id])
    end

    test "rascunho no meio da lista não impede os publicados", ctx do
      rascunho = insert(:workshop, organizer: ctx.dono, status: :draft, starts_at: em(9, 19))
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.dono, rascunho.id)

      assert {:ok, resultado} =
               Workshops.enroll_many(ctx.program, ctx.aluna, [rascunho.id, ctx.quinta.id])

      assert length(resultado.enrolled) == 1
    end

    test "nada marcado devolve erro próprio", ctx do
      assert {:error, :none_selected} = Workshops.enroll_many(ctx.program, ctx.aluna, [])
    end

    test "quem organiza não se inscreve no que já é dele", ctx do
      assert {:ok, resultado} =
               Workshops.enroll_many(ctx.program, ctx.dono, [ctx.quinta.id, ctx.sexta.id])

      assert resultado.enrolled == []
      assert length(resultado.failed) == 2
      assert Enum.all?(resultado.failed, fn {_w, motivo} -> motivo == :organizer end)
    end
  end

  describe "aviso ao organizador num lote" do
    test "um aviso por pessoa, não um por workshop", ctx do
      {:ok, _} = Workshops.enroll_many(ctx.program, ctx.aluna, [ctx.quinta.id, ctx.sexta.id])

      avisos =
        Notification
        |> Repo.all()
        |> Enum.filter(&(&1.user_id == ctx.dono.id and &1.action == :workshop_enrolled))

      # Sem isso, inscrever em 3 workshops enche a caixa com 3 linhas que nem
      # colapsam, que e justamente o spam que a programacao existe para matar.
      assert length(avisos) == 1
      assert hd(avisos).group_key =~ ctx.program.id
    end

    test "cada professor é avisado do workshop dele", ctx do
      joana = insert(:user)
      dela = insert(:workshop, organizer: joana, starts_at: em(9, 19))
      {:ok, _} = Workshops.add_admin(dela, joana, ctx.dono.id)
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.dono, dela.id)

      {:ok, _} = Workshops.enroll_many(ctx.program, ctx.aluna, [ctx.quinta.id, dela.id])

      destinatarios =
        Notification
        |> Repo.all()
        |> Enum.filter(&(&1.action == :workshop_enrolled))
        |> Enum.map(& &1.user_id)
        |> MapSet.new()

      assert MapSet.member?(destinatarios, ctx.dono.id)
      assert MapSet.member?(destinatarios, joana.id)
    end

    test "lote sem nenhuma inscrição não avisa ninguém", ctx do
      Repo.delete_all(Notification)

      {:ok, _} = Workshops.enroll_many(ctx.program, ctx.dono, [ctx.quinta.id])

      assert Repo.all(Notification) == []
    end
  end
end
