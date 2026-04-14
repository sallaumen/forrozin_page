defmodule ForrozinWeb.UserSessionController do
  @moduledoc false

  use ForrozinWeb, :controller

  alias Forrozin.Accounts
  alias ForrozinWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, error: nil)
  end

  def create(conn, %{"session" => %{"username" => username, "password" => password}}) do
    case Accounts.authenticate_user(username, password) do
      {:ok, user} ->
        conn
        |> UserAuth.login(user)
        |> put_flash(:info, "Bem-vindo, #{user.username}!")
        |> redirect(to: ~p"/collection")

      {:error, :invalid_credentials} ->
        render(conn, :new, error: "Nome de usuário ou senha inválidos.")
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.logout()
    |> put_flash(:info, "Sessão encerrada.")
    |> redirect(to: ~p"/login")
  end
end
