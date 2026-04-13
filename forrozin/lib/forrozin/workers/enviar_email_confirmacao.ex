defmodule Forrozin.Workers.EnviarEmailConfirmacao do
  @moduledoc """
  Worker Oban responsável por enviar o email de confirmação de conta.

  Enfileirado automaticamente após o cadastro de um novo usuário.
  Fila: `:email` — máximo 3 tentativas.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  alias Forrozin.Accounts
  alias Forrozin.Mailer
  alias ForrozinWeb.Emails.ConfirmacaoEmail

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    case Accounts.buscar_usuario_por_id(user_id) do
      nil ->
        # Usuário removido após o job ser enfileirado — descartar silenciosamente
        :ok

      user ->
        user
        |> ConfirmacaoEmail.novo()
        |> Mailer.deliver()

        :ok
    end
  end
end
