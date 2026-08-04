defmodule OGrupoDeEstudos.Media.Video.FFmpeg do
  @moduledoc """
  Adapter de `OGrupoDeEstudos.Media.Video.Behaviour` em cima do ffmpeg.

  Resolve dois problemas da galeria, nesta ordem de importância:

  1. **Compatibilidade.** O iPhone grava HEVC por padrão, e boa parte dos
     Android mostra tela preta. Em conteúdo pago isso vira pedido de
     reembolso. A saída é sempre H.264 + AAC em yuv420p, que abre em tudo.
  2. **Tamanho.** 1080p HEVC de celular ocupa perto de 50 MB por minuto. Em
     720p H.264 cai para a casa de 10 MB por minuto.

  Os argumentos são montados por funções puras (`transcode_args/2` e
  `poster_args/2`), separadas da chamada ao binário: é o que decide qualidade
  e tamanho, e dá para testar sem ffmpeg instalado.
  """

  @behaviour OGrupoDeEstudos.Media.Video.Behaviour

  # Longest side of the frame. Landscape becomes 1280x720 and portrait 720x1280:
  # both are "720p" on the short side, which is what matters for phone video.
  @max_dimension 1280
  # 26 is transparent enough for dance video and cuts the file down. maxrate
  # holds the worst case: a fast step with heavy texture blows past the CRF.
  @crf "26"
  @maxrate "2M"
  @bufsize "4M"

  @doc "Se o binário do ffmpeg existe nesta máquina."
  @impl true
  def available?, do: not is_nil(System.find_executable("ffmpeg"))

  @doc "Converte o vídeo para 720p H.264. Sobrescreve o destino."
  @impl true
  def transcode(source, dest) do
    source
    |> transcode_args(dest)
    |> executar()
  end

  @doc "Extrai um quadro como imagem de capa."
  @impl true
  def poster(source, dest) do
    source
    |> poster_args(dest)
    |> executar()
  end

  @doc """
  Argumentos do transcode.

  `-vf scale` usa `min(1280, iw)` de propósito: com o box fixo em 1280 o
  ffmpeg aumentaria um vídeo antigo de 640x480, gastando espaço para não
  ganhar nitidez nenhuma. `force_divisible_by=2` existe porque o libx264
  recusa dimensão ímpar.
  """
  @spec transcode_args(String.t(), String.t()) :: [String.t()]
  def transcode_args(source, dest) do
    [
      "-y",
      "-i",
      source,
      "-vf",
      escala(),
      "-c:v",
      "libx264",
      "-preset",
      "veryfast",
      "-crf",
      @crf,
      "-maxrate",
      @maxrate,
      "-bufsize",
      @bufsize,
      "-profile:v",
      "main",
      "-pix_fmt",
      "yuv420p",
      "-c:a",
      "aac",
      "-b:a",
      "128k",
      "-movflags",
      "+faststart",
      dest
    ]
  end

  @doc """
  Argumentos do poster.

  `-ss` antes do `-i` é a busca barata: o ffmpeg pula no container em vez de
  decodificar tudo até o segundo 1.
  """
  @spec poster_args(String.t(), String.t()) :: [String.t()]
  def poster_args(source, dest) do
    ["-y", "-ss", "1", "-i", source, "-frames:v", "1", "-q:v", "4", dest]
  end

  defp escala do
    "scale=w='min(#{@max_dimension},iw)':h='min(#{@max_dimension},ih)'" <>
      ":force_original_aspect_ratio=decrease:force_divisible_by=2"
  end

  # System.cmd does not go through a shell: a path with a space or a semicolon
  # arrives as a single argument, with no chance of becoming a command.
  defp executar(args) do
    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_saida, 0} -> :ok
      {saida, codigo} -> {:error, {codigo, String.slice(saida, -500, 500)}}
    end
  rescue
    e -> {:error, e}
  end
end
