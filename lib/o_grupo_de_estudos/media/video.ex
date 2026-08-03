defmodule OGrupoDeEstudos.Media.Video do
  @moduledoc """
  Fachada de transcodificação de vídeo.

  Delega para o adapter configurado, para o domínio depender desta porta
  (`OGrupoDeEstudos.Media.Video.Behaviour`) e não do ffmpeg. Por padrão usa
  `OGrupoDeEstudos.Media.Video.FFmpeg`; testes trocam via:

      config :o_grupo_de_estudos, OGrupoDeEstudos.Media.Video, adapter: AlgumMock

  O adapter é resolvido em runtime, então um teste sozinho consegue trocar.

  ## Uso

      Video.transcode("/tmp/upload.mov", "/tmp/saida.mp4")
      #=> :ok
  """

  @default_adapter OGrupoDeEstudos.Media.Video.FFmpeg

  @doc "Se dá para transcodificar nesta máquina."
  @spec available?() :: boolean()
  def available?, do: adapter().available?()

  @doc "Converte o vídeo para 720p H.264. Devolve `:ok` ou `{:error, motivo}`."
  @spec transcode(String.t(), String.t()) :: :ok | {:error, term()}
  def transcode(source, dest), do: adapter().transcode(source, dest)

  @doc "Extrai um quadro do vídeo como imagem de capa."
  @spec poster(String.t(), String.t()) :: :ok | {:error, term()}
  def poster(source, dest), do: adapter().poster(source, dest)

  defp adapter do
    :o_grupo_de_estudos
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:adapter, @default_adapter)
  end
end
