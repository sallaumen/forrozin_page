defmodule OGrupoDeEstudos.Workers.SendProgramEnrolledEmail do
  @moduledoc """
  Emails the enrollment confirmation for a program, listing the covered
  workshops (the whole package or the hand-picked subset).
  """

  # Unique per person and program for a day, so a leave-and-return does not
  # repeat the same confirmation.
  use Oban.Worker,
    queue: :email,
    max_attempts: 3,
    unique: [period: 86_400, keys: [:user_id, :program_id]]

  require Logger

  alias OGrupoDeEstudos.{Accounts, Workshops}
  alias OGrupoDeEstudosWeb.Emails.ProgramEnrolledEmail

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"user_id" => user_id, "program_id" => program_id, "workshop_ids" => workshop_ids}
      }) do
    with %{} = user <- Accounts.get_user_by_id(user_id),
         %{} = program <- Workshops.get_program(program_id),
         [_ | _] = workshops <- Workshops.list_program_workshops_scoped(program_id, workshop_ids) do
      entregar(user, program, workshops)
    else
      _missing ->
        Logger.debug("[ProgramEnrolled] usuário, programação ou aulas sumiram, nada a enviar")
        :ok
    end
  end

  defp entregar(user, program, workshops) do
    case ProgramEnrolledEmail.new(user, program, workshops) |> OGrupoDeEstudos.Mailer.deliver() do
      {:ok, _} ->
        :ok

      {:error, deliver_error} ->
        Logger.error("[ProgramEnrolled] falhou para #{user.email}: #{inspect(deliver_error)}")
        {:error, deliver_error}
    end
  end
end
