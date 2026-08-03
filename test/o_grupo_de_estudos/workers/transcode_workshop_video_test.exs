defmodule OGrupoDeEstudos.Workers.TranscodeWorkshopVideoTest do
  @moduledoc """
  Transcode de vídeo da galeria.

  O que está em jogo não é só espaço: iPhone grava HEVC, boa parte dos Android
  mostra tela preta, e a aluna que postou não entende por que a colega não
  consegue ver. Por isso a maior parte destes testes é sobre o arquivo que
  sobra no fim, não sobre o comando que rodou.
  """

  # async: false — troca :uploads_path e o adapter de vídeo, que são config
  # global.
  use OGrupoDeEstudos.DataCase, async: false

  import Mox
  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Media.Video
  alias OGrupoDeEstudos.Workers.TranscodeWorkshopVideo
  alias OGrupoDeEstudos.Workshops

  setup :verify_on_exit!

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    dir = Path.join(System.tmp_dir!(), "transcode_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    uploads_antes = Application.get_env(:o_grupo_de_estudos, :uploads_path)
    video_antes = Application.get_env(:o_grupo_de_estudos, Video)

    Application.put_env(:o_grupo_de_estudos, :uploads_path, dir)
    Application.put_env(:o_grupo_de_estudos, Video, adapter: Video.Mock)

    on_exit(fn ->
      restaurar(:uploads_path, uploads_antes)
      restaurar(Video, video_antes)
      File.rm_rf!(dir)
    end)

    origem = Path.join(dir, "origem.mov")
    # 4 MB de "vídeo": o que importa é ser bem maior do que a saída fingida.
    File.write!(origem, :binary.copy(<<0>>, 4_000_000))

    dono = insert(:user)
    aluna = insert(:user)
    workshop = insert(:workshop, organizer: dono)
    {:ok, _} = Workshops.enroll(workshop, aluna)

    %{dir: dir, origem: origem, dono: dono, aluna: aluna, workshop: workshop}
  end

  defp restaurar(chave, nil), do: Application.delete_env(:o_grupo_de_estudos, chave)
  defp restaurar(chave, valor), do: Application.put_env(:o_grupo_de_estudos, chave, valor)

  defp video(ctx),
    do: %{tmp_path: ctx.origem, content_type: "video/quicktime", byte_size: 4_000_000}

  defp foto(ctx) do
    caminho = Path.join(ctx.dir, "foto.png")
    File.write!(caminho, @png)
    %{tmp_path: caminho, content_type: "image/png", byte_size: byte_size(@png)}
  end

  # Vídeo que entra sem o worker rodar junto, para os testes do worker
  # partirem do estado real de "acabou de subir".
  defp subir_video(ctx) do
    Oban.Testing.with_testing_mode(:manual, fn ->
      {:ok, media} = Workshops.add_media(ctx.workshop, ctx.aluna, video(ctx))
      media
    end)
  end

  # ffmpeg de mentira: escreve no destino o conteúdo pedido e devolve :ok.
  defp escrever_no_destino(conteudo) do
    fn _origem, destino ->
      File.write!(destino, conteudo)
      :ok
    end
  end

  describe "o que acontece no upload" do
    test "vídeo entra como processando e vai para a fila", ctx do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, media} = Workshops.add_media(ctx.workshop, ctx.aluna, video(ctx))

        assert media.status == :processing

        assert_enqueued(
          worker: TranscodeWorkshopVideo,
          args: %{"media_id" => media.id},
          queue: :video
        )
      end)
    end

    test "foto já nasce pronta e não ocupa a fila", ctx do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, media} = Workshops.add_media(ctx.workshop, ctx.aluna, foto(ctx))

        assert media.status == :ready
        refute_enqueued(worker: TranscodeWorkshopVideo)
      end)
    end
  end

  describe "transcode que dá certo" do
    test "troca o arquivo, atualiza tamanho e tipo, e marca pronto", ctx do
      media = subir_video(ctx)
      chave_antiga = media.storage_key

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, escrever_no_destino(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, escrever_no_destino("jpeg-de-mentira"))

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      pronta = Workshops.get_media(media.id)
      assert pronta.status == :ready
      assert pronta.content_type == "video/mp4"
      assert pronta.byte_size == 800_000
      assert pronta.storage_key != chave_antiga
      # O convertido fica na pasta do mesmo workshop, como o original.
      assert pronta.storage_key =~ ~r{^workshop_media/#{ctx.workshop.id}/[A-Za-z0-9]+\.mp4$}
      assert {:file, _} = Workshops.serve_media(pronta)
    end

    test "o arquivo original vai embora, senão o transcode dobraria o espaço", ctx do
      media = subir_video(ctx)
      {:file, caminho_antigo} = Workshops.serve_media(media)
      assert File.exists?(caminho_antigo)

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, escrever_no_destino(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, escrever_no_destino("jpeg-de-mentira"))

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      refute File.exists?(caminho_antigo)
    end

    test "grava o poster e ele fica em disco", ctx do
      media = subir_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, escrever_no_destino(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, escrever_no_destino("jpeg-de-mentira"))

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      pronta = Workshops.get_media(media.id)
      assert pronta.poster_key =~ ~r{^workshop_media/#{ctx.workshop.id}/[A-Za-z0-9]+\.jpg$}
      assert {:file, _} = Workshops.serve_poster(pronta)
    end

    test "não sobra arquivo temporário na área de trabalho", ctx do
      media = subir_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, escrever_no_destino(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, escrever_no_destino("jpeg-de-mentira"))

      antes = temporarios()
      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      assert temporarios() == antes
    end
  end

  describe "degradação com elegância" do
    test "sem ffmpeg, guarda o arquivo como veio em vez de falhar", ctx do
      media = subir_video(ctx)

      expect(Video.Mock, :available?, fn -> false end)

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      intacta = Workshops.get_media(media.id)
      assert intacta.status == :ready
      assert intacta.storage_key == media.storage_key
      assert intacta.content_type == "video/quicktime"
      assert intacta.byte_size == media.byte_size
      assert is_nil(intacta.poster_key)
      assert {:file, _} = Workshops.serve_media(intacta)
    end

    test "transcode que falha não perde o vídeo da aluna", ctx do
      media = subir_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, fn _origem, _destino -> {:error, {1, "codec estranho"}} end)

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      intacta = Workshops.get_media(media.id)
      assert intacta.status == :ready
      assert intacta.storage_key == media.storage_key
      assert {:file, _} = Workshops.serve_media(intacta)
    end

    test "poster que falha não segura o vídeo em processando", ctx do
      media = subir_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, escrever_no_destino(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, fn _origem, _destino -> {:error, :vídeo_curto_demais} end)

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      pronta = Workshops.get_media(media.id)
      assert pronta.status == :ready
      assert pronta.byte_size == 800_000
      assert is_nil(pronta.poster_key)
    end

    test "vídeo que já foi transcodificado não roda de novo", ctx do
      media = subir_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, escrever_no_destino(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, escrever_no_destino("jpeg-de-mentira"))

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})
      # Segunda passada: retry do Oban ou job duplicado. Sem expect nenhum, um
      # toque no ffmpeg estoura o verify_on_exit!.
      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})
    end

    test "mídia apagada no meio do caminho não quebra o job", ctx do
      media = subir_video(ctx)
      {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.aluna, media.id)

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})
    end

    test "id que não existe não quebra o job" do
      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => Ecto.UUID.generate()})
    end
  end

  describe "remoção no meio do transcode" do
    test "quem apaga durante o ffmpeg ganha: nada convertido sobra no volume", ctx do
      media = subir_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)

      expect(Video.Mock, :transcode, fn _origem, destino ->
        # A aluna apaga enquanto o ffmpeg trabalha (ele segue com o arquivo
        # aberto). O job não pode ressuscitar a mídia apagada nem largar o
        # convertido órfão no volume: ninguém mais o deletaria.
        {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.aluna, media.id)
        File.write!(destino, :binary.copy(<<1>>, 800_000))
        :ok
      end)

      expect(Video.Mock, :poster, escrever_no_destino("jpeg-de-mentira"))

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      assert OGrupoDeEstudos.Media.ObjectStorage.list("workshop_media/") == []

      apagada = Workshops.get_media(media.id)
      refute is_nil(apagada.deleted_at)
      # A linha apagada não ganha a chave do convertido: fica como a remoção
      # a deixou.
      assert apagada.storage_key == media.storage_key
    end
  end

  describe "remoção depois do transcode" do
    test "apagar a mídia leva o poster junto", ctx do
      media = subir_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, escrever_no_destino(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, escrever_no_destino("jpeg-de-mentira"))

      :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})
      pronta = Workshops.get_media(media.id)
      {:file, caminho_poster} = Workshops.serve_poster(pronta)

      assert {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.aluna, media.id)
      refute File.exists?(caminho_poster)
    end
  end

  defp temporarios do
    System.tmp_dir!()
    |> File.ls!()
    |> Enum.filter(&String.starts_with?(&1, "workshop_video_"))
  end
end
