defmodule OGrupoDeEstudosWeb.WorkshopGalleryLiveTest do
  @moduledoc """
  The gallery seen from inside the page, with a video still being transcoded:
  the page has to resolve itself instead of showing "processing" forever.
  """

  # async: false because the test swaps :uploads_path in the global app env.
  use OGrupoDeEstudosWeb.ConnCase, async: false
  use Oban.Testing, repo: OGrupoDeEstudos.Repo

  import OGrupoDeEstudos.Factory
  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Workers.TranscodeWorkshopVideo
  alias OGrupoDeEstudos.Workshops

  @poll_interval_ms 60

  setup do
    dir = Path.join(System.tmp_dir!(), "galeria_lv_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    previous = Application.get_env(:o_grupo_de_estudos, :uploads_path)
    Application.put_env(:o_grupo_de_estudos, :uploads_path, dir)
    Application.put_env(:o_grupo_de_estudos, :recarga_galeria_ms, @poll_interval_ms)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:o_grupo_de_estudos, :uploads_path)
        value -> Application.put_env(:o_grupo_de_estudos, :uploads_path, value)
      end

      Application.delete_env(:o_grupo_de_estudos, :recarga_galeria_ms)
      File.rm_rf!(dir)
    end)

    source = Path.join(dir, "clipe.mov")
    File.write!(source, :binary.copy(<<0>>, 2_000))

    owner = insert(:user)
    student = insert(:user)
    workshop = insert(:workshop, organizer: owner)
    {:ok, _} = Workshops.enroll(workshop, student)

    %{dir: dir, source: source, owner: owner, student: student, workshop: workshop}
  end

  defp video_being_transcoded(ctx) do
    Oban.Testing.with_testing_mode(:manual, fn ->
      {:ok, media} =
        Workshops.add_media(ctx.workshop, ctx.student, %{
          tmp_path: ctx.source,
          content_type: "video/quicktime",
          byte_size: 2_000
        })

      media
    end)
  end

  defp reload_scheduled?(lv),
    do: :sys.get_state(lv.pid).socket.assigns[:recarga_agendada?] == true

  defp reload_messages(lv) do
    {:messages, queue} = Process.info(lv.pid, :messages)
    Enum.count(queue, &(&1 == :recarregar_galeria))
  end

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  defp photo(ctx) do
    path = Path.join(ctx.dir, "foto_#{System.unique_integer([:positive])}.png")
    File.write!(path, @png)

    {:ok, media} =
      Workshops.add_media(ctx.workshop, ctx.student, %{
        tmp_path: path,
        content_type: "image/png",
        byte_size: byte_size(@png)
      })

    media
  end

  describe "video while ffmpeg has not finished" do
    test "enrolled user sees that the video is processing", ctx do
      video_being_transcoded(ctx)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.student), ~p"/workshops/#{ctx.workshop.slug}")

      assert html =~ "Processando vídeo"
      refute html =~ "<video"
    end

    test "page refreshes itself when the transcode finishes", ctx do
      media = video_being_transcoded(ctx)

      {:ok, lv, _html} =
        live(log_in_user(build_conn(), ctx.student), ~p"/workshops/#{ctx.workshop.slug}")

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      send(lv.pid, :recarregar_galeria)

      assert render(lv) =~ "<video"
      refute render(lv) =~ "Processando vídeo"
    end

    test "using the gallery does not stack one poll per action", ctx do
      video_being_transcoded(ctx)
      photos = Enum.map(1..3, fn _ -> photo(ctx) end)

      {:ok, lv, _html} =
        live(log_in_user(build_conn(), ctx.student), ~p"/workshops/#{ctx.workshop.slug}")

      assert reload_scheduled?(lv)

      for f <- photos, do: render_click(lv, "remove_media", %{"id" => f.id})

      :sys.suspend(lv.pid)
      Process.sleep(@poll_interval_ms * 3)
      pendentes = reload_messages(lv)
      :sys.resume(lv.pid)

      assert pendentes == 1, "esperava 1 poll voando, achei #{pendentes}"
    end

    test "polling stops when no video is processing anymore", ctx do
      media = video_being_transcoded(ctx)

      {:ok, lv, _html} =
        live(log_in_user(build_conn(), ctx.student), ~p"/workshops/#{ctx.workshop.slug}")

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})
      send(lv.pid, :recarregar_galeria)
      _ = render(lv)

      refute reload_scheduled?(lv)
    end

    test "outsider sees neither the media nor the processing notice", ctx do
      video_being_transcoded(ctx)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/workshops/#{ctx.workshop.slug}")

      refute html =~ "Processando vídeo"
    end
  end
end
