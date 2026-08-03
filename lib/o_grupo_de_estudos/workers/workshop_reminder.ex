defmodule OGrupoDeEstudos.Workers.WorkshopReminder do
  @moduledoc """
  Avisa quem tem workshop amanhã.

  Varredura diária em vez de job agendado no momento da inscrição, por três
  motivos concretos:

  - workshop cancelado ou remarcado depois não deixa job zumbi avisando sobre
    evento que não vai acontecer: a varredura lê o estado atual;
  - cancelar inscrição não exige cancelar job nenhum, porque a linha some;
  - o projeto não tem nenhum precedente de `scheduled_at` nem de
    `Oban.cancel_job`, e em teste o Oban roda `:inline`, o que faria um job
    agendado disparar dentro do próprio teste.

  Roda às 12h UTC, que é 9h em Brasília. A mensagem é "amanhã tem workshop",
  nunca "em 24 horas": um workshop das 20h de sexta avisa às 9h de quinta.
  """

  use Oban.Worker, queue: :reminders, max_attempts: 3

  require Logger

  alias OGrupoDeEstudos.{Brazil, Workshops}
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.Engagement.SafeDispatch

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    args
    |> dia_alvo()
    |> avisar_do_dia()
  end

  # `dia` nos args serve aos testes e a um reenvio manual; sem ele, amanhã.
  defp dia_alvo(%{"dia" => iso}), do: Date.from_iso8601!(iso)
  defp dia_alvo(_args), do: Date.add(Brazil.today(), 1)

  defp avisar_do_dia(dia) do
    pendentes = Workshops.pending_reminders(Brazil.day_start_utc(dia), Brazil.day_end_utc(dia))

    Enum.each(pendentes, &avisar/1)
    Workshops.mark_reminded(Enum.map(pendentes, fn {inscricao, _, _} -> inscricao.id end))

    Logger.info("[WorkshopReminder] #{length(pendentes)} avisos para #{Date.to_iso8601(dia)}")
    :ok
  end

  # O ator e o organizador: a notificacao exige actor_id e "Tavano: amanha tem
  # workshop" le natural.
  defp avisar({_inscricao, workshop, user}) do
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
