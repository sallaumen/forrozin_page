defmodule OGrupoDeEstudosWeb.UserSessionController do
  @moduledoc false

  use OGrupoDeEstudosWeb, :controller

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudosWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, error: nil)
  end

  def create(conn, %{"session" => %{"username" => username, "password" => password}}) do
    case Accounts.check_credentials(username, password) do
      {:ok, user} ->
        conn
        |> UserAuth.login(user)
        |> put_flash(:info, "Bem-vindo, #{user.username}!")
        |> redirect(to: ~p"/collection")

      {:error, :invalid_credentials} ->
        render(conn, :new, error: "Nome de usuário ou senha inválidos.")
    end
  end

  def auto_login(conn, %{"user_id" => user_id}) do
    case Accounts.get_user_by_id(user_id) do
      nil ->
        conn |> redirect(to: ~p"/login")

      user ->
        conn
        |> UserAuth.login(user)
        |> redirect(to: ~p"/collection")
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.logout()
    |> put_flash(:info, "Sessão encerrada.")
    |> redirect(to: ~p"/login")
  end
end
