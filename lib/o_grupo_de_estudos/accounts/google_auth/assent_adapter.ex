defmodule OGrupoDeEstudos.Accounts.GoogleAuth.AssentAdapter do
  @moduledoc """
  Google sign-in through Assent's Google strategy.

  Refuses profiles whose email Google has not verified: linking accounts by
  email trusts that verification.
  """

  @behaviour OGrupoDeEstudos.Accounts.GoogleAuth.Behaviour

  @impl true
  def authorize_url do
    Assent.Strategy.Google.authorize_url(config())
  end

  @impl true
  def callback(params, session_params) do
    config()
    |> Keyword.put(:session_params, session_params)
    |> Assent.Strategy.Google.callback(params)
    |> normalize()
  end

  defp normalize({:ok, %{user: %{"email_verified" => true} = claims}}) do
    {:ok, %{google_id: claims["sub"], email: claims["email"], name: claims["name"]}}
  end

  defp normalize({:ok, _unverified_profile}), do: {:error, :email_not_verified}
  defp normalize({:error, error}), do: {:error, error}

  defp config do
    :o_grupo_de_estudos
    |> Application.get_env(:google_oauth, [])
    |> Keyword.put(:redirect_uri, OGrupoDeEstudosWeb.Endpoint.url() <> "/auth/google/callback")
  end
end
