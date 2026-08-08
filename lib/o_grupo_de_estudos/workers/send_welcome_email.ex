defmodule OGrupoDeEstudos.Workers.SendWelcomeEmail do
  @moduledoc """
  Oban worker that sends the welcome email after registration.

  Password signups get the confirmation link inside it; Google signups get
  the no-password note instead.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudosWeb.Emails.WelcomeEmail

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    user = Accounts.get_user_by_id(user_id)

    if is_nil(user) do
      Logger.debug("[WelcomeEmail] user not found: #{user_id}")
      :ok
    else
      Logger.info("[WelcomeEmail] sending to #{user.email}")

      case WelcomeEmail.new(user) |> OGrupoDeEstudos.Mailer.deliver() do
        {:ok, _} ->
          Logger.info("[WelcomeEmail] delivered to #{user.email}")
          :ok

        {:error, reason} ->
          Logger.error("[WelcomeEmail] failed for #{user.email}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end
