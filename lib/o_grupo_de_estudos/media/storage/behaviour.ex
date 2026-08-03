defmodule OGrupoDeEstudos.Media.Storage.Behaviour do
  @moduledoc """
  Port for user-media storage.

  Adapters implement these callbacks; `OGrupoDeEstudos.Media.Storage` delegates
  to the configured adapter (`Local` in dev/prod, a Mox mock in tests). This
  keeps the domain depending on a project-owned port instead of a concrete
  filesystem + Mogrify implementation (hexagonal edge / Iron Law: wrap
  third-party APIs behind project modules).
  """

  @callback save_avatar(user_id :: term(), tmp_path :: String.t(), ext :: String.t()) ::
              {:ok, String.t()} | {:error, term()}
  @callback delete_avatar(user_id :: term(), ext :: String.t()) :: :ok | {:error, term()}
  @callback avatar_exists?(user_id :: term(), ext :: String.t()) :: boolean()
  @callback dir(subdir :: String.t()) :: String.t()

  @doc """
  Guarda uma imagem redimensionada numa pasta do storage e devolve a URL
  pública. A chave é opaca: nada de id previsível no nome do arquivo.
  """
  @callback save_image(subdir :: String.t(), tmp_path :: String.t(), ext :: String.t()) ::
              {:ok, String.t()} | {:error, term()}

  @callback delete_image(public_url :: String.t()) :: :ok | {:error, term()}
end
