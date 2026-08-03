defmodule OGrupoDeEstudos.WorkshopMediaTest do
  # async: false — troca :uploads_path, que é config global.
  use OGrupoDeEstudos.DataCase, async: false

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    dir = Path.join(System.tmp_dir!(), "media_test_#{System.unique_integer([:positive])}")
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
    aluna = insert(:user)
    workshop = insert(:workshop, organizer: dono)
    {:ok, _} = Workshops.enroll(workshop, aluna)

    %{dir: dir, origem: origem, dono: dono, aluna: aluna, workshop: workshop}
  end

  defp foto(ctx),
    do: %{tmp_path: ctx.origem, content_type: "image/png", byte_size: byte_size(@png)}

  defp video(ctx),
    do: %{tmp_path: ctx.origem, content_type: "video/mp4", byte_size: 5_000_000}

  describe "quem pode ver a galeria" do
    test "quem se inscreveu vê", ctx do
      assert Workshops.can_see_media?(ctx.workshop, ctx.aluna)
    end

    test "quem administra vê, mesmo sem estar inscrito", ctx do
      assert Workshops.can_see_media?(ctx.workshop, ctx.dono)

      parceiro = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.dono, parceiro.id)
      assert Workshops.can_see_media?(ctx.workshop, parceiro)
    end

    test "estranho logado não vê", ctx do
      refute Workshops.can_see_media?(ctx.workshop, insert(:user))
    end

    test "visitante sem conta não vê", ctx do
      refute Workshops.can_see_media?(ctx.workshop, nil)
    end
  end

  describe "add_media/3" do
    test "inscrito manda foto, e ela não nasce oficial", ctx do
      assert {:ok, media} = Workshops.add_media(ctx.workshop, ctx.aluna, foto(ctx))

      assert media.kind == :photo
      refute media.official
      assert {:file, _caminho} = Workshops.serve_media(media)
    end

    test "quem administra manda mídia oficial", ctx do
      assert {:ok, media} = Workshops.add_media(ctx.workshop, ctx.dono, foto(ctx))

      assert media.official
    end

    test "vídeo entra como vídeo", ctx do
      assert {:ok, media} = Workshops.add_media(ctx.workshop, ctx.aluna, video(ctx))

      assert media.kind == :video
    end

    test "o arquivo NÃO fica na pasta pública", ctx do
      {:ok, media} = Workshops.add_media(ctx.workshop, ctx.aluna, foto(ctx))

      # Nada de midia paga em pasta servida pelo Plug.Static.
      refute media.storage_key =~ "avatars"
      refute media.storage_key =~ "flyers"
      assert media.storage_key =~ "workshop_media"
    end

    test "estranho não manda mídia", ctx do
      assert {:error, :unauthorized} =
               Workshops.add_media(ctx.workshop, insert(:user), foto(ctx))
    end

    test "tipo que não é imagem nem vídeo é recusado", ctx do
      attrs = %{tmp_path: ctx.origem, content_type: "application/pdf", byte_size: 100}

      assert {:error, :unsupported_type} = Workshops.add_media(ctx.workshop, ctx.aluna, attrs)
    end
  end

  describe "list_media/1" do
    test "oficial vem primeiro, depois a comunidade", ctx do
      {:ok, _da_aluna} = Workshops.add_media(ctx.workshop, ctx.aluna, foto(ctx))
      {:ok, do_professor} = Workshops.add_media(ctx.workshop, ctx.dono, foto(ctx))

      assert [primeira, segunda] = Workshops.list_media(ctx.workshop.id)
      assert primeira.id == do_professor.id
      assert primeira.official
      refute segunda.official
    end

    test "apagada some da lista", ctx do
      {:ok, media} = Workshops.add_media(ctx.workshop, ctx.aluna, foto(ctx))
      {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.aluna, media.id)

      assert Workshops.list_media(ctx.workshop.id) == []
    end
  end

  describe "remove_media/3" do
    test "quem enviou tira a sua, e o arquivo vai junto", ctx do
      {:ok, media} = Workshops.add_media(ctx.workshop, ctx.aluna, foto(ctx))
      {:file, caminho} = Workshops.serve_media(media)

      assert {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.aluna, media.id)
      refute File.exists?(caminho)
    end

    test "quem administra tira a de qualquer um", ctx do
      {:ok, media} = Workshops.add_media(ctx.workshop, ctx.aluna, foto(ctx))

      assert {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.dono, media.id)
    end

    test "um inscrito não tira a mídia de outro", ctx do
      {:ok, media} = Workshops.add_media(ctx.workshop, ctx.aluna, foto(ctx))
      outra = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, outra)

      assert {:error, :unauthorized} = Workshops.remove_media(ctx.workshop, outra, media.id)
    end

    test "id de mídia de outro workshop não encontra nada", ctx do
      alheio = insert(:workshop, organizer: ctx.dono)
      {:ok, _} = Workshops.enroll(alheio, ctx.aluna)
      {:ok, de_la} = Workshops.add_media(alheio, ctx.aluna, foto(ctx))

      assert {:error, :not_found} = Workshops.remove_media(ctx.workshop, ctx.aluna, de_la.id)
    end

    test "id inventado não quebra", ctx do
      assert {:error, :not_found} =
               Workshops.remove_media(ctx.workshop, ctx.aluna, "nao-e-uuid")
    end
  end

  describe "cota por workshop" do
    # O byte_size declarado no upload é o que conta para a cota, então dá para
    # simular um workshop quase cheio sem gravar 2 GB de verdade.
    @cota 2_147_483_648

    test "workshop no limite recusa o próximo arquivo com motivo próprio", ctx do
      {:ok, _quase_cheio} =
        Workshops.add_media(ctx.workshop, ctx.aluna, %{
          tmp_path: ctx.origem,
          content_type: "image/png",
          byte_size: @cota - 100
        })

      assert {:error, :media_quota} =
               Workshops.add_media(ctx.workshop, ctx.aluna, %{
                 tmp_path: ctx.origem,
                 content_type: "image/png",
                 byte_size: 200
               })
    end

    test "o que couber exatamente na cota ainda entra", ctx do
      {:ok, _} =
        Workshops.add_media(ctx.workshop, ctx.aluna, %{
          tmp_path: ctx.origem,
          content_type: "image/png",
          byte_size: @cota - 100
        })

      assert {:ok, _} =
               Workshops.add_media(ctx.workshop, ctx.aluna, %{
                 tmp_path: ctx.origem,
                 content_type: "image/png",
                 byte_size: 100
               })
    end

    test "a cota é por workshop, não global", ctx do
      {:ok, _} =
        Workshops.add_media(ctx.workshop, ctx.aluna, %{
          tmp_path: ctx.origem,
          content_type: "image/png",
          byte_size: @cota - 100
        })

      outro = insert(:workshop, organizer: ctx.dono)
      {:ok, _} = Workshops.enroll(outro, ctx.aluna)

      assert {:ok, _} = Workshops.add_media(outro, ctx.aluna, foto(ctx))
    end

    test "mídia apagada devolve o espaço da cota", ctx do
      {:ok, grande} =
        Workshops.add_media(ctx.workshop, ctx.aluna, %{
          tmp_path: ctx.origem,
          content_type: "image/png",
          byte_size: @cota - 100
        })

      {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.aluna, grande.id)

      assert {:ok, _} =
               Workshops.add_media(ctx.workshop, ctx.aluna, %{
                 tmp_path: ctx.origem,
                 content_type: "image/png",
                 byte_size: 200
               })
    end
  end

  describe "media_usage/1" do
    test "conta arquivos e bytes", ctx do
      {:ok, _} = Workshops.add_media(ctx.workshop, ctx.aluna, foto(ctx))
      {:ok, _} = Workshops.add_media(ctx.workshop, ctx.dono, video(ctx))

      uso = Workshops.media_usage(ctx.workshop.id)

      assert uso.count == 2
      assert uso.bytes > 5_000_000
    end

    test "workshop sem mídia devolve zero", ctx do
      assert %{count: 0, bytes: 0} = Workshops.media_usage(ctx.workshop.id)
    end
  end
end
