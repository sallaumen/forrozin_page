defmodule Forrozin.Workers.SendConfirmationEmail do
  @moduledoc """
  Oban worker that sends the confirmation email after user registration.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  alias Forrozin.Accounts
  alias ForrozinWeb.Emails.ConfirmationEmail

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    user = Accounts.get_user_by_id(user_id)

    if user do
      ConfirmationEmail.new(user) |> Forrozin.Mailer.deliver()
    end

    :ok
  end
end
