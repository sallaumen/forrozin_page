defmodule OGrupoDeEstudos.WorkshopStepsTest do
  @moduledoc """
  Os passos que foram dados no workshop.

  Não existia relação nenhuma entre workshop e passo do acervo: quem saía de
  um workshop com cinco passos na cabeça não tinha onde registrar isso, e o
  acervo seguia sendo uma ilha.

  Quem administra monta a lista. Curadoria por like foi considerada e
  descartada: ordenar por voto resolve, com muito mais peça, um problema que a
  permissão já resolve.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  setup do
    dono = insert(:user)

    %{
      dono: dono,
      workshop: insert(:workshop, organizer: dono),
      passo: insert(:step, code: "IV", name: "Inversão base"),
      outro: insert(:step, code: "SC", name: "Sacada simples")
    }
  end

  describe "montar a lista" do
    test "quem organiza adiciona", ctx do
      assert {:ok, _} = Workshops.add_step(ctx.workshop, ctx.dono, ctx.passo.id)

      assert [passo] = Workshops.list_steps(ctx.workshop.id)
      assert passo.code == "IV"
      assert passo.name == "Inversão base"
    end

    test "a ordem é a que quem dá a aula montou, não alfabética", ctx do
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.dono, ctx.outro.id)
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.dono, ctx.passo.id)

      assert ["SC", "IV"] = Enum.map(Workshops.list_steps(ctx.workshop.id), & &1.code)
    end

    test "o mesmo passo não entra duas vezes", ctx do
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.dono, ctx.passo.id)

      assert {:error, :already_added} = Workshops.add_step(ctx.workshop, ctx.dono, ctx.passo.id)
      assert length(Workshops.list_steps(ctx.workshop.id)) == 1
    end

    test "co-organizador também monta", ctx do
      parceiro = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.dono, parceiro.id)

      assert {:ok, _} = Workshops.add_step(ctx.workshop, parceiro, ctx.passo.id)
    end

    test "quem só está inscrito não mexe na lista", ctx do
      aluna = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, aluna)

      assert {:error, :unauthorized} = Workshops.add_step(ctx.workshop, aluna, ctx.passo.id)
    end

    test "tirar da lista", ctx do
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.dono, ctx.passo.id)

      assert {:ok, _} = Workshops.remove_step(ctx.workshop, ctx.dono, ctx.passo.id)
      assert Workshops.list_steps(ctx.workshop.id) == []
    end

    test "estranho não tira", ctx do
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.dono, ctx.passo.id)

      assert {:error, :unauthorized} =
               Workshops.remove_step(ctx.workshop, insert(:user), ctx.passo.id)
    end

    test "passo que não existe não entra", ctx do
      assert {:error, :not_found} =
               Workshops.add_step(ctx.workshop, ctx.dono, Ecto.UUID.generate())
    end

    test "id inválido não quebra", ctx do
      assert {:error, :not_found} = Workshops.add_step(ctx.workshop, ctx.dono, "nao-e-uuid")
    end
  end

  describe "o caminho de volta" do
    test "diz em que workshops a pessoa viu este passo", ctx do
      aluna = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, aluna)
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.dono, ctx.passo.id)

      assert [visto] = Workshops.workshops_where_seen(aluna.id, ctx.passo.id)
      assert visto.title == ctx.workshop.title
      assert visto.slug == ctx.workshop.slug
    end

    test "só conta workshop em que a pessoa esteve", ctx do
      estranha = insert(:user)
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.dono, ctx.passo.id)

      # O passo foi dado, mas não para ela: dizer "você viu" seria mentira.
      assert Workshops.workshops_where_seen(estranha.id, ctx.passo.id) == []
    end

    test "quem organiza também vê o próprio workshop no caminho de volta", ctx do
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.dono, ctx.passo.id)

      assert [_visto] = Workshops.workshops_where_seen(ctx.dono.id, ctx.passo.id)
    end

    test "visitante sem conta não tem histórico", ctx do
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.dono, ctx.passo.id)

      assert Workshops.workshops_where_seen(nil, ctx.passo.id) == []
    end
  end
end
