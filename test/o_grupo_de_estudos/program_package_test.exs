defmodule OGrupoDeEstudos.ProgramPackageTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

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

    {:ok, program} =
      Workshops.create_program(dono, %{
        title: "Três dias",
        price_cents: 15_000,
        payment_info: "Pix do festival"
      })

    workshops =
      for {dia, preco} <- [{7, 6000}, {8, 6000}, {9, 6000}] do
        insert(:workshop, organizer: dono, starts_at: em(dia, 19), price_cents: preco)
      end

    for w <- workshops, do: Workshops.attach_workshop(program, dono, w.id)
    {:ok, program} = Workshops.publish_program(dono, program)

    %{dono: dono, program: program, workshops: workshops, aluna: insert(:user)}
  end

  describe "enroll_in_package/2" do
    test "entra em todos os workshops de uma vez", ctx do
      assert {:ok, matricula} = Workshops.enroll_in_package(ctx.program, ctx.aluna)

      assert matricula.payment_status == :pending
      inscritos = Workshops.enrolled_workshop_ids(ctx.aluna.id)
      assert Enum.all?(ctx.workshops, &MapSet.member?(inscritos, &1.id))
    end

    test "as inscrições apontam para o pacote, então não se cobra duas vezes", ctx do
      {:ok, matricula} = Workshops.enroll_in_package(ctx.program, ctx.aluna)

      cobertas =
        ctx.workshops
        |> Enum.map(&Workshops.get_enrollment(&1.id, ctx.aluna.id))
        |> Enum.map(& &1.program_enrollment_id)

      assert Enum.all?(cobertas, &(&1 == matricula.id))
    end

    test "programação sem preço de pacote não vende pacote", %{dono: dono, aluna: aluna} do
      {:ok, sem_preco} = Workshops.create_program(dono, %{title: "Só avulso"})
      w = insert(:workshop, organizer: dono, starts_at: em(7, 19))
      {:ok, _} = Workshops.attach_workshop(sem_preco, dono, w.id)
      {:ok, sem_preco} = Workshops.publish_program(dono, sem_preco)

      assert {:error, :no_package} = Workshops.enroll_in_package(sem_preco, aluna)
    end

    test "uma turma lotada cancela o pacote inteiro e não deixa rastro", ctx do
      [primeiro, _, terceiro] = ctx.workshops
      {:ok, lotado} = Workshops.update_workshop(ctx.dono, terceiro, %{capacity: 1})
      {:ok, _} = Workshops.enroll(lotado, insert(:user))

      # Pagou pelos tres: entrar em dois seria errado.
      assert {:error, {:full, workshop}} = Workshops.enroll_in_package(ctx.program, ctx.aluna)
      assert workshop.id == terceiro.id

      # E nao pode sobrar inscricao solta das que deram certo antes de falhar.
      inscritos = Workshops.enrolled_workshop_ids(ctx.aluna.id)
      refute MapSet.member?(inscritos, primeiro.id)
      assert Workshops.list_package_enrollments(ctx.program, ctx.dono) == {:ok, []}
    end

    test "quem já comprou não compra de novo", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, ctx.aluna)

      assert {:error, :already_enrolled} = Workshops.enroll_in_package(ctx.program, ctx.aluna)
    end

    test "quem organiza não compra pacote do próprio evento", ctx do
      assert {:error, :organizer} = Workshops.enroll_in_package(ctx.program, ctx.dono)
    end

    test "quem já estava avulso em um vira pacote sem duplicar inscrição", ctx do
      [primeiro | _] = ctx.workshops
      {:ok, _} = Workshops.enroll(primeiro, ctx.aluna)

      assert {:ok, matricula} = Workshops.enroll_in_package(ctx.program, ctx.aluna)

      inscricao = Workshops.get_enrollment(primeiro.id, ctx.aluna.id)
      assert inscricao.program_enrollment_id == matricula.id
      assert length(Workshops.list_participants(primeiro.id)) == 1
    end
  end

  describe "painel do pacote" do
    test "organizador vê quem comprou e marca como pago", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, ctx.aluna)

      assert {:ok, [linha]} = Workshops.list_package_enrollments(ctx.program, ctx.dono)
      assert linha.name == ctx.aluna.name
      assert linha.payment_status == :pending

      assert {:ok, _} =
               Workshops.set_package_payment(ctx.program, ctx.dono, linha.id, :paid)

      assert {:ok, [atualizada]} = Workshops.list_package_enrollments(ctx.program, ctx.dono)
      assert atualizada.payment_status == :paid
    end

    test "resumo separa pacote de avulso", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, ctx.aluna)
      avulsa = insert(:user)
      {:ok, _} = Workshops.enroll(hd(ctx.workshops), avulsa)

      assert {:ok, resumo} = Workshops.package_summary(ctx.program, ctx.dono)

      assert resumo.packages == 1
      assert resumo.paid == 0
      assert resumo.revenue_cents == 0
    end

    test "receita do pacote conta só quem pagou", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, ctx.aluna)
      {:ok, [linha]} = Workshops.list_package_enrollments(ctx.program, ctx.dono)
      {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.dono, linha.id, :paid)

      assert {:ok, %{paid: 1, revenue_cents: 15_000}} =
               Workshops.package_summary(ctx.program, ctx.dono)
    end

    test "estranho não vê nem mexe no pagamento do pacote", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, ctx.aluna)
      estranho = insert(:user)

      assert {:error, :unauthorized} =
               Workshops.list_package_enrollments(ctx.program, estranho)

      assert {:error, :unauthorized} = Workshops.package_summary(ctx.program, estranho)

      assert {:error, :unauthorized} =
               Workshops.set_package_payment(ctx.program, estranho, Ecto.UUID.generate(), :paid)
    end

    test "co-organizador do workshop não vê o pagamento do pacote alheio", ctx do
      # O pacote e da programacao: quem manda nele e quem criou a programacao.
      parceiro = insert(:user)
      {:ok, _} = Workshops.add_admin(hd(ctx.workshops), ctx.dono, parceiro.id)

      assert {:error, :unauthorized} =
               Workshops.list_package_enrollments(ctx.program, parceiro)
    end
  end

  describe "inscrição individual continua funcionando ao lado do pacote" do
    test "avulso não ganha matrícula de pacote", ctx do
      {:ok, _} = Workshops.enroll(hd(ctx.workshops), ctx.aluna)

      inscricao = Workshops.get_enrollment(hd(ctx.workshops).id, ctx.aluna.id)
      assert is_nil(inscricao.program_enrollment_id)
    end

    test "o painel do workshop distingue quem está pelo pacote", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.program, ctx.aluna)
      avulsa = insert(:user)
      {:ok, _} = Workshops.enroll(hd(ctx.workshops), avulsa)

      {:ok, linhas} = Workshops.list_enrollments_for_organizer(hd(ctx.workshops), ctx.dono)

      pelo_pacote = Enum.find(linhas, &(&1.user.id == ctx.aluna.id))
      assert pelo_pacote.program_enrollment_id

      individual = Enum.find(linhas, &(&1.user.id == avulsa.id))
      assert is_nil(individual.program_enrollment_id)
    end
  end
end
