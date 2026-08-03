defmodule OGrupoDeEstudos.Workers.TranscodeWorkshopVideo do
  @moduledoc """
  Converte um vídeo da galeria para 720p H.264, fora do ciclo do upload.

  Fila própria com `concurrency: 1` (ver `config/config.exs`): a VM tem 1 vCPU
  compartilhado, e o ffmpeg usa tudo que encontra. Dois transcodes ao mesmo
  tempo deixariam o site lento para quem está navegando, e a fila não tem
  pressa nenhuma para terminar.

  `max_attempts: 3` porque o que costuma falhar aqui é transitório: disco
  cheio no meio da escrita, ou deploy no meio do job. Erro de codec não chega
  a virar tentativa: o contexto degrada e marca a mídia como pronta.

  `timeout` de 30 minutos existe para ffmpeg travado não segurar a fila para
  sempre; com `concurrency: 1`, um job preso é a fila inteira parada.
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
