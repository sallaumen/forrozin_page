defmodule OGrupoDeEstudosWeb.UserConfirmationController do
  @moduledoc false

  use OGrupoDeEstudosWeb, :controller

  alias OGrupoDeEstudos.Accounts

  @doc "Processa o link de confirmação de email."
  def confirm(conn, %{"token" => token}) do
    ok =
      case Accounts.validate_confirmation_token(token) do
        {:ok, _user} -> true
        {:error, :invalid_token} -> false
      end

    render(conn, :result, ok: ok)
  end
end
