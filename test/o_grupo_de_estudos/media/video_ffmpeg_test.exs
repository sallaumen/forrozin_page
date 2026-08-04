defmodule OGrupoDeEstudos.Media.Video.FFmpegTest do
  @moduledoc """
  Covers the pure half of the adapter, the command line. What decides quality
  and file size is the argument list, and that is a calculation.
  """

  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Media.Video.FFmpeg

  describe "transcode_args/2" do
    test "overwrites the destination without asking" do
      args = FFmpeg.transcode_args("/tmp/origem.mov", "/tmp/destino.mp4")

      assert "-y" in args
    end

    test "outputs H.264 with AAC audio, which every Android plays" do
      args = FFmpeg.transcode_args("/tmp/origem.mov", "/tmp/destino.mp4")

      assert par_de(args, "-c:v") == "libx264"
      assert par_de(args, "-c:a") == "aac"
    end

    test "forces the yuv420p pixel format" do
      args = FFmpeg.transcode_args("/tmp/origem.mov", "/tmp/destino.mp4")

      assert par_de(args, "-pix_fmt") == "yuv420p"
    end

    test "moves the index to the start so playback begins before the full download" do
      args = FFmpeg.transcode_args("/tmp/origem.mov", "/tmp/destino.mp4")

      assert par_de(args, "-movflags") == "+faststart"
    end

    test "caps the longest side at 1280 without upscaling a small video" do
      escala = args_de_escala("/tmp/origem.mov")

      assert escala =~ "min(1280,iw)"
      assert escala =~ "min(1280,ih)"
      assert escala =~ "force_original_aspect_ratio=decrease"
    end

    test "forces even dimensions, which libx264 requires" do
      assert args_de_escala("/tmp/origem.mov") =~ "force_divisible_by=2"
    end

    test "passes source and destination as separate arguments, never through a shell" do
      args = FFmpeg.transcode_args("/tmp/com espaço; rm -rf /.mov", "/tmp/destino.mp4")

      assert par_de(args, "-i") == "/tmp/com espaço; rm -rf /.mov"
      assert List.last(args) == "/tmp/destino.mp4"
    end
  end

  describe "poster_args/2" do
    test "seeks to the first second and grabs a single frame" do
      args = FFmpeg.poster_args("/tmp/video.mp4", "/tmp/poster.jpg")

      assert par_de(args, "-ss") == "1"
      assert par_de(args, "-frames:v") == "1"
    end

    test "puts -ss before -i, which is the cheap seek" do
      args = FFmpeg.poster_args("/tmp/video.mp4", "/tmp/poster.jpg")

      assert indice_de(args, "-ss") < indice_de(args, "-i")
    end

    test "puts the destination as the last argument" do
      args = FFmpeg.poster_args("/tmp/video.mp4", "/tmp/poster.jpg")

      assert List.last(args) == "/tmp/poster.jpg"
    end
  end

  defp par_de(args, flag) do
    case indice_de(args, flag) do
      nil -> nil
      i -> Enum.at(args, i + 1)
    end
  end

  defp indice_de(args, flag), do: Enum.find_index(args, &(&1 == flag))

  defp args_de_escala(source) do
    source
    |> FFmpeg.transcode_args("/tmp/destino.mp4")
    |> par_de("-vf")
  end
end
