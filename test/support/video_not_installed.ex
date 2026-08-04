defmodule OGrupoDeEstudos.Media.Video.NotInstalled do
  @moduledoc """
  Adapter de vídeo padrão dos testes: finge uma máquina sem ffmpeg.

  A suíte não pode depender de um binário estar instalado, senão o resultado
  muda de máquina para máquina. Com este dublê, todo teste que não fala de
  transcode passa pelo caminho de degradação, que é exatamente o que roda em
  produção se o ffmpeg sumir.

  Quem quer exercitar o transcode de verdade troca por
  `OGrupoDeEstudos.Media.Video.Mock` (Mox) dentro do próprio teste.
  """

  @behaviour OGrupoDeEstudos.Media.Video.Behaviour

  @impl true
  def available?, do: false

  @impl true
  def transcode(_source, _dest), do: {:error, :ffmpeg_unavailable}

  @impl true
  def poster(_source, _dest), do: {:error, :ffmpeg_unavailable}
end
