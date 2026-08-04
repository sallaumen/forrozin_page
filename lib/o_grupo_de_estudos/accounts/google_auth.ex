defmodule OGrupoDeEstudos.Accounts.GoogleAuth do
  @moduledoc """
  Google sign-in facade.

  Delegates to the configured adapter, so the web layer depends on this port
  (`OGrupoDeEstudos.Accounts.GoogleAuth.Behaviour`) and not on the OAuth
  library. Defaults to `GoogleAuth.AssentAdapter`; tests swap it through:

      config :o_grupo_de_estudos, OGrupoDeEstudos.Accounts.GoogleAuth, adapter: SomeMock

  Credentials come from the `:google_oauth` application env. When absent,
  `configured?/0` is false and the sign-in button stays hidden.
  """

  @default_adapter OGrupoDeEstudos.Accounts.GoogleAuth.AssentAdapter

  @doc "Whether Google OAuth credentials are configured."
  @spec configured?() :: boolean()
  def configured?, do: Application.get_env(:o_grupo_de_estudos, :google_oauth) != nil

  @doc "URL to send the user to, plus session params for the callback."
  @spec authorize_url() :: {:ok, %{url: String.t(), session_params: map()}} | {:error, term()}
  def authorize_url, do: adapter().authorize_url()

  @doc "Exchanges callback params for a normalized Google profile."
  @spec callback(map(), map()) ::
          {:ok, %{google_id: String.t(), email: String.t(), name: String.t()}}
          | {:error, term()}
  def callback(params, session_params), do: adapter().callback(params, session_params)

  defp adapter do
    :o_grupo_de_estudos
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:adapter, @default_adapter)
  end
end
