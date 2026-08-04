defmodule OGrupoDeEstudos.Workers.TranscodeWorkshopVideoTest do
  @moduledoc """
  Gallery video transcode. iPhone records HEVC and many Android players show a
  black screen, so most of these tests are about the file left at the end, not
  about the command that ran.
  """

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
    uploads_before = Application.get_env(:o_grupo_de_estudos, :uploads_path)
    video_before = Application.get_env(:o_grupo_de_estudos, Video)

    Application.put_env(:o_grupo_de_estudos, :uploads_path, dir)
    Application.put_env(:o_grupo_de_estudos, Video, adapter: Video.Mock)

    on_exit(fn ->
      restaurar(:uploads_path, uploads_before)
      restaurar(Video, video_before)
      File.rm_rf!(dir)
    end)

    source = Path.join(dir, "origem.mov")
    File.write!(source, :binary.copy(<<0>>, 4_000_000))

    owner = insert(:user)
    student = insert(:user)
    workshop = insert(:workshop, organizer: owner)
    {:ok, _} = Workshops.enroll(workshop, student)

    %{dir: dir, source: source, owner: owner, student: student, workshop: workshop}
  end

  defp restaurar(key, nil), do: Application.delete_env(:o_grupo_de_estudos, key)
  defp restaurar(key, value), do: Application.put_env(:o_grupo_de_estudos, key, value)

  defp video_upload(ctx),
    do: %{tmp_path: ctx.source, content_type: "video/quicktime", byte_size: 4_000_000}

  defp photo(ctx) do
    path = Path.join(ctx.dir, "foto.png")
    File.write!(path, @png)
    %{tmp_path: path, content_type: "image/png", byte_size: byte_size(@png)}
  end

  defp upload_video(ctx) do
    Oban.Testing.with_testing_mode(:manual, fn ->
      {:ok, media} = Workshops.add_media(ctx.workshop, ctx.student, video_upload(ctx))
      media
    end)
  end

  defp write_to_destination(content) do
    fn _source, destination ->
      File.write!(destination, content)
      :ok
    end
  end

  describe "what happens on upload" do
    test "video arrives as processing and goes to the queue", ctx do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, media} = Workshops.add_media(ctx.workshop, ctx.student, video_upload(ctx))

        assert media.status == :processing

        assert_enqueued(
          worker: TranscodeWorkshopVideo,
          args: %{"media_id" => media.id},
          queue: :video
        )
      end)
    end

    test "photo arrives ready and does not take the queue", ctx do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, media} = Workshops.add_media(ctx.workshop, ctx.student, photo(ctx))

        assert media.status == :ready
        refute_enqueued(worker: TranscodeWorkshopVideo)
      end)
    end
  end

  describe "successful transcode" do
    test "troca o arquivo, atualiza tamanho e tipo, e marca pronto", ctx do
      media = upload_video(ctx)
      old_key = media.storage_key

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, write_to_destination(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, write_to_destination("jpeg-de-mentira"))

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      ready_media = Workshops.get_media(media.id)
      assert ready_media.status == :ready
      assert ready_media.content_type == "video/mp4"
      assert ready_media.byte_size == 800_000
      assert ready_media.storage_key != old_key
      assert ready_media.storage_key =~ ~r{^workshop_media/#{ctx.workshop.id}/[A-Za-z0-9]+\.mp4$}
      assert {:file, _} = Workshops.serve_media(ready_media)
    end

    test "original file is dropped, otherwise the transcode would double the space", ctx do
      media = upload_video(ctx)
      {:file, old_path} = Workshops.serve_media(media)
      assert File.exists?(old_path)

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, write_to_destination(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, write_to_destination("jpeg-de-mentira"))

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      refute File.exists?(old_path)
    end

    test "stores the poster and it stays on disk", ctx do
      media = upload_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, write_to_destination(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, write_to_destination("jpeg-de-mentira"))

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      ready_media = Workshops.get_media(media.id)
      assert ready_media.poster_key =~ ~r{^workshop_media/#{ctx.workshop.id}/[A-Za-z0-9]+\.jpg$}
      assert {:file, _} = Workshops.serve_poster(ready_media)
    end

    test "leaves no temporary file in the work area", ctx do
      media = upload_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, write_to_destination(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, write_to_destination("jpeg-de-mentira"))

      earlier = temporarios()
      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      assert temporarios() == earlier
    end
  end

  describe "graceful degradation" do
    test "keeps the original file instead of failing when ffmpeg is missing", ctx do
      media = upload_video(ctx)

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

    test "failed transcode does not lose the uploaded video", ctx do
      media = upload_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)

      expect(Video.Mock, :transcode, fn _source, _destination ->
        {:error, {1, "codec estranho"}}
      end)

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      intacta = Workshops.get_media(media.id)
      assert intacta.status == :ready
      assert intacta.storage_key == media.storage_key
      assert {:file, _} = Workshops.serve_media(intacta)
    end

    test "failed poster does not hold the video in processing", ctx do
      media = upload_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, write_to_destination(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, fn _source, _destination -> {:error, :vídeo_curto_demais} end)

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      ready_media = Workshops.get_media(media.id)
      assert ready_media.status == :ready
      assert ready_media.byte_size == 800_000
      assert is_nil(ready_media.poster_key)
    end

    test "already transcoded video does not run again", ctx do
      media = upload_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, write_to_destination(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, write_to_destination("jpeg-de-mentira"))

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})
      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})
    end

    test "media deleted halfway does not break the job", ctx do
      media = upload_video(ctx)
      {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.student, media.id)

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})
    end

    test "unknown id does not break the job" do
      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => Ecto.UUID.generate()})
    end
  end

  describe "deletion during the transcode" do
    test "deleting during ffmpeg wins and leaves nothing converted on the volume", ctx do
      media = upload_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)

      expect(Video.Mock, :transcode, fn _source, destination ->
        {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.student, media.id)
        File.write!(destination, :binary.copy(<<1>>, 800_000))
        :ok
      end)

      expect(Video.Mock, :poster, write_to_destination("jpeg-de-mentira"))

      assert :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})

      assert OGrupoDeEstudos.Media.ObjectStorage.list("workshop_media/") == []

      deleted_media = Workshops.get_media(media.id)
      refute is_nil(deleted_media.deleted_at)
      assert deleted_media.storage_key == media.storage_key
    end
  end

  describe "deletion after the transcode" do
    test "deleting the media takes the poster with it", ctx do
      media = upload_video(ctx)

      expect(Video.Mock, :available?, fn -> true end)
      expect(Video.Mock, :transcode, write_to_destination(:binary.copy(<<1>>, 800_000)))
      expect(Video.Mock, :poster, write_to_destination("jpeg-de-mentira"))

      :ok = perform_job(TranscodeWorkshopVideo, %{"media_id" => media.id})
      ready_media = Workshops.get_media(media.id)
      {:file, poster_path} = Workshops.serve_poster(ready_media)

      assert {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.student, media.id)
      refute File.exists?(poster_path)
    end
  end

  defp temporarios do
    System.tmp_dir!()
    |> File.ls!()
    |> Enum.filter(&String.starts_with?(&1, "workshop_video_"))
  end
end
