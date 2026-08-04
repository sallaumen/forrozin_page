defmodule OGrupoDeEstudos.Workers.TranscodeWorkshopVideo do
  @moduledoc """
  Converts a gallery video to 720p H.264, outside the upload cycle.

  Its own queue with `concurrency: 1` (see `config/config.exs`): the VM has 1
  shared vCPU and ffmpeg uses everything it finds. Two transcodes at once would
  slow the site down for whoever is browsing, and the queue is in no hurry.

  `max_attempts: 3` because what usually fails here is transient: a full disk
  mid-write, or a deploy mid-job. A codec error does not even become an attempt:
  the context degrades and marks the media as ready.

  A 30 minute `timeout` exists so a stuck ffmpeg does not hold the queue forever;
  with `concurrency: 1`, one stuck job is the whole queue stopped.
  """

  use Oban.Worker, queue: :video, max_attempts: 3

  alias OGrupoDeEstudos.Workshops

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_id" => media_id}}) do
    Workshops.transcode_media(media_id)
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(30)
end
