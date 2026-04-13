defmodule ForrozinWeb.UserConfirmationController do
  @moduledoc false

  use ForrozinWeb, :controller

  alias Forrozin.Accounts

  @doc "Processa o link de confirmação de email."
  def confirm(conn, %{"token" => token}) do
    ok =
      case Accounts.confirmar_email(token) do
        {:ok, _user} -> true
        {:error, :token_invalido} -> false
      end

    render(conn, :result, ok: ok)
  end
end
