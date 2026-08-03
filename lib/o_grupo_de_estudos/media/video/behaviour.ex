defmodule OGrupoDeEstudos.Media.Video.Behaviour do
  @moduledoc """
  Porta para transcodificação de vídeo.

  Mesma ideia do `Media.Storage.Behaviour`: o domínio depende deste contrato,
  não do ffmpeg. Adapters implementam; `Media.Video` delega para o configurado
  (`FFmpeg` em dev/prod, um dublê nos testes).

  Quem chama escolhe os caminhos de origem e destino, então o adapter não fica
  dono do ciclo de vida de arquivo temporário.
  """

  @doc """
  Se dá para transcodificar nesta máquina.

  Existe porque a galeria degrada com elegância: sem ffmpeg, o arquivo é
  guardado como veio em vez de o upload falhar.
  """
  @callback available?() :: boolean()

  @doc "Converte o vídeo para 720p H.264. `dest` é sobrescrito."
  @callback transcode(source :: String.t(), dest :: String.t()) :: :ok | {:error, term()}

  @doc "Extrai um quadro do vídeo como imagem de capa."
  @callback poster(source :: String.t(), dest :: String.t()) :: :ok | {:error, term()}
end
