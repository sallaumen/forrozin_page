defmodule OGrupoDeEstudos.Workers.SendWaitlistPromotedEmail do
  @moduledoc """
  Emails whoever just left the waitlist into a seat.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  require Logger

  alias OGrupoDeEstudos.{Accounts, Workshops}
  alias OGrupoDeEstudosWeb.Emails.WaitlistPromotedEmail

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "workshop_id" => workshop_id} = args}) do
    with %{} = user <- Accounts.get_user_by_id(user_id),
         %{} = workshop <- Workshops.get_workshop(workshop_id) do
      entregar(user, workshop, reason(args))
    else
      nil ->
        Logger.debug("[WaitlistPromoted] usuário ou workshop sumiu, nada a enviar")
        :ok
    end
  end

  defp reason(%{"reason" => "capacity_increased"}), do: :capacity_increased
  defp reason(_args), do: :seat_freed

  defp entregar(user, workshop, reason) do
    case WaitlistPromotedEmail.new(user, workshop, reason) |> OGrupoDeEstudos.Mailer.deliver() do
      {:ok, _} ->
        :ok

      {:error, deliver_error} ->
        Logger.error("[WaitlistPromoted] falhou para #{user.email}: #{inspect(deliver_error)}")
        {:error, deliver_error}
    end
  end
end
