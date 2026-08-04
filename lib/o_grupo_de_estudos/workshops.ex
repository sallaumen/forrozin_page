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

  require Logger

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.Engagement.SafeDispatch
  alias OGrupoDeEstudos.Media.Storage
  alias OGrupoDeEstudos.Media.Video
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workers.TranscodeWorkshopVideo

  alias OGrupoDeEstudos.Workshops.{
    Access,
    AdminQuery,
    EnrollmentQuery,
    MediaQuery,
    PackageQuery,
    ProgramEnrollment,
    ProgramQuery,
    Workshop,
    WorkshopAdmin,
    JoinRequest,
    JoinRequestQuery,
    WorkshopEnrollment,
    WorkshopMedia,
    WorkshopProgram,
    TeacherQuery,
    WaitlistEntry,
    WaitlistQuery,
    WorkshopQuery,
    WorkshopStep,
    WorkshopStepQuery,
    WorkshopTeacher
  }

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
  defdelegate enrolled_counts_by_program(user_id, program_ids), to: EnrollmentQuery

  defdelegate upcoming_enrollments(user_id, opts \\ []),
    to: EnrollmentQuery,
    as: :list_upcoming_for_user

  defdelegate count_upcoming_enrollments(user_id),
    to: EnrollmentQuery,
    as: :count_upcoming_for_user

  defdelegate pending_reminders(de, ate), to: EnrollmentQuery
  defdelegate mark_reminded(enrollment_ids), to: EnrollmentQuery

  defdelegate get_enrollment(workshop_id, user_id), to: EnrollmentQuery, as: :get_for_user

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

  @doc "Fila de pedidos esperando resposta. Aceita o workshop ou só o id."
  @spec list_pending_requests(Workshop.t() | Ecto.UUID.t()) :: [map()]
  def list_pending_requests(%Workshop{id: id}), do: JoinRequestQuery.list_pending(id)
  def list_pending_requests(workshop_id), do: JoinRequestQuery.list_pending(workshop_id)

  @doc "Quantos pedidos esperando, para o contador do painel."
  @spec count_pending_requests(Workshop.t() | Ecto.UUID.t()) :: non_neg_integer()
  def count_pending_requests(%Workshop{id: id}), do: JoinRequestQuery.count_pending(id)
  def count_pending_requests(workshop_id), do: JoinRequestQuery.count_pending(workshop_id)

  @doc """
  Quem pode ABRIR a página do workshop.

  Todo workshop publicado abre para qualquer um, inclusive o privado: esconder
  faria a agenda parecer vazia justamente quando tem gente usando. O que se
  protege é o interior, não a existência.
  """
  @spec can_see_page?(Workshop.t(), User.t() | nil) :: boolean()
  def can_see_page?(%Workshop{status: status}, _user) when status in [:published, :cancelled],
    do: true

  def can_see_page?(%Workshop{} = workshop, %User{} = user), do: admin?(workshop, user)
  def can_see_page?(%Workshop{}, nil), do: false

  @doc """
  Se a pessoa tem acesso ao INTERIOR: nomes de quem vai, galeria, conversa e
  dados de pagamento.

  Público libera para quem tem conta. Privado exige aprovação, que vira
  inscrição.
  """
  @spec liberado?(Workshop.t(), User.t() | nil) :: boolean()
  def liberado?(%Workshop{visibility: :public}, %User{}), do: true
  def liberado?(%Workshop{visibility: :public}, nil), do: false
  def liberado?(%Workshop{}, nil), do: false

  def liberado?(%Workshop{} = workshop, %User{} = user) do
    admin?(workshop, user) or not is_nil(EnrollmentQuery.get_for_user(workshop.id, user.id))
  end

  @doc "Em que pé está o pedido desta pessoa: `:none`, `:pending`, `:approved` ou `:rejected`."
  @spec join_status(Workshop.t(), User.t() | nil) :: :none | :pending | :approved | :rejected
  def join_status(%Workshop{}, nil), do: :none

  def join_status(%Workshop{} = workshop, %User{} = user),
    do: JoinRequestQuery.status(workshop.id, user.id)

  @doc """
  Pede para entrar num workshop privado.

  Pedir não matricula: a vaga só existe depois do aceite. Uma recusa anterior
  não fecha a porta, o mesmo pedido volta para a fila.
  """
  @spec request_join(Workshop.t(), User.t() | nil) ::
          {:ok, JoinRequest.t()} | {:error, :unauthorized | :not_private | :already_requested}
  def request_join(%Workshop{}, nil), do: {:error, :unauthorized}

  def request_join(%Workshop{visibility: :public}, %User{}), do: {:error, :not_private}

  def request_join(%Workshop{} = workshop, %User{} = user) do
    case JoinRequestQuery.get(workshop.id, user.id) do
      nil -> criar_pedido(workshop, user)
      %JoinRequest{status: :rejected} = recusado -> repetir_pedido(recusado, workshop, user)
      %JoinRequest{} -> {:error, :already_requested}
    end
  end

  defp criar_pedido(workshop, user) do
    %JoinRequest{}
    |> JoinRequest.changeset(%{workshop_id: workshop.id, user_id: user.id, status: :pending})
    |> Repo.insert()
    |> avisar_do_pedido(workshop, user)
  end

  defp repetir_pedido(pedido, workshop, user) do
    pedido
    |> Ecto.Changeset.change(status: :pending, reviewed_at: nil, reviewed_by_id: nil)
    |> Repo.update()
    |> avisar_do_pedido(workshop, user)
  end

  defp avisar_do_pedido({:ok, pedido}, workshop, user) do
    SafeDispatch.run(fn ->
      Dispatcher.notify_workshop_join_request(user.id, workshop.organizer_id, workshop.id)
    end)

    {:ok, pedido}
  end

  defp avisar_do_pedido({:error, _changeset}, _workshop, _user), do: {:error, :already_requested}

  @doc """
  Aceita o pedido e matricula de uma vez.

  Quem pediu para entrar já disse o que queria; um segundo clique para
  confirmar seria burocracia para dizer a mesma coisa.
  """
  @spec approve_join(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, JoinRequest.t()} | {:error, :unauthorized | :not_found | :full | term()}
  def approve_join(%Workshop{} = workshop, %User{} = actor, request_id) do
    with :ok <- ensure_admin(workshop, actor),
         %JoinRequest{} = pedido <- buscar_pedido(workshop, request_id),
         %User{} = pessoa <- Accounts.get_user_by_id(pedido.user_id),
         # `enroll_overbooking` and not `enroll`: accepting is the teacher's call, since
         # they know whether one more fits in the room. The system warns, it does not decide.
         {:ok, _inscricao} <- enroll_overbooking(workshop, pessoa) do
      responder(pedido, :approved, actor, workshop, :workshop_join_approved)
    else
      nil -> {:error, :not_found}
      {:error, motivo} -> {:error, motivo}
    end
  end

  @doc "Recusa o pedido. Silencioso para a turma, e a pessoa pode pedir de novo."
  @spec reject_join(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, JoinRequest.t()} | {:error, :unauthorized | :not_found}
  def reject_join(%Workshop{} = workshop, %User{} = actor, request_id) do
    with :ok <- ensure_admin(workshop, actor),
         %JoinRequest{} = pedido <- buscar_pedido(workshop, request_id) do
      responder(pedido, :rejected, actor, workshop, :workshop_join_rejected)
    else
      nil -> {:error, :not_found}
      {:error, motivo} -> {:error, motivo}
    end
  end

  defp buscar_pedido(workshop, request_id) do
    Repo.get_by(JoinRequest, id: request_id, workshop_id: workshop.id)
  rescue
    Ecto.Query.CastError -> nil
  end

  defp responder(pedido, status, actor, workshop, acao) do
    pedido
    |> JoinRequest.review_changeset(status, actor)
    |> Repo.update()
    |> case do
      {:ok, respondido} -> avisar_da_resposta(respondido, workshop, acao)
      erro -> erro
    end
  end

  defp avisar_da_resposta(pedido, workshop, acao) do
    SafeDispatch.run(fn ->
      Dispatcher.notify_workshop_join_review(
        workshop.organizer_id,
        pedido.user_id,
        workshop.id,
        acao
      )
    end)

    {:ok, pedido}
  end

  defdelegate list_teachers(workshop_id), to: TeacherQuery, as: :list_for_workshop

  @max_teachers 2

  @doc """
  Define quem dá a aula, substituindo a lista inteira.

  Substituir em vez de acrescentar porque é assim que o formulário funciona:
  dois lugares, preenchidos ou não. Cada entrada é `%{user_id: id}` ou
  `%{display_name: nome}`.

  Quem organiza não entra automaticamente: produzir a aula de outra pessoa é o
  caso comum, e assumir que quem criou dá a aula era o bug.
  """
  @spec set_teachers(Workshop.t(), User.t(), [map()]) ::
          {:ok, [map()]}
          | {:error, :unauthorized | :too_many_teachers | :invalid_teacher}
  def set_teachers(%Workshop{} = workshop, %User{} = actor, entradas) do
    with :ok <- ensure_admin(workshop, actor),
         :ok <- ensure_cabem(entradas),
         {:ok, limpas} <- normalizar_professores(entradas) do
      regravar_professores(workshop, limpas)
    end
  end

  defp ensure_cabem(entradas) when length(entradas) <= @max_teachers, do: :ok
  defp ensure_cabem(_demais), do: {:error, :too_many_teachers}

  defp normalizar_professores(entradas) do
    entradas
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {entrada, posicao}, {:ok, acc} ->
      case normalizar_professor(entrada, posicao) do
        {:ok, limpa} -> {:cont, {:ok, [limpa | acc]}}
        :erro -> {:halt, {:error, :invalid_teacher}}
      end
    end)
    |> case do
      {:ok, invertidas} -> {:ok, Enum.reverse(invertidas)}
      erro -> erro
    end
  end

  defp normalizar_professor(%{user_id: user_id}, posicao) when is_binary(user_id) do
    case Accounts.get_user_by_id(user_id) do
      nil -> :erro
      %User{id: id} -> {:ok, %{user_id: id, display_name: nil, position: posicao}}
    end
  end

  defp normalizar_professor(%{display_name: nome}, posicao) when is_binary(nome) do
    case String.trim(nome) do
      "" -> :erro
      limpo -> {:ok, %{user_id: nil, display_name: limpo, position: posicao}}
    end
  end

  defp normalizar_professor(_sem_conta_nem_nome, _posicao), do: :erro

  # Delete and rewrite in the same transaction: the list is short and the order
  # matters, and reconciling two rows would cost more code than rewriting.
  defp regravar_professores(workshop, entradas) do
    Repo.transact(fn ->
      TeacherQuery.delete_all(workshop.id)
      Enum.reduce_while(entradas, {:ok, []}, &inserir_professor(&1, &2, workshop))
    end)
  end

  defp inserir_professor(entrada, {:ok, acc}, workshop) do
    %WorkshopTeacher{}
    |> WorkshopTeacher.changeset(Map.put(entrada, :workshop_id, workshop.id))
    |> Repo.insert()
    |> case do
      {:ok, criado} -> {:cont, {:ok, [criado | acc]}}
      {:error, _changeset} -> {:halt, {:error, :invalid_teacher}}
    end
  end

  defdelegate list_steps(workshop_id), to: WorkshopStepQuery, as: :list_for_workshop

  @doc """
  Diz em que workshops ESTA pessoa viu este passo.

  É o caminho de volta que faltava: o acervo era uma ilha, e nada na página do
  passo lembrava que ele tinha sido dado numa aula que a pessoa fez.
  """
  @spec workshops_where_seen(Ecto.UUID.t() | nil, Ecto.UUID.t()) :: [map()]
  defdelegate workshops_where_seen(user_id, step_id), to: WorkshopStepQuery, as: :where_user_saw

  @doc "Step ids the user saw in workshops they attended or organized, as a MapSet."
  @spec step_ids_seen_by(Ecto.UUID.t() | nil) :: MapSet.t()
  defdelegate step_ids_seen_by(user_id), to: WorkshopStepQuery

  @doc """
  Põe um passo do acervo na lista do workshop.

  Só quem administra: a lista é o que a aula ofereceu, e quem deu a aula sabe
  o que ofereceu. Curadoria por like foi considerada e descartada, porque
  ordenar por voto resolve com muito mais peça um problema que a permissão já
  resolve.
  """
  @spec add_step(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, WorkshopStep.t()} | {:error, :unauthorized | :not_found | :already_added}
  def add_step(%Workshop{} = workshop, %User{} = actor, step_id) do
    with :ok <- ensure_admin(workshop, actor),
         %{id: id} <- buscar_passo(step_id) do
      inserir_passo(workshop, id)
    else
      nil -> {:error, :not_found}
      {:error, motivo} -> {:error, motivo}
    end
  end

  defp buscar_passo(step_id) do
    OGrupoDeEstudos.Encyclopedia.StepQuery.get_by(id: step_id)
  rescue
    Ecto.Query.CastError -> nil
  end

  defp inserir_passo(workshop, step_id) do
    %WorkshopStep{}
    |> WorkshopStep.changeset(%{
      workshop_id: workshop.id,
      step_id: step_id,
      position: WorkshopStepQuery.next_position(workshop.id)
    })
    |> Repo.insert()
    |> case do
      {:ok, vinculo} -> {:ok, vinculo}
      {:error, %Ecto.Changeset{}} -> {:error, :already_added}
    end
  end

  @doc "Tira um passo da lista do workshop."
  @spec remove_step(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, WorkshopStep.t()} | {:error, :unauthorized | :not_found}
  def remove_step(%Workshop{} = workshop, %User{} = actor, step_id) do
    with :ok <- ensure_admin(workshop, actor) do
      WorkshopStepQuery.delete(workshop.id, step_id)
    end
  end

  @media_dir "workshop_media"
  # Refuses a new upload with less than 1 GB free. Without this the volume fills
  # and the next upload blows up mid-write with ENOSPC and no useful message.
  # On R2 it does not apply: free_bytes returns :unknown and the quota is the limit.
  @min_free_bytes 1_073_741_824
  # 2 GiB of media per workshop. With practically unlimited storage (R2) the risk
  # stops being a full disk and becomes cost: only enrolled users upload, but
  # nothing would stop someone dumping video after video. 2 GiB is around 3h of
  # transcoded video, room enough for real use.
  @max_media_bytes_por_workshop 2_147_483_648

  defdelegate list_media(workshop_id), to: MediaQuery, as: :list_for_workshop
  defdelegate get_media(media_id), to: MediaQuery, as: :get
  defdelegate media_usage(workshop_id), to: MediaQuery, as: :usage

  @doc """
  Quem pode ver a galeria: quem administra o workshop ou quem se inscreveu.

  A galeria é o conteúdo pelo qual se paga, então não segue a visibilidade da
  página: workshop público continua com a galeria fechada.
  """
  @spec can_see_media?(Workshop.t(), User.t() | nil) :: boolean()
  def can_see_media?(%Workshop{}, nil), do: false

  def can_see_media?(%Workshop{} = workshop, %User{} = user) do
    admin?(workshop, user) or not is_nil(EnrollmentQuery.get_for_user(workshop.id, user.id))
  end

  @doc """
  Guarda uma foto ou vídeo na galeria.

  Só quem está no workshop manda mídia. Marca como oficial o que veio de quem
  administra, para aparecer primeiro e com selo.
  """
  @spec add_media(Workshop.t(), User.t(), map()) ::
          {:ok, WorkshopMedia.t()}
          | {:error, :unauthorized | :unsupported_type | :storage_full | :media_quota | term()}
  def add_media(%Workshop{} = workshop, %User{} = user, %{
        tmp_path: tmp_path,
        content_type: content_type,
        byte_size: byte_size
      }) do
    with :ok <- ensure_pode_enviar(workshop, user),
         {:ok, kind} <- ensure_tipo(content_type),
         :ok <- ensure_cota(workshop.id, byte_size),
         :ok <- ensure_espaco(byte_size),
         {:ok, key} <-
           Storage.put_private(
             pasta_da_galeria(workshop.id),
             tmp_path,
             WorkshopMedia.extensao(content_type)
           ) do
      inserir_media(workshop, user, kind, key, content_type, byte_size)
    end
  end

  defp ensure_pode_enviar(workshop, user) do
    if can_see_media?(workshop, user), do: :ok, else: {:error, :unauthorized}
  end

  defp ensure_tipo(content_type) do
    case WorkshopMedia.kind_do_tipo(content_type) do
      :error -> {:error, :unsupported_type}
      kind -> {:ok, kind}
    end
  end

  defp ensure_cota(workshop_id, byte_size) do
    %{bytes: usados} = MediaQuery.usage(workshop_id)

    if usados + byte_size <= @max_media_bytes_por_workshop,
      do: :ok,
      else: {:error, :media_quota}
  end

  defp ensure_espaco(byte_size) do
    case Storage.free_bytes() do
      :unknown -> :ok
      livres when livres - byte_size > @min_free_bytes -> :ok
      _apertado -> {:error, :storage_full}
    end
  end

  defp inserir_media(workshop, user, kind, key, content_type, byte_size) do
    atributos = %{
      workshop_id: workshop.id,
      uploaded_by_id: user.id,
      kind: kind,
      storage_key: key,
      content_type: content_type,
      byte_size: byte_size,
      status: WorkshopMedia.status_inicial(kind),
      official: admin?(workshop, user)
    }

    case gravar_com_fila(atributos) do
      {:ok, media} -> {:ok, Repo.preload(media, :uploaded_by)}
      {:error, motivo} -> descartar_arquivo(key, motivo)
    end
  end

  # Media and transcode job go in the SAME transaction: either the video lands
  # with its conversion scheduled or nothing lands. Otherwise a failure to enqueue
  # would leave the row in "processing" forever with no job, and Lifeline does not
  # rescue a job that does not exist.
  defp gravar_com_fila(atributos) do
    Repo.transact(fn ->
      with {:ok, media} <- Repo.insert(WorkshopMedia.changeset(%WorkshopMedia{}, atributos)) do
        enfileirado(media)
      end
    end)
  end

  # A video leaves the upload as `:processing`: the file is already stored and the
  # conversion happens later, so nobody watches a frozen progress bar while ffmpeg runs.
  defp enfileirado(%WorkshopMedia{status: :processing, id: id} = media) do
    case Oban.insert(TranscodeWorkshopVideo.new(%{"media_id" => id})) do
      {:ok, _job} -> {:ok, media}
      {:error, motivo} -> {:error, motivo}
    end
  end

  defp enfileirado(media), do: {:ok, media}

  defp descartar_arquivo(key, erro) do
    Storage.delete_private(key)
    {:error, erro}
  end

  @doc "Como servir uma mídia: `{:file, caminho}` ou `{:redirect, url}`."
  @spec serve_media(WorkshopMedia.t()) ::
          {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}
  def serve_media(%WorkshopMedia{storage_key: key}), do: Storage.serve_private(key)

  @doc "Como servir o poster do vídeo. Sem poster é not_found, não erro."
  @spec serve_poster(WorkshopMedia.t()) ::
          {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}
  def serve_poster(%WorkshopMedia{poster_key: nil}), do: {:error, :not_found}
  def serve_poster(%WorkshopMedia{poster_key: key}), do: Storage.serve_private(key)

  @doc """
  Tira uma mídia da galeria.

  Quem enviou tira a sua; quem administra tira qualquer uma. Some da tela na
  hora e o arquivo vai embora junto.
  """
  @spec remove_media(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, WorkshopMedia.t()} | {:error, :unauthorized | :not_found}
  def remove_media(%Workshop{} = workshop, %User{} = user, media_id) do
    with %WorkshopMedia{} = media <- MediaQuery.get_scoped(media_id, workshop.id),
         :ok <- ensure_pode_apagar(workshop, user, media) do
      apagar_media(media)
    else
      nil -> {:error, :not_found}
      {:error, motivo} -> {:error, motivo}
    end
  end

  defp ensure_pode_apagar(workshop, user, media) do
    if media.uploaded_by_id == user.id or admin?(workshop, user),
      do: :ok,
      else: {:error, :unauthorized}
  end

  defp apagar_media(media) do
    agora = DateTime.utc_now() |> DateTime.truncate(:second)

    case media |> Ecto.Changeset.change(deleted_at: agora) |> Repo.update() do
      {:ok, apagada} ->
        Storage.delete_private(media.storage_key)
        apagar_poster(media.poster_key)
        {:ok, apagada}

      erro ->
        erro
    end
  end

  defp apagar_poster(nil), do: :ok
  defp apagar_poster(key), do: Storage.delete_private(key)

  @doc """
  Converte o vídeo de uma mídia para 720p H.264 e marca como pronta.

  Chamada pelo `Workers.TranscodeWorkshopVideo`, nunca direto pela borda: o
  ffmpeg leva dezenas de segundos e não cabe num `handle_event`.

  Sempre termina em `:ready`, mesmo quando dá errado. Um vídeo preso em
  "processando" para sempre é pior do que um vídeo grande: a aluna vê o dela
  na galeria de qualquer jeito, e quem tem Android antigo é que talvez não
  consiga abrir. Falhar o upload por causa disso seria trocar um problema
  parcial por um total.
  """
  @spec transcode_media(Ecto.UUID.t()) :: :ok | {:error, term()}
  def transcode_media(media_id) do
    case MediaQuery.get(media_id) do
      %WorkshopMedia{status: :processing, kind: :video, deleted_at: nil} = media ->
        converter(media, Video.available?())

      _pronta_apagada_ou_inexistente ->
        :ok
    end
  end

  defp converter(media, false) do
    Logger.warning("[Transcode] sem ffmpeg, mídia #{media.id} fica como veio")
    marcar_pronta(media, %{})
  end

  defp converter(media, true) do
    saida = caminho_temporario("mp4")

    try do
      rodar_transcode(media, saida)
    after
      File.rm(saida)
    end
  end

  # with_private_file exists because on an external provider the original is not
  # a local file: the adapter downloads to a temporary one and ffmpeg reads from there.
  defp rodar_transcode(media, saida) do
    case Storage.with_private_file(media.storage_key, &Video.transcode(&1, saida)) do
      {:ok, :ok} -> guardar_convertido(media, saida, tamanho(saida))
      {:ok, {:error, motivo}} -> desistir(media, motivo)
      {:error, motivo} -> desistir(media, motivo)
    end
  end

  # An ffmpeg that exits 0 and writes an empty file exists. Storing that would
  # delete the uploaded video and put nothing in its place.
  defp guardar_convertido(media, _saida, 0), do: desistir(media, :saida_vazia)

  defp guardar_convertido(media, saida, bytes) do
    case Storage.put_private(pasta_da_galeria(media.workshop_id), saida, ".mp4") do
      {:ok, chave} -> trocar_arquivo(media, chave, bytes, gerar_poster(media, saida))
      {:error, motivo} -> desistir(media, motivo)
    end
  end

  defp trocar_arquivo(media, chave, bytes, poster_key) do
    atributos = %{
      storage_key: chave,
      content_type: "video/mp4",
      byte_size: bytes,
      poster_key: poster_key
    }

    case marcar_pronta(media, atributos) do
      :ok -> Storage.delete_private(media.storage_key)
      # Whoever deleted during the transcode wins: the converted file and the poster
      # go away instead of becoming orphans, and there is nothing to retry.
      {:error, :apagada} -> descartar_convertido(chave, poster_key)
    end
  end

  defp descartar_convertido(chave, poster_key) do
    Storage.delete_private(chave)
    apagar_poster(poster_key)
    :ok
  end

  defp desistir(media, motivo) do
    Logger.warning("[Transcode] mídia #{media.id} falhou (#{inspect(motivo)}), fica o original")

    case marcar_pronta(media, %{}) do
      :ok -> :ok
      {:error, :apagada} -> :ok
    end
  end

  # Conditioned on `deleted_at` AGAIN, not only at the job entry: ffmpeg takes
  # minutes, and a deletion in between cannot be run over.
  defp marcar_pronta(media, atributos) do
    campos =
      atributos
      |> Map.put(:status, :ready)
      |> Map.put(:updated_at, NaiveDateTime.utc_now(:second))
      |> Map.to_list()

    viva = from(m in WorkshopMedia, where: m.id == ^media.id and is_nil(m.deleted_at))

    case Repo.update_all(viva, set: campos) do
      {1, _} -> :ok
      {0, _} -> {:error, :apagada}
    end
  end

  # The poster is decoration: without it the gallery shows the first frame, which
  # is usually black. Not a reason to hold the media in "processing".
  defp gerar_poster(media, video) do
    destino = caminho_temporario("jpg")

    try do
      guardar_poster(media, video, destino)
    after
      File.rm(destino)
    end
  end

  defp guardar_poster(media, video, destino) do
    case Video.poster(video, destino) do
      :ok -> chave_do_poster(media, destino)
      {:error, _motivo} -> nil
    end
  end

  defp chave_do_poster(media, destino) do
    case Storage.put_private(pasta_da_galeria(media.workshop_id), destino, ".jpg") do
      {:ok, chave} -> chave
      {:error, _motivo} -> nil
    end
  end

  # One folder per workshop: the bucket stays browsable by context, and what
  # belongs to a workshop lives together (original, converted and poster).
  defp pasta_da_galeria(workshop_id), do: Path.join(@media_dir, workshop_id)

  defp caminho_temporario(ext) do
    nome = "workshop_video_#{System.unique_integer([:positive])}.#{ext}"
    Path.join(System.tmp_dir!(), nome)
  end

  defp tamanho(caminho) do
    case File.stat(caminho) do
      {:ok, %{size: bytes}} -> bytes
      {:error, _motivo} -> 0
    end
  end

  @doc """
  Compra o pacote: entra em TODOS os workshops publicados da programação.

  Tudo ou nada, ao contrário da inscrição avulsa. Quem pagou pelos três dias
  não pode acabar em dois: se uma turma lotar no meio, as inscrições já feitas
  são desfeitas e ninguém fica meio dentro.
  """
  @spec enroll_in_package(WorkshopProgram.t(), User.t()) ::
          {:ok, ProgramEnrollment.t()}
          | {:error,
             :no_package | :organizer | :already_enrolled | {:full, Workshop.t()} | term()}
  def enroll_in_package(%WorkshopProgram{} = program, %User{} = user) do
    with :ok <- ensure_package(program),
         :ok <- ensure_nao_organiza(program, user),
         {:ok, matricula} <- criar_matricula(program, user) do
      cobrir_workshops(program, user, matricula)
    end
  end

  defp ensure_package(program) do
    if WorkshopProgram.pacote?(program), do: :ok, else: {:error, :no_package}
  end

  defp ensure_nao_organiza(%WorkshopProgram{owner_id: id}, %User{id: id}),
    do: {:error, :organizer}

  defp ensure_nao_organiza(_program, _user), do: :ok

  defp criar_matricula(program, user) do
    %ProgramEnrollment{}
    |> ProgramEnrollment.changeset(%{program_id: program.id, user_id: user.id})
    |> Repo.insert()
    |> case do
      {:ok, matricula} -> {:ok, matricula}
      {:error, %Ecto.Changeset{}} -> {:error, :already_enrolled}
    end
  end

  # Each workshop gets its own transaction (same reason as enroll_many), and the
  # compensation undoes whatever already landed if one fails.
  defp cobrir_workshops(program, user, matricula) do
    workshops = ProgramQuery.list_workshops(program.id)

    case Enum.reduce_while(workshops, [], &cobrir_um(&1, user, matricula, &2)) do
      {:error, motivo, criadas} -> desfazer_pacote(matricula, criadas, motivo)
      _criadas -> {:ok, matricula}
    end
  end

  defp cobrir_um(workshop, user, matricula, criadas) do
    case garantir_inscricao(workshop, user, matricula) do
      {:ok, :nova} -> {:cont, [workshop | criadas]}
      {:ok, :ja_existia} -> {:cont, criadas}
      {:error, motivo} -> {:halt, {:error, {motivo, workshop}, criadas}}
    end
  end

  # Whoever was already enrolled in one of the workshops moves to the package
  # without a duplicated enrollment.
  defp garantir_inscricao(workshop, user, matricula) do
    case EnrollmentQuery.get_for_user(workshop.id, user.id) do
      nil -> inscrever_pelo_pacote(workshop, user, matricula)
      inscricao -> vincular_ao_pacote(inscricao, matricula)
    end
  end

  defp inscrever_pelo_pacote(workshop, user, matricula) do
    case insert_enrollment_locked(workshop, user) do
      {:ok, inscricao} ->
        inscricao
        |> Ecto.Changeset.change(program_enrollment_id: matricula.id)
        |> Repo.update()
        |> case do
          {:ok, _} -> {:ok, :nova}
          erro -> erro
        end

      {:error, motivo} ->
        {:error, motivo}
    end
  end

  defp vincular_ao_pacote(inscricao, matricula) do
    inscricao
    |> Ecto.Changeset.change(program_enrollment_id: matricula.id)
    |> Repo.update()
    |> case do
      {:ok, _} -> {:ok, :ja_existia}
      erro -> erro
    end
  end

  defp desfazer_pacote(matricula, criadas, {motivo, workshop}) do
    for w <- criadas, do: apagar_inscricao(w.id, matricula.user_id)
    Repo.delete(matricula)
    {:error, {motivo, workshop}}
  end

  defp apagar_inscricao(workshop_id, user_id) do
    case EnrollmentQuery.get_for_user(workshop_id, user_id) do
      nil -> :ok
      inscricao -> Repo.delete(inscricao)
    end
  end

  @doc "Quem comprou o pacote. Só quem criou a programação vê."
  @spec list_package_enrollments(WorkshopProgram.t(), User.t()) ::
          {:ok, [map()]} | {:error, :unauthorized}
  def list_package_enrollments(%WorkshopProgram{} = program, %User{} = user) do
    with :ok <- ensure_program_owner(program, user) do
      {:ok, PackageQuery.list_for_program(program.id)}
    end
  end

  @doc "Resumo do pacote: quantos compraram, quantos pagaram, quanto entrou."
  @spec package_summary(WorkshopProgram.t(), User.t()) :: {:ok, map()} | {:error, :unauthorized}
  def package_summary(%WorkshopProgram{} = program, %User{} = user) do
    with :ok <- ensure_program_owner(program, user) do
      {:ok, PackageQuery.summary(program.id, program.price_cents)}
    end
  end

  @doc "Marca o pagamento do pacote."
  @spec set_package_payment(WorkshopProgram.t(), User.t(), Ecto.UUID.t(), atom()) ::
          {:ok, ProgramEnrollment.t()} | {:error, :unauthorized | :not_found | term()}
  def set_package_payment(%WorkshopProgram{} = program, %User{} = user, enrollment_id, status)
      when status in [:pending, :paid, :waived] do
    with :ok <- ensure_program_owner(program, user),
         %ProgramEnrollment{} = matricula <-
           PackageQuery.get_scoped(enrollment_id, program.id) do
      matricula |> ProgramEnrollment.payment_changeset(status) |> Repo.update()
    else
      nil -> {:error, :not_found}
      {:error, motivo} -> {:error, motivo}
    end
  end

  @doc "Matrícula da pessoa no pacote desta programação, ou `nil`."
  @spec package_enrollment(WorkshopProgram.t(), User.t() | nil) :: ProgramEnrollment.t() | nil
  def package_enrollment(%WorkshopProgram{}, nil), do: nil

  def package_enrollment(%WorkshopProgram{} = program, %User{} = user),
    do: PackageQuery.get_for_user(program.id, user.id)

  @doc """
  A agenda da comunidade, misturando workshops soltos e programações em ordem
  de data.

  Sem busca, workshop que está numa programação NÃO aparece solto: um festival
  com quinze workshops viraria quinze linhas repetindo o mesmo nome. Com busca
  a programação abre, senão o workshop lá dentro ficaria impossível de achar.

  Cada item é `%{kind: :workshop | :program, starts_at: ...}`, para a tela
  renderizar sem precisar decidir nada.
  """
  @spec list_agenda(keyword()) :: [map()]
  def list_agenda(opts \\ []) do
    buscando? = busca_ativa?(opts[:search])

    programas = ProgramQuery.list_feed(opts)
    resumos = ProgramQuery.summaries_by_ids(Enum.map(programas, fn {p, _} -> p.id end))

    opts
    |> Keyword.put(:only_loose, not buscando?)
    |> WorkshopQuery.list_feed()
    |> sem_repetir_programa(programas)
    |> Enum.map(&item_de_workshop/1)
    |> Enum.concat(Enum.map(programas, &item_de_programa(&1, resumos)))
    |> ordenar_por_data(Keyword.get(opts, :period, :upcoming))
  end

  # In a search the program and its workshops can match at the same time. Without
  # this the festival card would come sandwiched between its own children, and the
  # counter would announce three events where there is one.
  defp sem_repetir_programa(workshops, programas) do
    ja_listados = MapSet.new(programas, fn {program, _} -> program.id end)

    Enum.reject(workshops, &MapSet.member?(ja_listados, &1.program_id))
  end

  defp busca_ativa?(nil), do: false
  defp busca_ativa?(""), do: false
  defp busca_ativa?(termo), do: String.trim(termo) != ""

  defp item_de_workshop(workshop) do
    %{kind: :workshop, id: workshop.id, starts_at: workshop.starts_at, workshop: workshop}
  end

  # The period decides WHICH programs come in; the summary shown is the whole
  # festival, otherwise the card would say "3 workshops" while the program page
  # shows fifteen.
  defp item_de_programa({program, do_periodo}, resumos) do
    %{
      kind: :program,
      id: program.id,
      starts_at: do_periodo.starts_at,
      program: program,
      summary: Map.get(resumos, program.id, do_periodo)
    }
  end

  # In the past the agenda runs from most recent backwards: what just happened
  # matters more than what happened a year ago.
  defp ordenar_por_data(itens, :past), do: Enum.sort_by(itens, & &1.starts_at, {:desc, DateTime})
  defp ordenar_por_data(itens, _period), do: Enum.sort_by(itens, & &1.starts_at, DateTime)

  # One folder per poster owner, workshops and programs apart. The file name stays
  # random, which is what prevents scanning; the id in the folder only organizes
  # (the route is by slug, an id opens nothing).
  defp pasta_do_flyer(%Workshop{id: id}), do: "flyers/workshops/#{id}"
  defp pasta_do_flyer(%WorkshopProgram{id: id}), do: "flyers/programas/#{id}"

  @doc """
  Guarda o flyer de divulgação do workshop e apaga o anterior.

  Recebe o arquivo temporário do upload, não um caminho escolhido pelo
  usuário: quem decide onde o arquivo mora é o storage.
  """
  @spec put_workshop_flyer(Workshop.t(), User.t(), String.t(), String.t()) ::
          {:ok, Workshop.t()} | {:error, :unauthorized | term()}
  def put_workshop_flyer(%Workshop{} = workshop, %User{} = user, tmp_path, ext) do
    with :ok <- ensure_admin(workshop, user),
         {:ok, url} <- Storage.save_image(pasta_do_flyer(workshop), tmp_path, ext) do
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
         {:ok, url} <- Storage.save_image(pasta_do_flyer(program), tmp_path, ext) do
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

  # Only deletes the old file after the database confirms. The other way around, an
  # update error would leave the row pointing at a file that no longer exists.
  defp descartar_flyer({:ok, _} = resultado, nil), do: resultado

  defp descartar_flyer({:ok, _} = resultado, antigo) do
    Storage.delete_image(antigo)
    resultado
  end

  defp descartar_flyer(erro, _antigo), do: erro

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

  @doc """
  Inscreve numa lista de workshops da programação de uma vez.

  Cada workshop tem a sua transação, de propósito. Uma transação única
  seguraria N locks e duas pessoas marcando {A,B} e {B,A} ao mesmo tempo
  travariam uma na outra; e, pior, uma vaga que acabou faria as outras
  inscrições sumirem junto. Quem marcou três e perdeu uma quer as outras duas.

  Já estar inscrito conta como sucesso: a pessoa pediu para estar lá, e está.
  """
  @spec enroll_many(WorkshopProgram.t(), User.t(), [Ecto.UUID.t()]) ::
          {:ok, %{enrolled: [Workshop.t()], failed: [{Workshop.t(), atom()}]}}
          | {:error, :none_selected}
  def enroll_many(%WorkshopProgram{} = program, %User{} = user, workshop_ids) do
    case ProgramQuery.workshops_scoped(program.id, workshop_ids) do
      [] -> {:error, :none_selected}
      workshops -> {:ok, inscrever_em_lote(program, user, workshops)}
    end
  end

  defp inscrever_em_lote(program, user, workshops) do
    resultado =
      Enum.reduce(workshops, %{enrolled: [], failed: []}, fn workshop, acc ->
        acumular(acc, workshop, inscrever_um(workshop, user))
      end)

    avisar_organizadores(resultado, program, user)
    %{resultado | enrolled: Enum.reverse(resultado.enrolled)}
  end

  defp inscrever_um(workshop, user) do
    case admin?(workshop, user) do
      true -> {:error, :organizer}
      false -> workshop |> insert_enrollment_locked(user) |> tratar_repetida()
    end
  end

  defp tratar_repetida({:error, :already_enrolled}), do: {:ok, :ja_estava}
  defp tratar_repetida(outro), do: outro

  defp acumular(acc, workshop, {:ok, _}),
    do: %{acc | enrolled: [workshop | acc.enrolled]}

  defp acumular(acc, workshop, {:error, motivo}),
    do: %{acc | failed: acc.failed ++ [{workshop, motivo}]}

  defp avisar_organizadores(%{enrolled: []}, _program, _user), do: :ok

  defp avisar_organizadores(%{enrolled: workshops}, program, user) do
    SafeDispatch.run(fn ->
      workshops
      |> destinatarios_do_lote(user)
      |> Enum.each(fn {organizer_id, workshop} ->
        Dispatcher.notify_program_enrollment(user.id, organizer_id, workshop.id, program.id)
      end)
    end)
  end

  # One notice per person, even when they organize several workshops of the batch:
  # three identical lines in the inbox is the spam a program exists to kill.
  defp destinatarios_do_lote(workshops, user) do
    workshops
    |> Enum.flat_map(fn workshop -> Enum.map(admin_ids(workshop), &{&1, workshop}) end)
    |> Enum.reject(fn {organizer_id, _} -> organizer_id == user.id end)
    |> Enum.uniq_by(fn {organizer_id, _} -> organizer_id end)
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

  # Enrollment that ignores the capacity, and ONLY it. It exists for the two paths
  # where someone already decided the person gets in: the teacher approving, and
  # the promotion from the waitlist into a seat that just opened. The normal path
  # keeps blocking, otherwise the capacity would mean nothing.
  defp enroll_overbooking(workshop, user) do
    Repo.transact(fn ->
      with {:ok, locked} <- lock_workshop(workshop.id),
           :ok <- ensure_open(locked) do
        insert_enrollment(locked, user)
      end
    end)
    |> notify_organizers(workshop, user)
  end

  # Outside the transaction on purpose: a broadcast does not roll back, so a late
  # error would leave the organizer notified of an enrollment that does not exist.
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
  def cancel_enrollment(%Workshop{} = workshop, %User{id: user_id}) do
    case EnrollmentQuery.get_for_user(workshop.id, user_id) do
      nil -> {:error, :not_found}
      enrollment -> enrollment |> Repo.delete() |> promover_da_fila(workshop)
    end
  end

  # An open seat calls whoever waited longest. One person per seat: the waitlist
  # moves one step, it does not drain.
  defp promover_da_fila({:ok, _apagada} = resultado, workshop) do
    case WaitlistQuery.first_in_line(workshop.id) do
      nil -> resultado
      entrada -> promover(entrada, workshop, resultado)
    end
  end

  defp promover_da_fila(erro, _workshop), do: erro

  defp promover(entrada, workshop, resultado) do
    with %User{} = pessoa <- Accounts.get_user_by_id(entrada.user_id),
         {:ok, _inscricao} <- enroll_overbooking(workshop, pessoa) do
      Repo.delete(entrada)
      avisar_promocao(workshop, pessoa)
    end

    resultado
  end

  defp avisar_promocao(workshop, pessoa) do
    SafeDispatch.run(fn ->
      Dispatcher.notify_waitlist_promoted(workshop.organizer_id, pessoa.id, workshop.id)
    end)
  end

  defdelegate list_waitlist(workshop_id), to: WaitlistQuery, as: :list_for_workshop
  defdelegate waitlist_count(workshop_id), to: WaitlistQuery, as: :count

  @doc "Em que lugar da fila a pessoa está, contando de 1. `nil` se não está."
  @spec waitlist_position(Workshop.t(), User.t() | nil) :: pos_integer() | nil
  def waitlist_position(%Workshop{}, nil), do: nil

  def waitlist_position(%Workshop{} = workshop, %User{} = user),
    do: WaitlistQuery.position(workshop.id, user.id)

  @doc """
  Se aceitar mais uma pessoa passaria do limite de vagas.

  Serve para avisar quem organiza antes de aceitar, não para barrar: em turma
  com aceite, caber ou não caber é decisão de quem dá a aula.
  """
  @spec passaria_do_limite?(Workshop.t()) :: boolean()
  def passaria_do_limite?(%Workshop{} = workshop),
    do: Workshop.full?(workshop, EnrollmentQuery.count(workshop.id))

  @doc """
  Entra na fila de espera de uma turma lotada.

  Só faz sentido com a turma cheia: com vaga sobrando a pessoa se inscreve, e
  esperar seria pior para ela.
  """
  @spec join_waitlist(Workshop.t(), User.t() | nil) ::
          {:ok, WaitlistEntry.t()}
          | {:error, :unauthorized | :has_room | :already_enrolled | :already_waiting}
  def join_waitlist(%Workshop{}, nil), do: {:error, :unauthorized}

  def join_waitlist(%Workshop{} = workshop, %User{} = user) do
    with :ok <- ensure_lotado(workshop),
         :ok <- ensure_fora_da_turma(workshop, user) do
      inserir_na_fila(workshop, user)
    end
  end

  defp ensure_lotado(workshop) do
    if passaria_do_limite?(workshop), do: :ok, else: {:error, :has_room}
  end

  defp ensure_fora_da_turma(workshop, user) do
    case EnrollmentQuery.get_for_user(workshop.id, user.id) do
      nil -> :ok
      _ja_esta -> {:error, :already_enrolled}
    end
  end

  defp inserir_na_fila(workshop, user) do
    %WaitlistEntry{}
    |> WaitlistEntry.changeset(%{workshop_id: workshop.id, user_id: user.id})
    |> Repo.insert()
    |> case do
      {:ok, entrada} -> {:ok, entrada}
      {:error, %Ecto.Changeset{}} -> {:error, :already_waiting}
    end
  end

  @doc "Sai da fila de espera."
  @spec leave_waitlist(Workshop.t(), User.t() | nil) ::
          {:ok, WaitlistEntry.t()} | {:error, :not_found}
  def leave_waitlist(%Workshop{}, nil), do: {:error, :not_found}

  def leave_waitlist(%Workshop{} = workshop, %User{} = user) do
    case WaitlistQuery.get(workshop.id, user.id) do
      nil -> {:error, :not_found}
      entrada -> Repo.delete(entrada)
    end
  end

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

  # Takes atom or string keys coming from the form, without atomizing input.
  defp normalize(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    ArgumentError -> attrs
  end
end
