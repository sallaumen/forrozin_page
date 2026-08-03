defmodule OGrupoDeEstudos.Media.Video.FFmpegTest do
  @moduledoc """
  Cobre a parte pura do adapter: a linha de comando.

  Rodar ffmpeg de verdade no teste amarraria a suite a um binário instalado na
  máquina. O que decide qualidade e tamanho do arquivo é a lista de argumentos,
  e isso é cálculo, não ação.
  """

  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Media.Video.FFmpeg

  describe "transcode_args/2" do
    test "sobrescreve o destino sem perguntar" do
      args = FFmpeg.transcode_args("/tmp/origem.mov", "/tmp/destino.mp4")

      assert "-y" in args
    end

    test "sai em H.264 com áudio AAC, que todo Android abre" do
      args = FFmpeg.transcode_args("/tmp/origem.mov", "/tmp/destino.mp4")

      assert par_de(args, "-c:v") == "libx264"
      assert par_de(args, "-c:a") == "aac"
    end

    test "força pixel format yuv420p" do
      # HEVC de iPhone costuma vir em 10 bits. Sem isso o H.264 sai num perfil
      # que boa parte dos Android tambem nao decodifica, e o transcode nao
      # resolveria nada.
      args = FFmpeg.transcode_args("/tmp/origem.mov", "/tmp/destino.mp4")

      assert par_de(args, "-pix_fmt") == "yuv420p"
    end

    test "põe o índice no começo do arquivo, para o vídeo abrir antes de baixar inteiro" do
      args = FFmpeg.transcode_args("/tmp/origem.mov", "/tmp/destino.mp4")

      assert par_de(args, "-movflags") == "+faststart"
    end

    test "limita o lado maior a 1280 sem esticar vídeo pequeno" do
      escala = args_de_escala("/tmp/origem.mov")

      # min(1280, iw) nunca aumenta: um 640x480 antigo sai 640x480.
      assert escala =~ "min(1280,iw)"
      assert escala =~ "min(1280,ih)"
      assert escala =~ "force_original_aspect_ratio=decrease"
    end

    test "garante dimensão par, senão o libx264 recusa" do
      assert args_de_escala("/tmp/origem.mov") =~ "force_divisible_by=2"
    end

    test "origem e destino entram como argumentos separados, nunca interpolados numa shell" do
      args = FFmpeg.transcode_args("/tmp/com espaço; rm -rf /.mov", "/tmp/destino.mp4")

      assert par_de(args, "-i") == "/tmp/com espaço; rm -rf /.mov"
      assert List.last(args) == "/tmp/destino.mp4"
    end
  end

  describe "poster_args/2" do
    test "busca no segundo 1 e tira um quadro só" do
      args = FFmpeg.poster_args("/tmp/video.mp4", "/tmp/poster.jpg")

      assert par_de(args, "-ss") == "1"
      assert par_de(args, "-frames:v") == "1"
    end

    test "o -ss vem antes do -i, que é a busca barata" do
      # Depois do -i o ffmpeg decodifica tudo ate o segundo 1. Antes, ele pula
      # direto no container. E a diferenca entre 0,3s e varios segundos de CPU.
      args = FFmpeg.poster_args("/tmp/video.mp4", "/tmp/poster.jpg")

      assert indice_de(args, "-ss") < indice_de(args, "-i")
    end

    test "o destino é o último argumento" do
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

  defp args_de_escala(origem) do
    origem
    |> FFmpeg.transcode_args("/tmp/destino.mp4")
    |> par_de("-vf")
  end
end
