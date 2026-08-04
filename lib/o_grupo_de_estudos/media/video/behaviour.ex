defmodule OGrupoDeEstudos.Media.Video.Behaviour do
  @moduledoc """
  Port for video transcoding.

  Same idea as `Media.Storage.Behaviour`: the domain depends on this contract,
  not on ffmpeg. Adapters implement it; `Media.Video` delegates to the configured
  one (`FFmpeg` in dev and prod, a double in tests).

  The caller chooses the source and destination paths, so the adapter does not own
  the life cycle of a temporary file.
  """

  @doc """
  Whether transcoding is possible on this machine.

  It exists because the gallery degrades gracefully: without ffmpeg the file is
  stored as it came instead of failing the upload.
  """
  @callback available?() :: boolean()

  @doc "Converts the video to 720p H.264. `dest` is overwritten."
  @callback transcode(source :: String.t(), dest :: String.t()) :: :ok | {:error, term()}

  @doc "Extracts a video frame as the cover image."
  @callback poster(source :: String.t(), dest :: String.t()) :: :ok | {:error, term()}
end
