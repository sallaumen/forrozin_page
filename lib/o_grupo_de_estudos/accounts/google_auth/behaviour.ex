defmodule OGrupoDeEstudos.Accounts.GoogleAuth.Behaviour do
  @moduledoc "Port for Google sign-in: authorize URL plus callback exchange."

  @type profile :: %{google_id: String.t(), email: String.t(), name: String.t()}

  @callback authorize_url() ::
              {:ok, %{url: String.t(), session_params: map()}} | {:error, term()}
  @callback callback(params :: map(), session_params :: map()) ::
              {:ok, profile()} | {:error, term()}
end
