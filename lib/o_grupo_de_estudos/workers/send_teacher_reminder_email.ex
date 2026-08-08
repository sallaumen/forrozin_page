defmodule OGrupoDeEstudos.Workers.SendTeacherReminderEmail do
  @moduledoc """
  Sends the class summary to one teacher or organizer of a workshop.

  The roster and the counts are loaded at send time, so the summary shows
  the enrollment picture of the moment it goes out, not of the sweep.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  require Logger

  alias OGrupoDeEstudos.{Accounts, Workshops}
  alias OGrupoDeEstudosWeb.Emails.TeacherReminderEmail

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "workshop_id" => workshop_id} = args}) do
    with %{} = user <- Accounts.get_user_by_id(user_id),
         %{} = workshop <- Workshops.get_workshop(workshop_id) do
      entregar(user, workshop, flavor(args))
    else
      nil ->
        Logger.debug("[TeacherReminder] usuário ou workshop sumiu, nada a enviar")
        :ok
    end
  end

  defp flavor(%{"flavor" => "today"}), do: :today
  defp flavor(_args), do: :tomorrow

  defp entregar(user, workshop, flavor) do
    participants = Workshops.list_participants(workshop.id)
    waitlist_count = Workshops.waitlist_count(workshop.id)

    email = TeacherReminderEmail.new(user, workshop, participants, waitlist_count, flavor: flavor)

    case OGrupoDeEstudos.Mailer.deliver(email) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error("[TeacherReminder] falhou para #{user.email}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
