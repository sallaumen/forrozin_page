defmodule OGrupoDeEstudos.Workers.SendWorkshopReminderEmail do
  @moduledoc """
  Sends the "there is a workshop tomorrow" email.

  Email and not push: push requires VAPID, a subscription table and, on the
  iPhone, the app installed on the home screen. Email already works in production
  and reaches everyone.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  require Logger

  alias OGrupoDeEstudos.{Accounts, Workshops}
  alias OGrupoDeEstudosWeb.Emails.WorkshopReminderEmail

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "workshop_id" => workshop_id}}) do
    with %{} = user <- Accounts.get_user_by_id(user_id),
         %{} = workshop <- Workshops.get_workshop(workshop_id) do
      entregar(user, workshop)
    else
      nil ->
        Logger.debug("[WorkshopReminder] usuário ou workshop sumiu, nada a enviar")
        :ok
    end
  end

  defp entregar(user, workshop) do
    case user |> WorkshopReminderEmail.new(workshop) |> OGrupoDeEstudos.Mailer.deliver() do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error("[WorkshopReminder] falhou para #{user.email}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
