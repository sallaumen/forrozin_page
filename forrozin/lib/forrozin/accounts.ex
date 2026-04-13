defmodule Forrozin.Accounts do
  @moduledoc """
  Contexto de ação responsável por usuários e autenticação.

  Gerencia registro, confirmação de email, login e consulta de usuários.
  A promoção de papel (user → admin) é feita diretamente no banco.
  """

  alias Forrozin.Accounts.User
  alias Forrozin.Repo
  alias Forrozin.Workers.EnviarEmailConfirmacao

  # ---------------------------------------------------------------------------
  # Registro
  # ---------------------------------------------------------------------------

  @doc """
  Registra um novo usuário e enfileira o email de confirmação.

  Retorna `{:ok, user}` ou `{:error, changeset}`.
  """
  def registrar_usuario(attrs) do
    token = gerar_token()

    changeset =
      %User{}
      |> User.changeset_registro(attrs)
      |> Ecto.Changeset.put_change(:confirmation_token, token)

    case Repo.insert(changeset) do
      {:ok, user} ->
        %{user_id: user.id}
        |> EnviarEmailConfirmacao.new()
        |> Oban.insert()

        {:ok, user}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Confirmação de email
  # ---------------------------------------------------------------------------

  @doc """
  Confirma o email de um usuário pelo token.

  Retorna `{:ok, user}` ou `{:error, :token_invalido}`.
  """
  def confirmar_email(token) do
    case Repo.get_by(User, confirmation_token: token) do
      nil ->
        {:error, :token_invalido}

      user ->
        user
        |> User.changeset_confirmacao()
        |> Repo.update()
    end
  end

  @doc "Retorna `true` se o usuário confirmou o email."
  def email_confirmado?(%User{confirmed_at: confirmed_at}), do: confirmed_at != nil
  def email_confirmado?(_), do: false

  # ---------------------------------------------------------------------------
  # Autenticação
  # ---------------------------------------------------------------------------

  @doc """
  Autentica um usuário pelo nome de usuário e senha.

  Retorna `{:ok, user}` se as credenciais forem válidas,
  `{:error, :credenciais_invalidas}` caso contrário.

  Sempre executa a verificação de senha para evitar timing attacks.
  """
  def autenticar_usuario(nome_usuario, senha) do
    user = Repo.get_by(User, nome_usuario: nome_usuario)
    verificar_senha(user, senha)
  end

  defp verificar_senha(nil, _senha) do
    Argon2.no_user_verify()
    {:error, :credenciais_invalidas}
  end

  defp verificar_senha(user, senha) do
    if Argon2.verify_pass(senha, user.senha_hash) do
      {:ok, user}
    else
      {:error, :credenciais_invalidas}
    end
  end

  # ---------------------------------------------------------------------------
  # Consultas
  # ---------------------------------------------------------------------------

  @doc "Busca um usuário pelo id. Retorna `nil` se não encontrado."
  def buscar_usuario_por_id(id) do
    Repo.get(User, id)
  end

  @doc "Verifica se o usuário tem papel de admin."
  def admin?(%User{papel: "admin"}), do: true
  def admin?(_), do: false

  # ---------------------------------------------------------------------------
  # Privado
  # ---------------------------------------------------------------------------

  defp gerar_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
