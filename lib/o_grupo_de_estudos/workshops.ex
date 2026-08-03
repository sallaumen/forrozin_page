defmodule OGrupoDeEstudos.Workshops do
  @moduledoc """
  Workshops: eventos pontuais com inscrição por link.

  Deliberadamente separado de `Study`: inscrito em workshop NÃO é aluno.
  Um professor pode ter 100 inscritos num sábado sem que isso vire vínculo
  de estudo, que é uma relação contínua e de outra natureza.

  Privacidade do pagamento é regra de contexto, não de template: as leituras
  públicas passam por `EnrollmentQuery.list_participants/1`, que nem projeta
  os campos de pagamento.
  """

  import Ecto.Query, only: [from: 2]

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.Engagement.SafeDispatch
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.{EnrollmentQuery, Workshop, WorkshopEnrollment, WorkshopQuery}

  # ── Leituras ──────────────────────────────────────────────────────────

  defdelegate list_feed(opts \\ []), to: WorkshopQuery
  defdelegate list_for_organizer(organizer_id), to: WorkshopQuery
  defdelegate get_by_slug(slug), to: WorkshopQuery
  defdelegate get_workshop(id), to: WorkshopQuery, as: :get
  defdelegate organizer_id(workshop_id), to: WorkshopQuery
  defdelegate slugs_by_ids(ids), to: WorkshopQuery

  defdelegate list_participants(workshop_id), to: EnrollmentQuery
  defdelegate count_enrollments(workshop_id), to: EnrollmentQuery, as: :count
  defdelegate enrollment_counts(workshop_ids), to: EnrollmentQuery, as: :count_by_workshop
  defdelegate enrolled_workshop_ids(user_id), to: EnrollmentQuery
  defdelegate get_enrollment(workshop_id, user_id), to: EnrollmentQuery, as: :get_for_user

  # ── Ciclo de vida do workshop ─────────────────────────────────────────

  @doc "Cria um workshop como rascunho. Qualquer usuário pode."
  @spec create_workshop(User.t(), map()) :: {:ok, Workshop.t()} | {:error, Ecto.Changeset.t()}
  def create_workshop(%User{id: organizer_id}, attrs) do
    %Workshop{}
    |> Workshop.changeset(Map.put(normalize(attrs), :organizer_id, organizer_id))
    |> Repo.insert()
  end

  @doc "Edita um workshop do próprio organizador."
  @spec update_workshop(User.t(), Workshop.t(), map()) ::
          {:ok, Workshop.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def update_workshop(%User{id: actor_id}, %Workshop{organizer_id: actor_id} = workshop, attrs) do
    workshop
    |> Workshop.changeset(normalize(attrs))
    |> Repo.update()
  end

  def update_workshop(%User{}, %Workshop{}, _attrs), do: {:error, :unauthorized}

  @doc "Publica: a partir daqui aparece na agenda e aceita inscrição."
  @spec publish_workshop(User.t(), Workshop.t()) ::
          {:ok, Workshop.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def publish_workshop(%User{id: actor_id}, %Workshop{organizer_id: actor_id} = workshop) do
    workshop |> Workshop.status_changeset(:published) |> Repo.update()
  end

  def publish_workshop(%User{}, %Workshop{}), do: {:error, :unauthorized}

  @doc """
  Cancela preservando o registro: inscrições, quem pagou e a conversa
  continuam existindo. Apagar de vez só faz sentido em rascunho vazio.
  """
  @spec cancel_workshop(User.t(), Workshop.t()) ::
          {:ok, Workshop.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def cancel_workshop(%User{id: actor_id}, %Workshop{organizer_id: actor_id} = workshop) do
    workshop |> Workshop.status_changeset(:cancelled) |> Repo.update()
  end

  def cancel_workshop(%User{}, %Workshop{}), do: {:error, :unauthorized}

  @doc "Apaga de vez. Só rascunho e só sem ninguém inscrito."
  @spec delete_workshop(User.t(), Workshop.t()) ::
          {:ok, Workshop.t()} | {:error, :unauthorized | :not_deletable}
  def delete_workshop(%User{id: actor_id}, %Workshop{organizer_id: actor_id} = workshop) do
    if workshop.status == :draft and EnrollmentQuery.count(workshop.id) == 0 do
      Repo.delete(workshop)
    else
      {:error, :not_deletable}
    end
  end

  def delete_workshop(%User{}, %Workshop{}), do: {:error, :unauthorized}

  # ── Inscrição ─────────────────────────────────────────────────────────

  @doc """
  Inscreve alguém num workshop publicado.

  A vaga é conferida dentro de uma transação com o workshop travado
  (`FOR UPDATE`): o índice único impede a mesma pessoa duas vezes, mas não
  impede duas pessoas diferentes pegarem a última vaga ao mesmo tempo.
  """
  @spec enroll(Workshop.t(), User.t()) ::
          {:ok, WorkshopEnrollment.t()}
          | {:error, :organizer | :not_open | :full | :already_enrolled}
  def enroll(%Workshop{organizer_id: id}, %User{id: id}), do: {:error, :organizer}

  def enroll(%Workshop{} = workshop, %User{} = user) do
    workshop
    |> insert_enrollment_locked(user)
    |> notify_organizer(workshop, user)
  end

  defp insert_enrollment_locked(workshop, user) do
    Repo.transact(fn ->
      with {:ok, locked} <- lock_workshop(workshop.id),
           :ok <- ensure_open(locked),
           :ok <- ensure_has_room(locked) do
        insert_enrollment(locked, user)
      end
    end)
  end

  # Fora da transacao de proposito: broadcast nao faz rollback, entao um erro
  # tardio deixaria o organizador com aviso de uma inscricao inexistente.
  defp notify_organizer({:ok, _enrollment} = result, workshop, user) do
    SafeDispatch.run(fn ->
      Dispatcher.notify_workshop_enrollment(user.id, workshop.organizer_id, workshop.id)
    end)

    result
  end

  defp notify_organizer(error, _workshop, _user), do: error

  @doc "Cancela a própria inscrição, liberando a vaga."
  @spec cancel_enrollment(Workshop.t(), User.t()) ::
          {:ok, WorkshopEnrollment.t()} | {:error, :not_found}
  def cancel_enrollment(%Workshop{id: workshop_id}, %User{id: user_id}) do
    case EnrollmentQuery.get_for_user(workshop_id, user_id) do
      nil -> {:error, :not_found}
      enrollment -> Repo.delete(enrollment)
    end
  end

  # ── Gestão do organizador (privado) ───────────────────────────────────

  @doc "Lista de inscritos COM pagamento. Só o organizador."
  @spec list_enrollments_for_organizer(Workshop.t(), User.t()) ::
          {:ok, [WorkshopEnrollment.t()]} | {:error, :unauthorized}
  def list_enrollments_for_organizer(%Workshop{organizer_id: actor_id} = workshop, %User{
        id: actor_id
      }) do
    {:ok, EnrollmentQuery.list_for_organizer(workshop.id)}
  end

  def list_enrollments_for_organizer(%Workshop{}, %User{}), do: {:error, :unauthorized}

  @doc "Resumo de pagamento (inscritos, pagos, isentos). Só o organizador."
  @spec payment_summary(Workshop.t(), User.t()) :: {:ok, map()} | {:error, :unauthorized}
  def payment_summary(%Workshop{organizer_id: actor_id} = workshop, %User{id: actor_id}) do
    {:ok, EnrollmentQuery.payment_summary(workshop.id)}
  end

  def payment_summary(%Workshop{}, %User{}), do: {:error, :unauthorized}

  @doc """
  Marca o estado de pagamento de uma inscrição.

  A inscrição é buscada com escopo no workshop do organizador, então um id
  forjado de outro evento não encontra nada.
  """
  @spec set_payment_status(Workshop.t(), User.t(), Ecto.UUID.t(), atom()) ::
          {:ok, WorkshopEnrollment.t()}
          | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def set_payment_status(
        %Workshop{organizer_id: actor_id} = workshop,
        %User{id: actor_id},
        enrollment_id,
        status
      )
      when status in [:pending, :paid, :waived] do
    case EnrollmentQuery.get_scoped(enrollment_id, workshop.id) do
      nil -> {:error, :not_found}
      enrollment -> enrollment |> WorkshopEnrollment.payment_changeset(status) |> Repo.update()
    end
  end

  def set_payment_status(%Workshop{}, %User{}, _enrollment_id, _status),
    do: {:error, :unauthorized}

  # ── Privado ───────────────────────────────────────────────────────────

  defp lock_workshop(workshop_id) do
    query = from(w in Workshop, where: w.id == ^workshop_id, lock: "FOR UPDATE")

    case Repo.one(query) do
      nil -> {:error, :not_open}
      workshop -> {:ok, workshop}
    end
  end

  defp ensure_open(%Workshop{status: :published}), do: :ok
  defp ensure_open(%Workshop{}), do: {:error, :not_open}

  defp ensure_has_room(%Workshop{capacity: nil}), do: :ok

  defp ensure_has_room(%Workshop{} = workshop) do
    if Workshop.full?(workshop, EnrollmentQuery.count(workshop.id)) do
      {:error, :full}
    else
      :ok
    end
  end

  defp insert_enrollment(workshop, user) do
    %WorkshopEnrollment{}
    |> WorkshopEnrollment.changeset(%{workshop_id: workshop.id, user_id: user.id})
    |> Repo.insert()
    |> case do
      {:ok, enrollment} ->
        {:ok, enrollment}

      {:error, %Ecto.Changeset{errors: errors}} when is_list(errors) ->
        {:error, :already_enrolled}
    end
  end

  # Aceita chaves atom ou string vindas do form, sem atomizar input.
  defp normalize(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    ArgumentError -> attrs
  end
end
