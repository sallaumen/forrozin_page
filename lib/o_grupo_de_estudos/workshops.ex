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

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.Engagement.SafeDispatch
  alias OGrupoDeEstudos.Media.Storage
  alias OGrupoDeEstudos.Repo

  alias OGrupoDeEstudos.Workshops.{
    Access,
    AdminQuery,
    EnrollmentQuery,
    ProgramQuery,
    Workshop,
    WorkshopAdmin,
    WorkshopEnrollment,
    WorkshopProgram,
    WorkshopQuery
  }

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
  def update_workshop(%User{} = user, %Workshop{} = workshop, attrs) do
    with :ok <- ensure_admin(workshop, user) do
      workshop
      |> Workshop.changeset(normalize(attrs))
      |> Repo.update()
    end
  end

  @doc "Publica: a partir daqui aparece na agenda e aceita inscrição."
  @spec publish_workshop(User.t(), Workshop.t()) ::
          {:ok, Workshop.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def publish_workshop(%User{} = user, %Workshop{} = workshop) do
    with :ok <- ensure_admin(workshop, user) do
      workshop |> Workshop.status_changeset(:published) |> Repo.update()
    end
  end

  @doc """
  Cancela preservando o registro: inscrições, quem pagou e a conversa
  continuam existindo. Apagar de vez só faz sentido em rascunho vazio.
  """
  @spec cancel_workshop(User.t(), Workshop.t()) ::
          {:ok, Workshop.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def cancel_workshop(%User{} = user, %Workshop{} = workshop) do
    with :ok <- ensure_admin(workshop, user) do
      workshop |> Workshop.status_changeset(:cancelled) |> Repo.update()
    end
  end

  @doc """
  Apaga de vez. Só rascunho, só sem ninguém inscrito, e só quem criou.

  De propósito fora do conjunto de administradores: co-organizador administra,
  não destrói.
  """
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

  # ── Flyer ─────────────────────────────────────────────────────────────

  @flyer_dir "flyers"

  @doc """
  Guarda o flyer de divulgação do workshop e apaga o anterior.

  Recebe o arquivo temporário do upload, não um caminho escolhido pelo
  usuário: quem decide onde o arquivo mora é o storage.
  """
  @spec put_workshop_flyer(Workshop.t(), User.t(), String.t(), String.t()) ::
          {:ok, Workshop.t()} | {:error, :unauthorized | term()}
  def put_workshop_flyer(%Workshop{} = workshop, %User{} = user, tmp_path, ext) do
    with :ok <- ensure_admin(workshop, user),
         {:ok, url} <- Storage.save_image(@flyer_dir, tmp_path, ext) do
      antigo = workshop.flyer_path
      resultado = workshop |> Workshop.flyer_changeset(url) |> Repo.update()
      descartar_flyer(resultado, antigo)
    end
  end

  @doc "Tira o flyer do workshop e apaga o arquivo."
  @spec remove_workshop_flyer(Workshop.t(), User.t()) ::
          {:ok, Workshop.t()} | {:error, :unauthorized | term()}
  def remove_workshop_flyer(%Workshop{} = workshop, %User{} = user) do
    with :ok <- ensure_admin(workshop, user) do
      antigo = workshop.flyer_path
      resultado = workshop |> Workshop.flyer_changeset(nil) |> Repo.update()
      descartar_flyer(resultado, antigo)
    end
  end

  @doc "Guarda o flyer da programação e apaga o anterior."
  @spec put_program_flyer(WorkshopProgram.t(), User.t(), String.t(), String.t()) ::
          {:ok, WorkshopProgram.t()} | {:error, :unauthorized | term()}
  def put_program_flyer(%WorkshopProgram{} = program, %User{} = user, tmp_path, ext) do
    with :ok <- ensure_program_owner(program, user),
         {:ok, url} <- Storage.save_image(@flyer_dir, tmp_path, ext) do
      antigo = program.flyer_path
      resultado = program |> WorkshopProgram.flyer_changeset(url) |> Repo.update()
      descartar_flyer(resultado, antigo)
    end
  end

  @doc "Tira o flyer da programação e apaga o arquivo."
  @spec remove_program_flyer(WorkshopProgram.t(), User.t()) ::
          {:ok, WorkshopProgram.t()} | {:error, :unauthorized | term()}
  def remove_program_flyer(%WorkshopProgram{} = program, %User{} = user) do
    with :ok <- ensure_program_owner(program, user) do
      antigo = program.flyer_path
      resultado = program |> WorkshopProgram.flyer_changeset(nil) |> Repo.update()
      descartar_flyer(resultado, antigo)
    end
  end

  # So apaga o arquivo antigo depois que o banco confirmou. Ao contrario, um
  # erro de update deixaria a linha apontando para arquivo que nao existe mais.
  defp descartar_flyer({:ok, _} = resultado, nil), do: resultado

  defp descartar_flyer({:ok, _} = resultado, antigo) do
    Storage.delete_image(antigo)
    resultado
  end

  defp descartar_flyer(erro, _antigo), do: erro

  # ── Programação ───────────────────────────────────────────────────────

  defdelegate get_program_by_slug(slug), to: ProgramQuery, as: :get_by_slug
  defdelegate get_program(id), to: ProgramQuery, as: :get
  defdelegate list_programs_for_owner(owner_id), to: ProgramQuery, as: :list_for_owner
  defdelegate program_summaries(program_ids), to: ProgramQuery, as: :summaries_by_ids

  @doc "Workshops da programação, do mais cedo ao mais tarde."
  @spec list_program_workshops(WorkshopProgram.t(), keyword()) :: [Workshop.t()]
  def list_program_workshops(%WorkshopProgram{} = program, opts \\ []),
    do: ProgramQuery.list_workshops(program.id, opts)

  @doc "Cria uma programação. Qualquer pessoa com conta pode."
  @spec create_program(User.t(), map()) ::
          {:ok, WorkshopProgram.t()} | {:error, Ecto.Changeset.t()}
  def create_program(%User{id: owner_id}, attrs) do
    %WorkshopProgram{}
    |> WorkshopProgram.changeset(Map.put(attrs, :owner_id, owner_id))
    |> Repo.insert()
  end

  @doc "Edita a programação. Só quem criou."
  @spec update_program(User.t(), WorkshopProgram.t(), map()) ::
          {:ok, WorkshopProgram.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def update_program(%User{} = user, %WorkshopProgram{} = program, attrs) do
    with :ok <- ensure_program_owner(program, user) do
      program |> WorkshopProgram.changeset(attrs) |> Repo.update()
    end
  end

  @doc "Publica: a partir daqui o link abre para quem não tem conta."
  @spec publish_program(User.t(), WorkshopProgram.t()) ::
          {:ok, WorkshopProgram.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def publish_program(%User{} = user, %WorkshopProgram{} = program) do
    with :ok <- ensure_program_owner(program, user) do
      program |> WorkshopProgram.status_changeset(:published) |> Repo.update()
    end
  end

  @doc "Cancela a programação. Os workshops dentro continuam existindo."
  @spec cancel_program(User.t(), WorkshopProgram.t()) ::
          {:ok, WorkshopProgram.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def cancel_program(%User{} = user, %WorkshopProgram{} = program) do
    with :ok <- ensure_program_owner(program, user) do
      program |> WorkshopProgram.status_changeset(:cancelled) |> Repo.update()
    end
  end

  @doc """
  Põe um workshop na programação.

  Exige administrar os dois lados. É assim que um festival funciona: a equipe
  vira co-organizadora do workshop de cada professor e monta a programação.
  """
  @spec attach_workshop(WorkshopProgram.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, Workshop.t()} | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def attach_workshop(%WorkshopProgram{} = program, %User{} = user, workshop_id) do
    move_workshop(program, user, workshop_id, program.id)
  end

  @doc "Tira o workshop da programação. Ele continua existindo, solto."
  @spec detach_workshop(WorkshopProgram.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, Workshop.t()} | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def detach_workshop(%WorkshopProgram{} = program, %User{} = user, workshop_id) do
    move_workshop(program, user, workshop_id, nil)
  end

  defp move_workshop(program, user, workshop_id, program_id) do
    with :ok <- ensure_program_owner(program, user),
         %Workshop{} = workshop <- WorkshopQuery.get(workshop_id),
         :ok <- ensure_admin(workshop, user) do
      workshop |> Ecto.Changeset.change(program_id: program_id) |> Repo.update()
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_program_owner(%WorkshopProgram{owner_id: id}, %User{id: id}), do: :ok
  defp ensure_program_owner(%WorkshopProgram{}, %User{}), do: {:error, :unauthorized}

  # ── Administradores ───────────────────────────────────────────────────

  @doc "Ids de quem administra: o criador mais os co-organizadores."
  @spec admin_ids(Workshop.t()) :: [Ecto.UUID.t()]
  def admin_ids(%Workshop{} = workshop) do
    [workshop.organizer_id | AdminQuery.co_admin_ids(workshop.id)]
  end

  @doc "true quando a pessoa administra o workshop (criador ou co-organizador)."
  @spec admin?(Workshop.t(), User.t() | nil) :: boolean()
  def admin?(%Workshop{}, nil), do: false
  def admin?(%Workshop{organizer_id: id}, %User{id: id}), do: true

  def admin?(%Workshop{} = workshop, %User{} = user),
    do: AdminQuery.co_admin?(workshop.id, user.id)

  @doc """
  Resolve numa passada o que a pessoa pode fazer neste workshop.

  A Policy é pura e não consulta o banco; este struct traz os fatos.
  """
  @spec access_for(Workshop.t(), User.t() | nil) :: Access.t()
  def access_for(%Workshop{} = workshop, user) do
    %Access{
      workshop: workshop,
      user_id: user && user.id,
      owner?: owner?(workshop, user),
      admin?: admin?(workshop, user),
      enrolled?: enrolled?(workshop, user)
    }
  end

  defp owner?(%Workshop{organizer_id: id}, %User{id: id}), do: true
  defp owner?(%Workshop{}, _user), do: false

  defp enrolled?(%Workshop{}, nil), do: false

  defp enrolled?(%Workshop{} = workshop, %User{} = user),
    do: not is_nil(EnrollmentQuery.get_for_user(workshop.id, user.id))

  @doc "Co-organizadores com dados de exibição."
  @spec list_co_admins(Workshop.t()) :: [map()]
  def list_co_admins(%Workshop{} = workshop), do: AdminQuery.list_co_admins(workshop.id)

  @doc """
  Promove alguém a co-organizador. Só o criador promove: quem entra por
  convite passa a ver o controle de pagamento, e essa porta é de quem criou.
  """
  @spec add_admin(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, WorkshopAdmin.t()} | {:error, :unauthorized | :already_admin | :not_found}
  def add_admin(%Workshop{} = workshop, %User{} = actor, user_id) do
    with :ok <- ensure_owner(workshop, actor),
         :ok <- ensure_not_admin(workshop, user_id),
         %User{} = user <- Accounts.get_user_by_id(user_id) do
      insert_admin(workshop, actor, user)
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_admin(workshop, actor, user) do
    %WorkshopAdmin{}
    |> WorkshopAdmin.changeset(%{
      workshop_id: workshop.id,
      user_id: user.id,
      invited_by_id: actor.id
    })
    |> Repo.insert()
    |> case do
      {:ok, admin} -> {:ok, admin}
      {:error, %Ecto.Changeset{}} -> {:error, :already_admin}
    end
  end

  @doc "Remove um co-organizador. O criador remove qualquer um; os outros só a si mesmos."
  @spec remove_admin(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, WorkshopAdmin.t()} | {:error, :unauthorized | :cannot_remove_owner | :not_found}
  def remove_admin(%Workshop{organizer_id: id}, %User{}, id), do: {:error, :cannot_remove_owner}

  def remove_admin(%Workshop{} = workshop, %User{} = actor, user_id) do
    with :ok <- ensure_can_remove(workshop, actor, user_id) do
      AdminQuery.delete(workshop.id, user_id)
    end
  end

  defp ensure_can_remove(workshop, %User{id: actor_id}, actor_id) do
    if admin?(workshop, %User{id: actor_id}), do: :ok, else: {:error, :unauthorized}
  end

  defp ensure_can_remove(workshop, actor, _user_id), do: ensure_owner(workshop, actor)

  defp ensure_owner(%Workshop{organizer_id: id}, %User{id: id}), do: :ok
  defp ensure_owner(%Workshop{}, %User{}), do: {:error, :unauthorized}

  defp ensure_admin(workshop, user) do
    if admin?(workshop, user), do: :ok, else: {:error, :unauthorized}
  end

  defp ensure_not_admin(workshop, user_id) do
    if user_id in admin_ids(workshop), do: {:error, :already_admin}, else: :ok
  end

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
  def enroll(%Workshop{} = workshop, %User{} = user) do
    case admin?(workshop, user) do
      true -> {:error, :organizer}
      false -> workshop |> insert_enrollment_locked(user) |> notify_organizers(workshop, user)
    end
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
  defp notify_organizers({:ok, _enrollment} = result, workshop, user) do
    SafeDispatch.run(fn ->
      Dispatcher.notify_workshop_enrollment(user.id, admin_ids(workshop), workshop.id)
    end)

    result
  end

  defp notify_organizers(error, _workshop, _user), do: error

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
  def list_enrollments_for_organizer(%Workshop{} = workshop, %User{} = user) do
    with :ok <- ensure_admin(workshop, user) do
      {:ok, EnrollmentQuery.list_for_organizer(workshop.id)}
    end
  end

  @doc "Resumo de pagamento (inscritos, pagos, isentos). Quem administra vê."
  @spec payment_summary(Workshop.t(), User.t()) :: {:ok, map()} | {:error, :unauthorized}
  def payment_summary(%Workshop{} = workshop, %User{} = user) do
    with :ok <- ensure_admin(workshop, user) do
      {:ok, EnrollmentQuery.payment_summary(workshop.id)}
    end
  end

  @doc """
  Marca o estado de pagamento de uma inscrição.

  A inscrição é buscada com escopo no workshop do organizador, então um id
  forjado de outro evento não encontra nada.
  """
  @spec set_payment_status(Workshop.t(), User.t(), Ecto.UUID.t(), atom()) ::
          {:ok, WorkshopEnrollment.t()}
          | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def set_payment_status(%Workshop{} = workshop, %User{} = user, enrollment_id, status)
      when status in [:pending, :paid, :waived] do
    with :ok <- ensure_admin(workshop, user),
         %WorkshopEnrollment{} = enrollment <-
           EnrollmentQuery.get_scoped(enrollment_id, workshop.id) do
      enrollment |> WorkshopEnrollment.payment_changeset(status) |> Repo.update()
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
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
