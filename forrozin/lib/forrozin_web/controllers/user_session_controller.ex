defmodule ForrozinWeb.UserSessionController do
  @moduledoc false

  use ForrozinWeb, :controller

  alias Forrozin.Accounts
  alias ForrozinWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, error: nil)
  end

  def create(conn, %{"session" => %{"nome_usuario" => nome, "senha" => senha}}) do
    case Accounts.autenticar_usuario(nome, senha) do
      {:ok, user} ->
        conn
        |> UserAuth.login(user)
        |> put_flash(:info, "Bem-vindo, #{user.nome_usuario}!")
        |> redirect(to: ~p"/acervo")

      {:error, :credenciais_invalidas} ->
        render(conn, :new, error: "Nome de usuário ou senha inválidos.")
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.logout()
    |> put_flash(:info, "Sessão encerrada.")
    |> redirect(to: ~p"/entrar")
  end
end
