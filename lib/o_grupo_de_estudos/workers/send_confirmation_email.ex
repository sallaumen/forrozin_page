defmodule OGrupoDeEstudos.Workers.SendConfirmationEmail do
  @moduledoc """
  Oban worker that sends the confirmation email after user registration.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudosWeb.Emails.ConfirmationEmail

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    user = Accounts.get_user_by_id(user_id)

    if is_nil(user) do
      Logger.warning("[ConfirmationEmail] user not found: #{user_id}")
      :ok
    else
      Logger.info("[ConfirmationEmail] sending to #{user.email}")

      case ConfirmationEmail.new(user) |> OGrupoDeEstudos.Mailer.deliver() do
        {:ok, _} ->
          Logger.info("[ConfirmationEmail] delivered to #{user.email}")
          :ok

        {:error, reason} ->
          Logger.error("[ConfirmationEmail] failed for #{user.email}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end
