defmodule OGrupoDeEstudos.Workers.WorkshopReminder do
  @moduledoc """
  Notifies whoever has a workshop tomorrow.

  A daily sweep instead of a job scheduled at enrollment time, for three concrete
  reasons:

  - a workshop cancelled or rescheduled later leaves no zombie job announcing an
    event that will not happen: the sweep reads the current state;
  - cancelling an enrollment requires cancelling no job, because the row is gone;
  - the project has no precedent of `scheduled_at` nor of `Oban.cancel_job`, and
    in test Oban runs `:inline`, which would make a scheduled job fire inside the
    test itself.

  Runs at 12h UTC, which is 9h in Brazil. The message is "there is a workshop
  tomorrow", never "in 24 hours": a workshop at 20h on Friday is announced at 9h
  on Thursday.
  """

  use Oban.Worker, queue: :reminders, max_attempts: 3

  require Logger

  alias OGrupoDeEstudos.{Brazil, Workshops}
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.Engagement.SafeDispatch

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    args
    |> target_day()
    |> notify_for_day()
  end

  # `dia` in the args serves the tests and a manual resend; without it, tomorrow.
  defp target_day(%{"dia" => iso}), do: Date.from_iso8601!(iso)
  defp target_day(_args), do: Date.add(Brazil.today(), 1)

  defp notify_for_day(dia) do
    pendentes = Workshops.pending_reminders(Brazil.day_start_utc(dia), Brazil.day_end_utc(dia))

    Enum.each(pendentes, &notify/1)
    Workshops.mark_reminded(Enum.map(pendentes, fn {enrollment, _, _} -> enrollment.id end))

    Logger.info("[WorkshopReminder] #{length(pendentes)} avisos para #{Date.to_iso8601(dia)}")
    :ok
  end

  # The actor is the organizer: the notification requires actor_id, and
  # "Tavano: tomorrow there is a workshop" reads naturally.
  defp notify({_enrollment, workshop, user}) do
    SafeDispatch.run(fn ->
      Dispatcher.notify_workshop_reminder(workshop.organizer_id, user.id, workshop.id)
    end)

    Oban.insert(
      OGrupoDeEstudos.Workers.SendWorkshopReminderEmail.new(%{
        "user_id" => user.id,
        "workshop_id" => workshop.id
      })
    )
  end
end
