defmodule OGrupoDeEstudos.Workers.SendPasswordResetEmail do
  use Oban.Worker, queue: :email, max_attempts: 3

  require Logger

  alias OGrupoDeEstudos.{Accounts, Metadata}
  alias OGrupoDeEstudosWeb.Emails.PasswordResetEmail

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "reset_url" => reset_url}}) do
    user = Accounts.get_user_by_id(user_id)

    if is_nil(user) do
      Logger.warning("[PasswordResetEmail] user not found: #{user_id}")
      :ok
    else
      count =
        Metadata.get_integer(Metadata.password_reset_count_name(), "user", user_id)

      Logger.info("[PasswordResetEmail] sending to #{user.email} (reset ##{count})")

      case PasswordResetEmail.new(user, reset_url, count) |> OGrupoDeEstudos.Mailer.deliver() do
        {:ok, _} ->
          Logger.info("[PasswordResetEmail] delivered to #{user.email}")
          :ok

        {:error, reason} ->
          Logger.error("[PasswordResetEmail] failed for #{user.email}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end
