defmodule OGrupoDeEstudos.Media.ObjectStorage.Behaviour do
  @moduledoc """
  Porta de armazenamento de objetos: bytes entram e saem por chave opaca.

  É o ÚNICO contrato que um provider externo (S3, Tigris, R2) precisa
  implementar para o storage sair do disco local. De propósito, não sabe nada
  de avatar, flyer ou galeria: nome de arquivo, redimensionamento e permissão
  são política de `Media.Storage` e do domínio, e não mudam quando o provider
  muda.

  A chave é um caminho relativo opaco ("avatars/u1_99.jpg"). Quem chama decide
  a chave; o adapter decide onde os bytes moram.
  """

  @doc "Grava o arquivo de origem na chave. Sobrescreve se já existir."
  @callback put(key :: String.t(), source_path :: String.t()) :: :ok | {:error, term()}

  @doc "Apaga o objeto. Silencioso quando já não existe."
  @callback delete(key :: String.t()) :: :ok | {:error, term()}

  @callback exists?(key :: String.t()) :: boolean()

  @doc "Chaves que começam com o prefixo. Para faxina (avatares antigos)."
  @callback list(prefix :: String.t()) :: [String.t()]

  @doc "URL pública de um objeto servido sem autorização (avatar, flyer)."
  @callback public_url(key :: String.t()) :: String.t()

  @doc """
  Como servir um objeto restrito: `{:file, caminho}` para `send_file`, ou
  `{:redirect, url}` quando o provider gera URL assinada.

  O controller de mídia trata os dois; o adapter escolhe o que tem.
  """
  @callback serve(key :: String.t()) ::
              {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}

  @doc """
  Roda `fun` com um caminho local legível do objeto (entrada de ffmpeg ou
  Mogrify). No disco é o próprio arquivo; num provider externo, o adapter
  baixa para um temporário e limpa depois.
  """
  @callback with_local_file(key :: String.t(), fun :: (String.t() -> result)) ::
              {:ok, result} | {:error, term()}
            when result: term()

  @doc "Bytes livres, ou `:unknown` quando o provider não expõe (ou nem limita)."
  @callback free_bytes() :: non_neg_integer() | :unknown
end
