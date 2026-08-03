defmodule OGrupoDeEstudos.WorkshopProgramsTest do
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
    %{dono: insert(:user)}
  end

  describe "create_program/2" do
    test "cria com slug legível e sufixo", %{dono: dono} do
      assert {:ok, program} =
               Workshops.create_program(dono, %{
                 title: "Fim de semana de forró roots",
                 description: "Quinta e sexta.",
                 location: "Curitiba"
               })

      assert program.owner_id == dono.id
      assert program.status == :draft
      assert program.slug =~ ~r/^fim-de-semana-de-forro-roots-[a-z0-9]+$/
    end

    test "título é obrigatório", %{dono: dono} do
      assert {:error, %Ecto.Changeset{}} =
               Workshops.create_program(dono, %{description: "só isso"})
    end
  end

  describe "attach_workshop/3" do
    setup %{dono: dono} do
      {:ok, program} = Workshops.create_program(dono, %{title: "Meu fim de semana"})
      %{program: program, workshop: insert(:workshop, organizer: dono)}
    end

    test "quem administra os dois lados atacha", ctx do
      assert {:ok, atualizado} =
               Workshops.attach_workshop(ctx.program, ctx.dono, ctx.workshop.id)

      assert atualizado.program_id == ctx.program.id
      assert [w] = Workshops.list_program_workshops(ctx.program)
      assert w.id == ctx.workshop.id
    end

    test "co-organizador do workshop também atacha, se for dono da programação", ctx do
      # É assim que um festival funciona: a equipe vira co-organizadora do
      # workshop de cada professor e monta a programação.
      parceiro = insert(:user)
      {:ok, program_dele} = Workshops.create_program(parceiro, %{title: "Festival"})
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.dono, parceiro.id)

      assert {:ok, _} = Workshops.attach_workshop(program_dele, parceiro, ctx.workshop.id)
    end

    test "não atacha workshop que não administra", ctx do
      alheio = insert(:workshop)

      assert {:error, :unauthorized} =
               Workshops.attach_workshop(ctx.program, ctx.dono, alheio.id)
    end

    test "não atacha em programação alheia", ctx do
      assert {:error, :unauthorized} =
               Workshops.attach_workshop(ctx.program, insert(:user), ctx.workshop.id)
    end

    test "id inventado não encontra nada", ctx do
      assert {:error, :not_found} =
               Workshops.attach_workshop(ctx.program, ctx.dono, Ecto.UUID.generate())
    end

    test "detach solta o workshop sem apagá-lo", ctx do
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.dono, ctx.workshop.id)

      assert {:ok, solto} = Workshops.detach_workshop(ctx.program, ctx.dono, ctx.workshop.id)
      assert is_nil(solto.program_id)
      assert Workshops.get_workshop(ctx.workshop.id)
    end
  end

  describe "list_program_workshops/2" do
    setup %{dono: dono} do
      {:ok, program} = Workshops.create_program(dono, %{title: "Dois dias"})
      %{program: program}
    end

    test "vem em ordem de data, do mais cedo ao mais tarde", ctx do
      sexta = insert(:workshop, organizer: ctx.dono, starts_at: em(8, 20))
      quinta = insert(:workshop, organizer: ctx.dono, starts_at: em(7, 19))

      for w <- [sexta, quinta], do: Workshops.attach_workshop(ctx.program, ctx.dono, w.id)

      assert [primeiro, segundo] = Workshops.list_program_workshops(ctx.program)
      assert primeiro.id == quinta.id
      assert segundo.id == sexta.id
    end

    test "rascunho fica fora para quem só olha", ctx do
      publicado = insert(:workshop, organizer: ctx.dono)
      rascunho = insert(:workshop, organizer: ctx.dono, status: :draft)

      for w <- [publicado, rascunho], do: Workshops.attach_workshop(ctx.program, ctx.dono, w.id)

      assert [visivel] = Workshops.list_program_workshops(ctx.program)
      assert visivel.id == publicado.id

      # Quem administra precisa ver o próprio rascunho para poder publicar.
      assert length(Workshops.list_program_workshops(ctx.program, include_drafts: true)) == 2
    end

    test "cancelado continua na lista: quem se inscreveu precisa saber", ctx do
      cancelado = insert(:workshop, organizer: ctx.dono, status: :cancelled)
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.dono, cancelado.id)

      assert [w] = Workshops.list_program_workshops(ctx.program)
      assert w.status == :cancelled
    end
  end

  describe "publish_program/2 e cancel_program/2" do
    setup %{dono: dono} do
      {:ok, program} = Workshops.create_program(dono, %{title: "Publicável"})
      %{program: program}
    end

    test "dono publica e cancela", ctx do
      assert {:ok, %{status: :published}} = Workshops.publish_program(ctx.dono, ctx.program)
      assert {:ok, %{status: :cancelled}} = Workshops.cancel_program(ctx.dono, ctx.program)
    end

    test "estranho não mexe", ctx do
      assert {:error, :unauthorized} = Workshops.publish_program(insert(:user), ctx.program)
      assert {:error, :unauthorized} = Workshops.cancel_program(insert(:user), ctx.program)
    end
  end

  describe "program_summaries/1" do
    test "agrega contagem e intervalo de datas sem N+1", %{dono: dono} do
      {:ok, program} = Workshops.create_program(dono, %{title: "Festival"})

      primeiro = insert(:workshop, organizer: dono, starts_at: em(10, 14))
      ultimo = insert(:workshop, organizer: dono, starts_at: em(12, 14))
      for w <- [primeiro, ultimo], do: Workshops.attach_workshop(program, dono, w.id)

      resumo = Workshops.program_summaries([program.id]) |> Map.fetch!(program.id)
      assert resumo.count == 2
      assert DateTime.compare(resumo.starts_at, primeiro.starts_at) == :eq
      assert DateTime.compare(resumo.ends_at, ultimo.starts_at) == :eq
    end

    test "programação vazia não aparece no resumo", %{dono: dono} do
      {:ok, vazia} = Workshops.create_program(dono, %{title: "Sem nada"})

      assert Workshops.program_summaries([vazia.id]) == %{}
    end
  end
end
