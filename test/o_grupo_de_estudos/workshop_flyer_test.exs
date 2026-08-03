defmodule OGrupoDeEstudos.WorkshopFlyerTest do
  # async: false — troca :uploads_path, que é config global do app.
  use OGrupoDeEstudos.DataCase, async: false

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  # 1x1 PNG de verdade: o Mogrify precisa de bytes que sejam imagem.
  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    dir = Path.join(System.tmp_dir!(), "flyer_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    anterior = Application.get_env(:o_grupo_de_estudos, :uploads_path)
    Application.put_env(:o_grupo_de_estudos, :uploads_path, dir)

    on_exit(fn ->
      case anterior do
        nil -> Application.delete_env(:o_grupo_de_estudos, :uploads_path)
        valor -> Application.put_env(:o_grupo_de_estudos, :uploads_path, valor)
      end

      File.rm_rf!(dir)
    end)

    origem = Path.join(dir, "origem.png")
    File.write!(origem, @png)

    dono = insert(:user)
    %{dir: dir, origem: origem, dono: dono, workshop: insert(:workshop, organizer: dono)}
  end

  defp caminho_no_disco(dir, "/uploads/" <> relativo), do: Path.join(dir, relativo)

  describe "put_workshop_flyer/4" do
    test "guarda o arquivo e aponta a coluna para ele", ctx do
      assert {:ok, atualizado} =
               Workshops.put_workshop_flyer(ctx.workshop, ctx.dono, ctx.origem, ".png")

      assert atualizado.flyer_path =~
               ~r{^/uploads/flyers/workshops/#{ctx.workshop.id}/[A-Za-z0-9]+\.png$}

      assert File.exists?(caminho_no_disco(ctx.dir, atualizado.flyer_path))
    end

    test "a pasta organiza por workshop; o nome continua não adivinhável", ctx do
      # O id do workshop na pasta não abre nada (rota é por slug) e deixa o
      # bucket navegável por contexto. O que protege de varredura é o nome
      # aleatório, e o id de quem organiza continua fora da URL.
      {:ok, atualizado} = Workshops.put_workshop_flyer(ctx.workshop, ctx.dono, ctx.origem, ".png")

      assert atualizado.flyer_path =~ "flyers/workshops/#{ctx.workshop.id}/"
      refute atualizado.flyer_path =~ ctx.dono.id
    end

    test "trocar o flyer apaga o anterior em vez de acumular lixo", ctx do
      {:ok, com_primeiro} =
        Workshops.put_workshop_flyer(ctx.workshop, ctx.dono, ctx.origem, ".png")

      primeiro = caminho_no_disco(ctx.dir, com_primeiro.flyer_path)

      {:ok, com_segundo} =
        Workshops.put_workshop_flyer(com_primeiro, ctx.dono, ctx.origem, ".png")

      refute File.exists?(primeiro)
      assert File.exists?(caminho_no_disco(ctx.dir, com_segundo.flyer_path))
    end

    test "co-organizador também põe flyer", ctx do
      parceiro = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.dono, parceiro.id)

      assert {:ok, _} = Workshops.put_workshop_flyer(ctx.workshop, parceiro, ctx.origem, ".png")
    end

    test "estranho não põe flyer no workshop alheio", ctx do
      assert {:error, :unauthorized} =
               Workshops.put_workshop_flyer(ctx.workshop, insert(:user), ctx.origem, ".png")
    end
  end

  describe "remove_workshop_flyer/2" do
    test "tira a referência e apaga o arquivo", ctx do
      {:ok, com_flyer} = Workshops.put_workshop_flyer(ctx.workshop, ctx.dono, ctx.origem, ".png")
      arquivo = caminho_no_disco(ctx.dir, com_flyer.flyer_path)

      assert {:ok, sem_flyer} = Workshops.remove_workshop_flyer(com_flyer, ctx.dono)

      assert is_nil(sem_flyer.flyer_path)
      refute File.exists?(arquivo)
    end

    test "tirar quando não tem não quebra", ctx do
      assert {:ok, %{flyer_path: nil}} =
               Workshops.remove_workshop_flyer(ctx.workshop, ctx.dono)
    end

    test "estranho não tira flyer alheio", ctx do
      {:ok, com_flyer} = Workshops.put_workshop_flyer(ctx.workshop, ctx.dono, ctx.origem, ".png")

      assert {:error, :unauthorized} =
               Workshops.remove_workshop_flyer(com_flyer, insert(:user))
    end
  end

  describe "flyer da programação" do
    setup %{dono: dono} do
      {:ok, program} = Workshops.create_program(dono, %{title: "Festival com cartaz"})
      %{program: program}
    end

    test "dono põe e tira", ctx do
      assert {:ok, com_flyer} =
               Workshops.put_program_flyer(ctx.program, ctx.dono, ctx.origem, ".png")

      assert com_flyer.flyer_path =~ "/uploads/flyers/programas/#{ctx.program.id}/"
      arquivo = caminho_no_disco(ctx.dir, com_flyer.flyer_path)
      assert File.exists?(arquivo)

      assert {:ok, %{flyer_path: nil}} = Workshops.remove_program_flyer(com_flyer, ctx.dono)
      refute File.exists?(arquivo)
    end

    test "estranho não mexe", ctx do
      assert {:error, :unauthorized} =
               Workshops.put_program_flyer(ctx.program, insert(:user), ctx.origem, ".png")
    end
  end
end
