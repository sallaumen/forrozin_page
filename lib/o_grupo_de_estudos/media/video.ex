defmodule OGrupoDeEstudos.Media.Video do
  @moduledoc """
  Video transcoding facade.

  Delegates to the configured adapter, so the domain depends on this port
  (`OGrupoDeEstudos.Media.Video.Behaviour`) and not on ffmpeg. Defaults to
  `OGrupoDeEstudos.Media.Video.FFmpeg`; tests swap it through:

      config :o_grupo_de_estudos, OGrupoDeEstudos.Media.Video, adapter: SomeMock

  The adapter is resolved at runtime, so a single test can swap it.

  ## Usage

      Video.transcode("/tmp/upload.mov", "/tmp/output.mp4")
      #=> :ok
  """

  @default_adapter OGrupoDeEstudos.Media.Video.FFmpeg

  @doc "Whether transcoding is possible on this machine."
  @spec available?() :: boolean()
  def available?, do: adapter().available?()

  @doc "Converts the video to 720p H.264. Returns `:ok` or `{:error, reason}`."
  @spec transcode(String.t(), String.t()) :: :ok | {:error, term()}
  def transcode(source, dest), do: adapter().transcode(source, dest)

  @doc "Extracts a video frame as the cover image."
  @spec poster(String.t(), String.t()) :: :ok | {:error, term()}
  def poster(source, dest), do: adapter().poster(source, dest)

  defp adapter do
    :o_grupo_de_estudos
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:adapter, @default_adapter)
  end
end
