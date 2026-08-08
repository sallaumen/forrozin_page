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
  def perform(%Oban.Job{args: %{"dia" => iso}}) do
    dia = Date.from_iso8601!(iso)
    notify_for_day(dia, flavor_for(dia))
  end

  # Two sweeps: tomorrow (the classic day-before notice) and today, which
  # catches whoever enrolled after yesterday's sweep had already run. Without
  # the second pass, a workshop announced the evening before reminds nobody.
  def perform(%Oban.Job{}) do
    today = Brazil.today()

    notify_for_day(Date.add(today, 1), :tomorrow)
    notify_for_day(today, :today)
  end

  defp flavor_for(dia) do
    if Date.compare(dia, Brazil.today()) == :eq, do: :today, else: :tomorrow
  end

  defp notify_for_day(dia, flavor) do
    pendentes = Workshops.pending_reminders(Brazil.day_start_utc(dia), Brazil.day_end_utc(dia))

    Enum.each(pendentes, &notify(&1, flavor))
    Workshops.mark_reminded(Enum.map(pendentes, fn {enrollment, _, _} -> enrollment.id end))

    Logger.info("[WorkshopReminder] #{length(pendentes)} avisos para #{Date.to_iso8601(dia)}")
    :ok
  end

  # The actor is the organizer: the notification requires actor_id, and
  # "Tavano: tomorrow there is a workshop" reads naturally.
  defp notify({_enrollment, workshop, user}, flavor) do
    SafeDispatch.run(fn ->
      Dispatcher.notify_workshop_reminder(workshop.organizer_id, user.id, workshop.id, flavor)
    end)

    Oban.insert(
      OGrupoDeEstudos.Workers.SendWorkshopReminderEmail.new(%{
        "user_id" => user.id,
        "workshop_id" => workshop.id,
        "flavor" => Atom.to_string(flavor)
      })
    )
  end
end
