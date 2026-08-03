defmodule OGrupoDeEstudos.Media.Storage do
  @moduledoc """
  Facade for user-uploaded media storage (avatars).

  Delegates to the configured adapter, so callers depend on this stable port
  (`OGrupoDeEstudos.Media.Storage.Behaviour`) rather than a concrete
  filesystem + Mogrify implementation. Defaults to
  `OGrupoDeEstudos.Media.Storage.Local`; tests swap in a Mox mock via:

      config :o_grupo_de_estudos, OGrupoDeEstudos.Media.Storage, adapter: SomeMock

  The adapter is resolved at runtime so a single test can override it.

  ## Usage

      Storage.save_avatar(user_id, tmp_path, ".jpg")
      #=> {:ok, "/uploads/avatars/abc123.jpg"}
  """

  @default_adapter OGrupoDeEstudos.Media.Storage.Local

  @doc "Saves an avatar image. Returns `{:ok, public_url}` or `{:error, reason}`."
  @spec save_avatar(term(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def save_avatar(user_id, tmp_path, ext), do: adapter().save_avatar(user_id, tmp_path, ext)

  @doc "Deletes an avatar file if it exists."
  @spec delete_avatar(term(), String.t()) :: :ok | {:error, term()}
  def delete_avatar(user_id, ext), do: adapter().delete_avatar(user_id, ext)

  @doc "Returns true if the avatar file exists."
  @spec avatar_exists?(term(), String.t()) :: boolean()
  def avatar_exists?(user_id, ext), do: adapter().avatar_exists?(user_id, ext)

  @doc "Returns the base uploads directory for a given subdirectory."
  @spec dir(String.t()) :: String.t()
  def dir(subdir), do: adapter().dir(subdir)

  @doc "Guarda uma imagem numa pasta do storage. Chave opaca."
  def save_image(subdir, tmp_path, ext), do: adapter().save_image(subdir, tmp_path, ext)

  @doc "Apaga uma imagem pela URL pública. Silencioso se já não existe."
  def delete_image(public_url), do: adapter().delete_image(public_url)

  @doc "Guarda um arquivo em pasta privada e devolve a chave opaca."
  def put_private(subdir, tmp_path, ext), do: adapter().put_private(subdir, tmp_path, ext)

  @doc "Caminho no disco de uma chave privada, para o controller servir."
  def private_path(key), do: adapter().private_path(key)

  @doc "Apaga um arquivo privado."
  def delete_private(key), do: adapter().delete_private(key)

  @doc "Bytes livres no volume, ou `:unknown` quando não dá para medir."
  def free_bytes, do: adapter().free_bytes()

  defp adapter do
    :o_grupo_de_estudos
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:adapter, @default_adapter)
  end
end
