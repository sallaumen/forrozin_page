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

  # ── Pedido de entrada (workshop privado) ──────────────────────────────

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
         {:ok, _inscricao} <- enroll(workshop, pessoa) do
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

  # ── Galeria ───────────────────────────────────────────────────────────

  @media_dir "workshop_media"
  # Recusa upload novo com menos de 1 GB livre. Sem isso o volume enche e o
  # proximo upload estoura ENOSPC no meio, sem mensagem que ajude ninguem.
  # No R2 nao se aplica: free_bytes devolve :unknown e quem limita e a cota.
  @min_free_bytes 1_073_741_824
  # 2 GiB de midia por workshop. Com storage praticamente ilimitado (R2), o
  # risco deixa de ser disco cheio e vira custo: so inscritos mandam midia,
  # mas nada impediria alguem de despejar video atras de video. 2 GiB dao
  # ~3h de video transcodificado, folga para uso real.
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

  # Mídia e job de transcode entram na MESMA transação: ou o vídeo entra com
  # a conversão agendada, ou nada entra. Sem isso, uma falha ao enfileirar
  # deixaria a linha em "processando" para sempre, sem job nenhum, e o
  # Lifeline não resgata job que não existe.
  defp gravar_com_fila(atributos) do
    Repo.transact(fn ->
      with {:ok, media} <- Repo.insert(WorkshopMedia.changeset(%WorkshopMedia{}, atributos)) do
        enfileirado(media)
      end
    end)
  end

  # Vídeo sai do upload em `:processing`: o arquivo já está salvo e a conversão
  # acontece depois, para a aluna não ficar olhando a barra parada enquanto o
  # ffmpeg roda.
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

  # ── Transcode de vídeo ────────────────────────────────────────────────

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

  # O with_private_file existe porque num provider externo o original não é
  # arquivo local: o adapter baixa para um temporário e o ffmpeg lê de lá.
  defp rodar_transcode(media, saida) do
    case Storage.with_private_file(media.storage_key, &Video.transcode(&1, saida)) do
      {:ok, :ok} -> guardar_convertido(media, saida, tamanho(saida))
      {:ok, {:error, motivo}} -> desistir(media, motivo)
      {:error, motivo} -> desistir(media, motivo)
    end
  end

  # ffmpeg que sai com 0 mas escreve arquivo vazio existe. Guardar isso
  # apagaria o vídeo da aluna e trocaria por nada.
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
      # Quem apagou durante o transcode ganhou: o convertido e o poster vão
      # embora em vez de virarem órfãos, e não há nada para tentar de novo.
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

  # Condicionado a `deleted_at` DE NOVO, não só na entrada do job: o ffmpeg
  # leva minutos, e uma remoção nesse meio tempo não pode ser atropelada.
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

  # Poster é enfeite: sem ele a galeria mostra o primeiro quadro do vídeo, que
  # costuma ser preto. Não é motivo para segurar a mídia em "processando".
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

  # Uma pasta por workshop: o bucket fica navegável por contexto, e o que é
  # de um workshop mora junto (original, convertido e poster).
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

  # ── Pacote da programação ─────────────────────────────────────────────

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

  # Cada workshop tem a sua transacao (mesmo motivo de enroll_many), e a
  # compensacao desfaz o que ja entrou se algum falhar.
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

  # Quem ja estava avulso num dos workshops passa a estar pelo pacote, sem
  # inscricao duplicada.
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

  # ── Agenda ────────────────────────────────────────────────────────────

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

  # Na busca a programacao e os workshops dela podem casar ao mesmo tempo. Sem
  # isso o card do festival sairia ensanduichado entre os proprios filhos, e o
  # contador anunciaria tres eventos onde existe um.
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

  # O periodo decide QUAIS programacoes entram; o resumo mostrado e o do
  # festival inteiro, senao o card diria "3 workshops" enquanto a pagina da
  # programacao mostra quinze.
  defp item_de_programa({program, do_periodo}, resumos) do
    %{
      kind: :program,
      id: program.id,
      starts_at: do_periodo.starts_at,
      program: program,
      summary: Map.get(resumos, program.id, do_periodo)
    }
  end

  # No passado a agenda vai do mais recente para tras: o que acabou de
  # acontecer interessa mais que o de um ano atras.
  defp ordenar_por_data(itens, :past), do: Enum.sort_by(itens, & &1.starts_at, {:desc, DateTime})
  defp ordenar_por_data(itens, _period), do: Enum.sort_by(itens, & &1.starts_at, DateTime)

  # ── Flyer ─────────────────────────────────────────────────────────────

  # Uma pasta por dono do cartaz: workshops e programações separados, cada um
  # com a sua. O nome do arquivo continua aleatório, que é o que impede
  # varredura; o id na pasta só organiza (rota é por slug, id não abre nada).
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

  # Um aviso por pessoa, mesmo que ela organize varios workshops do lote:
  # tres linhas iguais na caixa e o spam que a programacao existe para matar.
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
