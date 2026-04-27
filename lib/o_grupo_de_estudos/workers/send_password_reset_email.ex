defmodule OGrupoDeEstudos.Workers.SendPasswordResetEmail do
  use Oban.Worker, queue: :email, max_attempts: 3

  alias OGrupoDeEstudos.{Accounts, Metadata}
  alias OGrupoDeEstudosWeb.Emails.PasswordResetEmail

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "reset_url" => reset_url}}) do
    user = Accounts.get_user_by_id(user_id)

    if user do
      count = Metadata.get_integer(
        Metadata.password_reset_count_name(),
        "user",
        user_id
      )

      PasswordResetEmail.new(user, reset_url, count)
      |> OGrupoDeEstudos.Mailer.deliver()
    end

    :ok
  end
end
