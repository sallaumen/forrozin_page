defmodule OGrupoDeEstudosWeb.WorkshopGalleryLiveTest do
  @moduledoc """
  A galeria vista de dentro da página, com vídeo em transcode.

  O que importa aqui é a aluna não ficar olhando "Processando" para sempre:
  ela sobe o vídeo, o ffmpeg roda em outra fila, e a página tem que se
  resolver sozinha.
  """

  # async: false — troca :uploads_path, que é config global.
  use OGrupoDeEstudosWeb.ConnCase, async: false
  # ConnCase nao traz os helpers de job; so o DataCase traz.
  use Oban.Testing, repo: OGrupoDeEstudos.Repo

  import OGrupoDeEstudos.Factory
  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Workers.TranscodeWorkshopVideo
  alias OGrupoDeEstudos.Workshops

  # Poll curto: o teste espera o timer vencer de verdade, e 4s seguraria a
  # suite inteira.
  @intervalo_ms 60

  setup do
    dir = Path.join(System.tmp_dir!(), "galeria_lv_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    anterior = Application.get_env(:o_grupo_de_estudos, :uploads_path)
    Application.put_env(:o_grupo_de_estudos, :uploads_path, dir)
    Application.put_env(:o_grupo_de_estudos, :recarga_galeria_ms, @intervalo_ms)

    on_exit(fn ->
      case anterior do
        nil -> Application.delete_env(:o_grupo_de_estudos, :uploads_path)
        valor -> Application.put_env(:o_grupo_de_estudos, :uploads_path, valor)
      end

      Application.delete_env(:o_grupo_de_estudos, :recarga_galeria_ms)
      File.rm_rf!(dir)
    end)

    origem = Path.join(dir, "clipe.mov")
    File.write!(origem, :binary.copy(<<0>>, 2_000))

    dono = insert(:user)
    aluna = insert(:user)
    workshop = insert(:workshop, organizer: dono)
    {:ok, _} = Workshops.enroll(workshop, aluna)

    %{dir: dir, origem: origem, dono: dono, aluna: aluna, workshop: workshop}
  end

  # Sobe o vídeo sem deixar o worker rodar junto, que é o estado real de quem
  # acabou de mandar o arquivo.
  defp video_em_transcode(ctx) do
    Oban.Testing.with_testing_mode(:manual, fn ->
      {:ok, media} =
        Workshops.add_media(ctx.workshop, ctx.aluna, %{
          tmp_path: ctx.origem,
          content_type: "video/quicktime",
          byte_size: 2_000
        })

      media
    end)
  end

  # A trava do poll é estado do socket, não sai no HTML: é o único jeito de
  # afirmar que não há timer duplicado voando.
  defp agendada?(lv), do: :sys.get_state(lv.pid).socket.assigns[:recarga_agendada?] == true

  defp mensagens_de_recarga(lv) do
    {:messages, fila} = Process.info(lv.pid, :messages)
    Enum.count(fila, &(&1 == :recarregar_galeria))
  end

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  defp foto(ctx) do
    caminho = Path.join(ctx.dir, "foto_#{System.unique_integer([:positive])}.png")
    File.write!(caminho, @png)

    {:ok, media} =
      Workshops.add_media(ctx.workshop, ctx.aluna, %{
        tmp_path: caminho,
        content_type: "image/png",
        byte_size: byte_size(@png)
      })

    media
  end

  describe "vídeo enquanto o ffmpeg não terminou" do
    test "quem está no workshop vê que o vídeo está processando", ctx do
      video_em_transcode(ctx)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.aluna), ~p"/workshops/#{ctx.workshop.slug}")

      assert html =~ "Processando vídeo"
      refute html =~ "<video"
    end

    test "a página se atualiza sozinha quando o transcode termina", ctx do
      media = video_em_transcode(ctx)

      {:ok, lv, _html} =
        live(log_in_user(build_conn(), ctx.aluna), ~p"/workshops/#{ctx.workshop.slug}")

      # Sem ffmpeg na suite, o worker degrada e marca como pronta: para a tela,
      # o efeito e o mesmo de um transcode que deu certo.
      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      send(lv.pid, :recarregar_galeria)

      assert render(lv) =~ "<video"
      refute render(lv) =~ "Processando vídeo"
    end

    test "mexer na galeria não acumula um poll por ação", ctx do
      # Apagar midia refaz a pagina inteira. Sem trava, quem sobe um video e
      # depois limpa umas fotos junta um timer por clique, todos relendo a
      # mesma galeria.
      video_em_transcode(ctx)
      fotos = Enum.map(1..3, fn _ -> foto(ctx) end)

      {:ok, lv, _html} =
        live(log_in_user(build_conn(), ctx.aluna), ~p"/workshops/#{ctx.workshop.slug}")

      assert agendada?(lv)

      for f <- fotos, do: render_click(lv, "remove_media", %{"id" => f.id})

      # Suspender o processo deixa os timers vencerem sem serem consumidos, e
      # ai da para contar quantos estavam voando de verdade.
      :sys.suspend(lv.pid)
      Process.sleep(@intervalo_ms * 3)
      pendentes = mensagens_de_recarga(lv)
      :sys.resume(lv.pid)

      assert pendentes == 1, "esperava 1 poll voando, achei #{pendentes}"
    end

    test "quando não há mais vídeo processando, o poll para", ctx do
      media = video_em_transcode(ctx)

      {:ok, lv, _html} =
        live(log_in_user(build_conn(), ctx.aluna), ~p"/workshops/#{ctx.workshop.slug}")

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})
      send(lv.pid, :recarregar_galeria)
      _ = render(lv)

      refute agendada?(lv)
    end

    test "quem não está no workshop não vê nem o aviso de processando", ctx do
      video_em_transcode(ctx)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/workshops/#{ctx.workshop.slug}")

      refute html =~ "Processando vídeo"
    end
  end
end
