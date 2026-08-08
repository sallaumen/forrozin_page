defmodule OGrupoDeEstudos.Workers.SendWorkshopEnrolledEmail do
  @moduledoc """
  Emails the enrollment confirmation for a single workshop.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  require Logger

  alias OGrupoDeEstudos.{Accounts, Workshops}
  alias OGrupoDeEstudosWeb.Emails.WorkshopEnrolledEmail

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "workshop_id" => workshop_id}}) do
    with %{} = user <- Accounts.get_user_by_id(user_id),
         %{} = workshop <- Workshops.get_workshop(workshop_id) do
      entregar(user, workshop)
    else
      nil ->
        Logger.debug("[WorkshopEnrolled] usuário ou workshop sumiu, nada a enviar")
        :ok
    end
  end

  defp entregar(user, workshop) do
    case WorkshopEnrolledEmail.new(user, workshop) |> OGrupoDeEstudos.Mailer.deliver() do
      {:ok, _} ->
        :ok

      {:error, deliver_error} ->
        Logger.error("[WorkshopEnrolled] falhou para #{user.email}: #{inspect(deliver_error)}")
        {:error, deliver_error}
    end
  end
end
