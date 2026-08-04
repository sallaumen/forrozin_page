defmodule OGrupoDeEstudos.Media.Video.FFmpeg do
  @moduledoc """
  `OGrupoDeEstudos.Media.Video.Behaviour` adapter on top of ffmpeg.

  It solves two gallery problems, in this order of importance:

  1. **Compatibility.** The iPhone records HEVC by default, and many Android
     players show a black screen. On paid content that becomes a refund request.
     The output is always H.264 plus AAC in yuv420p, which plays everywhere.
  2. **Size.** 1080p HEVC from a phone takes around 50 MB per minute. At 720p
     H.264 it drops to about 10 MB per minute.

  The arguments are built by pure functions (`transcode_args/2` and
  `poster_args/2`), separate from the call to the binary: they are what decides
  quality and size, and they can be tested without ffmpeg installed.
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

  @doc "Whether the ffmpeg binary exists on this machine."
  @impl true
  def available?, do: not is_nil(System.find_executable("ffmpeg"))

  @doc "Converts the video to 720p H.264. Overwrites the destination."
  @impl true
  def transcode(source, dest) do
    source
    |> transcode_args(dest)
    |> executar()
  end

  @doc "Extracts a frame as the cover image."
  @impl true
  def poster(source, dest) do
    source
    |> poster_args(dest)
    |> executar()
  end

  @doc """
  Transcode arguments.

  `-vf scale` uses `min(1280, iw)` on purpose: with the box fixed at 1280 ffmpeg
  would upscale an old 640x480 video, spending space for no extra sharpness.
  `force_divisible_by=2` exists because libx264 refuses an odd dimension.
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
  Poster arguments.

  `-ss` before `-i` is the cheap seek: ffmpeg jumps inside the container instead
  of decoding everything up to the first second.
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
      {_output, 0} -> :ok
      {output, code} -> {:error, {code, String.slice(output, -500, 500)}}
    end
  rescue
    e -> {:error, e}
  end
end
