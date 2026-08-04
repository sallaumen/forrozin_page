defmodule OGrupoDeEstudos.Media.ObjectStorage do
  @moduledoc """
  Facade of the object port (`ObjectStorage.Behaviour`).

  Delegates to the configured adapter, so the rest of the app depends on the
  contract and not on where the bytes live. Defaults to the local disk
  (`ObjectStorage.LocalDisk`); tests swap it through:

      config :o_grupo_de_estudos, OGrupoDeEstudos.Media.ObjectStorage, adapter: SomeMock

  When the storage leaves Fly for an external provider, a new adapter comes in
  here and nothing else moves.
  """

  alias OGrupoDeEstudos.Media.ObjectStorage.LocalDisk

  @doc "Writes the source file at the key. Overwrites when it already exists."
  @spec put(String.t(), String.t()) :: :ok | {:error, term()}
  def put(key, source_path), do: adapter().put(key, source_path)

  @doc "Deletes the object. Silent when it is already gone."
  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(key), do: adapter().delete(key)

  @spec exists?(String.t()) :: boolean()
  def exists?(key), do: adapter().exists?(key)

  @doc "Keys starting with the prefix."
  @spec list(String.t()) :: [String.t()]
  def list(prefix), do: adapter().list(prefix)

  @doc "Public URL of an object served without authorization."
  @spec public_url(String.t()) :: String.t()
  def public_url(key), do: adapter().public_url(key)

  @doc "How to serve a restricted object: local file or signed redirect."
  @spec serve(String.t()) :: {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}
  def serve(key), do: adapter().serve(key)

  @doc "Runs `fun` with a readable local path of the object."
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
