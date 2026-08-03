defmodule OGrupoDeEstudos.Workshops.EnrollmentQuery do
  @moduledoc """
  Leituras de `WorkshopEnrollment`.

  A separação aqui é de privacidade, não de conveniência: `list_participants/1`
  projeta explicitamente só o que pode ser público, e é a única leitura que a
  página do workshop usa. Pagamento só sai por `list_for_organizer/1`, que o
  contexto chama depois de autorizar o dono.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.WorkshopEnrollment

  @doc """
  `%{program_id => quantos}`: em quantos workshops de cada programação a
  pessoa está inscrita.

  Em lote de propósito: uma consulta por programação na agenda seria N+1.
  """
  @spec enrolled_counts_by_program(Ecto.UUID.t() | nil, [Ecto.UUID.t()]) :: %{
          Ecto.UUID.t() => non_neg_integer()
        }
  def enrolled_counts_by_program(nil, _program_ids), do: %{}
  def enrolled_counts_by_program(_user_id, []), do: %{}

  def enrolled_counts_by_program(user_id, program_ids) do
    from(e in WorkshopEnrollment,
      join: w in assoc(e, :workshop),
      where: e.user_id == ^user_id and w.program_id in ^program_ids,
      group_by: w.program_id,
      select: {w.program_id, count(e.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "Participantes visíveis publicamente: sem nenhum campo de pagamento."
  @spec list_participants(Ecto.UUID.t()) :: [map()]
  def list_participants(workshop_id) do
    from(e in WorkshopEnrollment,
      join: u in assoc(e, :user),
      where: e.workshop_id == ^workshop_id,
      order_by: [asc: e.inserted_at],
      select: %{
        id: e.id,
        user_id: u.id,
        name: u.name,
        username: u.username,
        avatar_path: u.avatar_path,
        enrolled_at: e.inserted_at
      }
    )
    |> Repo.all()
  end

  @doc "Lista completa do organizador, com o estado de pagamento."
  @spec list_for_organizer(Ecto.UUID.t()) :: [WorkshopEnrollment.t()]
  def list_for_organizer(workshop_id) do
    from(e in WorkshopEnrollment,
      where: e.workshop_id == ^workshop_id,
      order_by: [asc: e.inserted_at],
      preload: [:user]
    )
    |> Repo.all()
  end

  @doc """
  Inscrição por id, restrita ao workshop dado.

  O `workshop_id` vem sempre do mount (nunca do cliente): sem esse escopo,
  um organizador poderia marcar pagamento numa inscrição de outro evento.
  """
  @spec get_scoped(Ecto.UUID.t(), Ecto.UUID.t()) :: WorkshopEnrollment.t() | nil
  def get_scoped(enrollment_id, workshop_id) do
    case Ecto.UUID.cast(enrollment_id) do
      {:ok, uuid} ->
        WorkshopEnrollment
        |> where([e], e.id == ^uuid and e.workshop_id == ^workshop_id)
        |> Repo.one()

      :error ->
        nil
    end
  end

  @doc "Inscrição de uma pessoa específica num workshop, ou nil."
  @spec get_for_user(Ecto.UUID.t(), Ecto.UUID.t()) :: WorkshopEnrollment.t() | nil
  def get_for_user(workshop_id, user_id) do
    Repo.get_by(WorkshopEnrollment, workshop_id: workshop_id, user_id: user_id)
  end

  @doc "Quantas pessoas estão inscritas."
  @spec count(Ecto.UUID.t()) :: non_neg_integer()
  def count(workshop_id) do
    WorkshopEnrollment
    |> where([e], e.workshop_id == ^workshop_id)
    |> Repo.aggregate(:count)
  end

  @doc "Contagem por workshop, em lote (evita N+1 na agenda)."
  @spec count_by_workshop([Ecto.UUID.t()]) :: %{Ecto.UUID.t() => non_neg_integer()}
  def count_by_workshop([]), do: %{}

  def count_by_workshop(workshop_ids) do
    from(e in WorkshopEnrollment,
      where: e.workshop_id in ^workshop_ids,
      group_by: e.workshop_id,
      select: {e.workshop_id, count(e.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "Resumo de pagamento do organizador: inscritos, pagos e isentos."
  @spec payment_summary(Ecto.UUID.t()) :: %{total: integer(), paid: integer(), waived: integer()}
  def payment_summary(workshop_id) do
    from(e in WorkshopEnrollment,
      where: e.workshop_id == ^workshop_id,
      select: %{
        total: count(e.id),
        paid: filter(count(e.id), e.payment_status == :paid),
        waived: filter(count(e.id), e.payment_status == :waived)
      }
    )
    |> Repo.one()
  end

  @doc "MapSet dos workshops em que a pessoa está inscrita."
  @spec enrolled_workshop_ids(Ecto.UUID.t()) :: MapSet.t()
  def enrolled_workshop_ids(user_id) do
    from(e in WorkshopEnrollment,
      where: e.user_id == ^user_id,
      select: e.workshop_id
    )
    |> Repo.all()
    |> MapSet.new()
  end
end
