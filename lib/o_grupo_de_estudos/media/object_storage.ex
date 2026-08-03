defmodule OGrupoDeEstudos.Media.ObjectStorage do
  @moduledoc """
  Fachada da porta de objetos (`ObjectStorage.Behaviour`).

  Delega para o adapter configurado, para o resto do app depender do contrato
  e não de onde os bytes moram. Por padrão usa o disco local
  (`ObjectStorage.LocalDisk`); testes trocam via:

      config :o_grupo_de_estudos, OGrupoDeEstudos.Media.ObjectStorage, adapter: AlgumMock

  Quando o storage sair do Fly para um provider externo, entra um adapter novo
  aqui e mais nada muda de lugar.
  """

  alias OGrupoDeEstudos.Media.ObjectStorage.LocalDisk

  @doc "Grava o arquivo de origem na chave. Sobrescreve se já existir."
  @spec put(String.t(), String.t()) :: :ok | {:error, term()}
  def put(key, source_path), do: adapter().put(key, source_path)

  @doc "Apaga o objeto. Silencioso quando já não existe."
  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(key), do: adapter().delete(key)

  @spec exists?(String.t()) :: boolean()
  def exists?(key), do: adapter().exists?(key)

  @doc "Chaves que começam com o prefixo."
  @spec list(String.t()) :: [String.t()]
  def list(prefix), do: adapter().list(prefix)

  @doc "URL pública de um objeto servido sem autorização."
  @spec public_url(String.t()) :: String.t()
  def public_url(key), do: adapter().public_url(key)

  @doc "Como servir um objeto restrito: arquivo local ou redirect assinado."
  @spec serve(String.t()) :: {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}
  def serve(key), do: adapter().serve(key)

  @doc "Roda `fun` com um caminho local legível do objeto."
  @spec with_local_file(String.t(), (String.t() -> result)) :: {:ok, result} | {:error, term()}
        when result: term()
  def with_local_file(key, fun), do: adapter().with_local_file(key, fun)

  @doc "Bytes livres no storage, ou `:unknown`."
  @spec free_bytes() :: non_neg_integer() | :unknown
  def free_bytes, do: adapter().free_bytes()

  defp adapter do
    :o_grupo_de_estudos
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:adapter, LocalDisk)
  end
end
