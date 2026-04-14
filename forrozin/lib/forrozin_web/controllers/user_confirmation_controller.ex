defmodule ForrozinWeb.UserConfirmationController do
  @moduledoc false

  use ForrozinWeb, :controller

  alias Forrozin.Accounts

  @doc "Processa o link de confirmação de email."
  def confirm(conn, %{"token" => token}) do
    ok =
      case Accounts.confirm_email(token) do
        {:ok, _user} -> true
        {:error, :invalid_token} -> false
      end

    render(conn, :result, ok: ok)
  end
end
