defmodule OGrupoDeEstudos.Workshops do
  @moduledoc """
  Workshops: one-off events with enrollment by link.

  Deliberately separate from `Study`: being enrolled in a workshop does NOT make
  someone a student. A teacher can have 100 enrollments on a Saturday without any
  of it becoming a study link, which is a continuous relationship of another kind.

  Payment privacy is a context rule, not a template one: public reads go through
  `EnrollmentQuery.list_participants/1`, which does not even project the payment
  fields.
  """

  import Ecto.Query, only: [from: 2]

  require Logger

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.Engagement.SafeDispatch
  alias OGrupoDeEstudos.Media.Storage
  alias OGrupoDeEstudos.Media.Video
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Sequences
  alias OGrupoDeEstudos.Sequences.CitationQuery
  alias OGrupoDeEstudos.Workers.TranscodeWorkshopVideo

  alias OGrupoDeEstudos.Workshops.{
    Access,
    AdminQuery,
    EnrollmentPayment,
    EnrollmentQuery,
    MediaQuery,
    PackageQuery,
    PackageSplit,
    ProgramAdmin,
    ProgramAdminQuery,
    ProgramEnrollment,
    ProgramQuery,
    Receipts,
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
    WorkshopSequence,
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
  defdelegate pending_teacher_reminders(de, ate), to: WorkshopQuery
  defdelegate mark_teacher_reminded(workshop_ids), to: WorkshopQuery

  defdelegate get_enrollment(workshop_id, user_id), to: EnrollmentQuery, as: :get_for_user

  @doc "Creates a workshop as a draft. Any user can."
  @spec create_workshop(User.t(), map()) :: {:ok, Workshop.t()} | {:error, Ecto.Changeset.t()}
  def create_workshop(%User{id: organizer_id}, attrs) do
    %Workshop{}
    |> Workshop.changeset(Map.put(normalize(attrs), :organizer_id, organizer_id))
    |> Repo.insert()
  end

  @doc "Edits a workshop of the organizer themselves."
  @spec update_workshop(User.t(), Workshop.t(), map()) ::
          {:ok, Workshop.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def update_workshop(%User{} = user, %Workshop{} = workshop, attrs) do
    with :ok <- ensure_admin(workshop, user) do
      workshop
      |> Workshop.changeset(normalize(attrs))
      |> Repo.update()
    end
  end

  @doc "Publishes: from here on it shows on the agenda and accepts enrollment."
  @spec publish_workshop(User.t(), Workshop.t()) ::
          {:ok, Workshop.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def publish_workshop(%User{} = user, %Workshop{} = workshop) do
    with :ok <- ensure_admin(workshop, user) do
      workshop |> Workshop.status_changeset(:published) |> Repo.update()
    end
  end

  @doc """
  Cancels while preserving the record: enrollments, who paid and the conversation
  keep existing. Deleting for good only makes sense for an empty draft.
  """
  @spec cancel_workshop(User.t(), Workshop.t()) ::
          {:ok, Workshop.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def cancel_workshop(%User{} = user, %Workshop{} = workshop) do
    with :ok <- ensure_admin(workshop, user) do
      workshop |> Workshop.status_changeset(:cancelled) |> Repo.update()
    end
  end

  @doc """
  Deletes for good. Draft only, with nobody enrolled, and only the creator.

  Out of the admin set on purpose: a co-organizer administers, it does not destroy.
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

  @doc "Queue of requests waiting for an answer. Takes the workshop or just the id."
  @spec list_pending_requests(Workshop.t() | Ecto.UUID.t()) :: [map()]
  def list_pending_requests(%Workshop{id: id}), do: JoinRequestQuery.list_pending(id)
  def list_pending_requests(workshop_id), do: JoinRequestQuery.list_pending(workshop_id)

  @doc "How many requests are waiting, for the panel counter."
  @spec count_pending_requests(Workshop.t() | Ecto.UUID.t()) :: non_neg_integer()
  def count_pending_requests(%Workshop{id: id}), do: JoinRequestQuery.count_pending(id)
  def count_pending_requests(workshop_id), do: JoinRequestQuery.count_pending(workshop_id)

  @doc """
  Who can OPEN the workshop page.

  Every published workshop opens for anyone, private included: hiding it would
  make the agenda look empty exactly when people are using it. What is protected
  is the inside, not the existence.
  """
  @spec can_see_page?(Workshop.t(), User.t() | nil) :: boolean()
  def can_see_page?(%Workshop{status: status}, _user) when status in [:published, :cancelled],
    do: true

  def can_see_page?(%Workshop{} = workshop, %User{} = user), do: admin?(workshop, user)
  def can_see_page?(%Workshop{}, nil), do: false

  @doc """
  Whether the person has access to the INSIDE: names of who is going, gallery,
  conversation and payment data.

  Public opens for anyone with an account. Private requires approval, which turns
  into enrollment.
  """
  @spec inside_open?(Workshop.t(), User.t() | nil) :: boolean()
  def inside_open?(%Workshop{visibility: :public}, %User{}), do: true
  def inside_open?(%Workshop{visibility: :public}, nil), do: false
  def inside_open?(%Workshop{}, nil), do: false

  def inside_open?(%Workshop{} = workshop, %User{} = user) do
    admin?(workshop, user) or not is_nil(EnrollmentQuery.get_for_user(workshop.id, user.id))
  end

  @doc "Where this person's request stands: `:none`, `:pending`, `:approved` or `:rejected`."
  @spec join_status(Workshop.t(), User.t() | nil) :: :none | :pending | :approved | :rejected
  def join_status(%Workshop{}, nil), do: :none

  def join_status(%Workshop{} = workshop, %User{} = user),
    do: JoinRequestQuery.status(workshop.id, user.id)

  @doc """
  Asks to join a private workshop.

  Asking does not enroll: the seat only exists after approval. An earlier
  rejection does not close the door, the same request goes back to the queue.
  """
  @spec request_join(Workshop.t(), User.t() | nil) ::
          {:ok, JoinRequest.t()} | {:error, :unauthorized | :not_private | :already_requested}
  def request_join(%Workshop{}, nil), do: {:error, :unauthorized}

  def request_join(%Workshop{visibility: :public}, %User{}), do: {:error, :not_private}

  def request_join(%Workshop{} = workshop, %User{} = user) do
    case JoinRequestQuery.get(workshop.id, user.id) do
      nil -> create_request(workshop, user)
      %JoinRequest{status: :rejected} = recusado -> retry_request(recusado, workshop, user)
      %JoinRequest{} -> {:error, :already_requested}
    end
  end

  defp create_request(workshop, user) do
    %JoinRequest{}
    |> JoinRequest.changeset(%{workshop_id: workshop.id, user_id: user.id, status: :pending})
    |> Repo.insert()
    |> notify_about_request(workshop, user)
  end

  defp retry_request(request, workshop, user) do
    request
    |> Ecto.Changeset.change(status: :pending, reviewed_at: nil, reviewed_by_id: nil)
    |> Repo.update()
    |> notify_about_request(workshop, user)
  end

  defp notify_about_request({:ok, request}, workshop, user) do
    SafeDispatch.run(fn ->
      Dispatcher.notify_workshop_join_request(user.id, workshop.organizer_id, workshop.id)
    end)

    {:ok, request}
  end

  defp notify_about_request({:error, _changeset}, _workshop, _user),
    do: {:error, :already_requested}

  @doc """
  Approves the request and enrolls in one go.

  Whoever asked to join already said what they wanted; a second confirming click
  would be bureaucracy for the same answer.
  """
  @spec approve_join(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, JoinRequest.t()} | {:error, :unauthorized | :not_found | :full | term()}
  def approve_join(%Workshop{} = workshop, %User{} = actor, request_id) do
    with :ok <- ensure_admin(workshop, actor),
         %JoinRequest{} = request <- fetch_request(workshop, request_id),
         %User{} = pessoa <- Accounts.get_user_by_id(request.user_id),
         # `enroll_overbooking` and not `enroll`: accepting is the teacher's call, since
         # they know whether one more fits in the room. The system warns, it does not decide.
         {:ok, _enrollment} <- enroll_overbooking(workshop, pessoa) do
      respond(request, :approved, actor, workshop, :workshop_join_approved)
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Rejects the request. Silent for the class, and the person can ask again."
  @spec reject_join(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, JoinRequest.t()} | {:error, :unauthorized | :not_found}
  def reject_join(%Workshop{} = workshop, %User{} = actor, request_id) do
    with :ok <- ensure_admin(workshop, actor),
         %JoinRequest{} = request <- fetch_request(workshop, request_id) do
      respond(request, :rejected, actor, workshop, :workshop_join_rejected)
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_request(workshop, request_id) do
    Repo.get_by(JoinRequest, id: request_id, workshop_id: workshop.id)
  rescue
    Ecto.Query.CastError -> nil
  end

  defp respond(request, status, actor, workshop, action) do
    request
    |> JoinRequest.review_changeset(status, actor)
    |> Repo.update()
    |> case do
      {:ok, answered} -> notify_answer(answered, workshop, action)
      error -> error
    end
  end

  defp notify_answer(request, workshop, action) do
    SafeDispatch.run(fn ->
      Dispatcher.notify_workshop_join_review(
        workshop.organizer_id,
        request.user_id,
        workshop.id,
        action
      )
    end)

    {:ok, request}
  end

  defdelegate list_teachers(workshop_id), to: TeacherQuery, as: :list_for_workshop

  @max_teachers 2

  @doc """
  Sets who teaches, replacing the whole list.

  Replacing instead of appending because that is how the form works: two slots,
  filled or not. Each entry is `%{user_id: id}` or `%{display_name: name}`.

  The organizer does not enter automatically: producing someone else's class is
  the common case, and assuming the creator teaches was the bug.
  """
  @spec set_teachers(Workshop.t(), User.t(), [map()]) ::
          {:ok, [map()]}
          | {:error, :unauthorized | :too_many_teachers | :invalid_teacher}
  def set_teachers(%Workshop{} = workshop, %User{} = actor, entries) do
    with :ok <- ensure_admin(workshop, actor),
         :ok <- ensure_fits(entries),
         {:ok, normalized} <- normalize_teachers(entries) do
      rewrite_teachers(workshop, normalized)
    end
  end

  defp ensure_fits(entries) when length(entries) <= @max_teachers, do: :ok
  defp ensure_fits(_too_many), do: {:error, :too_many_teachers}

  defp normalize_teachers(entries) do
    entries
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {entry, position_index}, {:ok, acc} ->
      case normalize_teacher(entry, position_index) do
        {:ok, limpa} -> {:cont, {:ok, [limpa | acc]}}
        :error -> {:halt, {:error, :invalid_teacher}}
      end
    end)
    |> case do
      {:ok, invertidas} -> {:ok, Enum.reverse(invertidas)}
      error -> error
    end
  end

  defp normalize_teacher(%{user_id: user_id}, position_index) when is_binary(user_id) do
    case Accounts.get_user_by_id(user_id) do
      nil -> :error
      %User{id: id} -> {:ok, %{user_id: id, display_name: nil, position: position_index}}
    end
  end

  defp normalize_teacher(%{display_name: name}, position_index) when is_binary(name) do
    case String.trim(name) do
      "" -> :error
      trimmed -> {:ok, %{user_id: nil, display_name: trimmed, position: position_index}}
    end
  end

  defp normalize_teacher(_neither_account_nor_name, _position_index), do: :error

  # Delete and rewrite in the same transaction: the list is short and the order
  # matters, and reconciling two rows would cost more code than rewriting.
  defp rewrite_teachers(workshop, entries) do
    Repo.transact(fn ->
      TeacherQuery.delete_all(workshop.id)
      Enum.reduce_while(entries, {:ok, []}, &insert_teacher(&1, &2, workshop))
    end)
  end

  defp insert_teacher(entry, {:ok, acc}, workshop) do
    %WorkshopTeacher{}
    |> WorkshopTeacher.changeset(Map.put(entry, :workshop_id, workshop.id))
    |> Repo.insert()
    |> case do
      {:ok, criado} -> {:cont, {:ok, [criado | acc]}}
      {:error, _changeset} -> {:halt, {:error, :invalid_teacher}}
    end
  end

  defdelegate list_steps(workshop_id), to: WorkshopStepQuery, as: :list_for_workshop

  @doc """
  Tells in which workshops THIS person saw this step.

  It is the way back that was missing: the collection was an island, and nothing
  on the step page recalled that it had been taught in a class the person took.
  """
  @spec workshops_where_seen(Ecto.UUID.t() | nil, Ecto.UUID.t()) :: [map()]
  defdelegate workshops_where_seen(user_id, step_id), to: WorkshopStepQuery, as: :where_user_saw

  @doc "Step ids the user saw in workshops they attended or organized, as a MapSet."
  @spec step_ids_seen_by(Ecto.UUID.t() | nil) :: MapSet.t()
  defdelegate step_ids_seen_by(user_id), to: WorkshopStepQuery

  @doc """
  Puts a collection step into the workshop list.

  Admins only: the list is what the class offered, and whoever taught it knows
  what they offered. Like-based curation was considered and dropped, because
  ordering by vote solves, with much more machinery, a problem the permission
  already solves.
  """
  @spec add_step(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, WorkshopStep.t()} | {:error, :unauthorized | :not_found | :already_added}
  def add_step(%Workshop{} = workshop, %User{} = actor, step_id) do
    with :ok <- ensure_admin(workshop, actor),
         %{id: id} <- fetch_step(step_id) do
      insert_step(workshop, id)
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_step(step_id) do
    Encyclopedia.get_step_by(id: step_id)
  rescue
    Ecto.Query.CastError -> nil
  end

  defp insert_step(workshop, step_id) do
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

  @doc "Removes a step from the workshop list."
  @spec remove_step(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, WorkshopStep.t()} | {:error, :unauthorized | :not_found}
  def remove_step(%Workshop{} = workshop, %User{} = actor, step_id) do
    with :ok <- ensure_admin(workshop, actor) do
      WorkshopStepQuery.delete(workshop.id, step_id)
    end
  end

  @doc "Sequences cited by this workshop, oldest citation first."
  @spec list_sequences(Ecto.UUID.t()) :: [CitationQuery.row()]
  defdelegate list_sequences(workshop_id), to: CitationQuery, as: :list_for_workshop

  @doc """
  Cites a sequence on the workshop page.

  Admins only, and on purpose: a sequence is refined work that belongs to whoever
  built it, and the class shows the one its teacher stands behind. A student takes
  it home by favoriting, not by attaching another one here.
  """
  @spec add_sequence(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, WorkshopSequence.t()} | {:error, :unauthorized | :not_found | :already_added}
  def add_sequence(%Workshop{} = workshop, %User{} = actor, sequence_id) do
    with :ok <- ensure_admin(workshop, actor),
         %{id: id} <- fetch_sequence(sequence_id) do
      insert_sequence(workshop, id)
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_sequence(sequence_id) do
    Sequences.get_sequence(sequence_id)
  rescue
    Ecto.Query.CastError -> nil
  end

  defp insert_sequence(workshop, sequence_id) do
    %WorkshopSequence{}
    |> WorkshopSequence.changeset(%{workshop_id: workshop.id, sequence_id: sequence_id})
    |> Repo.insert()
    |> case do
      {:ok, citation} -> {:ok, citation}
      {:error, %Ecto.Changeset{}} -> {:error, :already_added}
    end
  end

  @doc "Drops the citation. The sequence itself belongs to its author and stays."
  @spec remove_sequence(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, WorkshopSequence.t()} | {:error, :unauthorized | :not_found}
  def remove_sequence(%Workshop{} = workshop, %User{} = actor, sequence_id) do
    with :ok <- ensure_admin(workshop, actor) do
      case Repo.get_by(WorkshopSequence, workshop_id: workshop.id, sequence_id: sequence_id) do
        nil -> {:error, :not_found}
        citation -> Repo.delete(citation)
      end
    end
  rescue
    Ecto.Query.CastError -> {:error, :not_found}
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
  @max_media_bytes_per_workshop 2_147_483_648

  defdelegate list_media(workshop_id), to: MediaQuery, as: :list_for_workshop
  defdelegate get_media(media_id), to: MediaQuery, as: :get
  defdelegate media_usage(workshop_id), to: MediaQuery, as: :usage

  @doc """
  Who can see the gallery: whoever administers the workshop or is enrolled.

  The gallery is the content people pay for, so it does not follow the page
  visibility: a public workshop still keeps the gallery closed.
  """
  @spec can_see_media?(Workshop.t(), User.t() | nil) :: boolean()
  def can_see_media?(%Workshop{}, nil), do: false

  def can_see_media?(%Workshop{} = workshop, %User{} = user) do
    admin?(workshop, user) or not is_nil(EnrollmentQuery.get_for_user(workshop.id, user.id))
  end

  @doc """
  Stores a photo or video in the gallery.

  Only who is in the workshop uploads media. Media from an admin is marked as
  official, so it comes first and with a badge.
  """
  @spec add_media(Workshop.t(), User.t(), map()) ::
          {:ok, WorkshopMedia.t()}
          | {:error, :unauthorized | :unsupported_type | :storage_full | :media_quota | term()}
  def add_media(%Workshop{} = workshop, %User{} = user, %{
        tmp_path: tmp_path,
        content_type: content_type,
        byte_size: byte_size
      }) do
    with :ok <- ensure_can_upload(workshop, user),
         {:ok, kind} <- ensure_media_kind(content_type),
         :ok <- ensure_quota(workshop.id, byte_size),
         :ok <- ensure_espaco(byte_size),
         {:ok, key} <-
           Storage.put_private(
             gallery_folder(workshop.id),
             tmp_path,
             WorkshopMedia.extension(content_type)
           ) do
      inserir_media(workshop, user, kind, key, content_type, byte_size)
    end
  end

  defp ensure_can_upload(workshop, user) do
    if can_see_media?(workshop, user), do: :ok, else: {:error, :unauthorized}
  end

  defp ensure_media_kind(content_type) do
    case WorkshopMedia.kind_from_content_type(content_type) do
      :error -> {:error, :unsupported_type}
      kind -> {:ok, kind}
    end
  end

  defp ensure_quota(workshop_id, byte_size) do
    %{bytes: used} = MediaQuery.usage(workshop_id)

    if used + byte_size <= @max_media_bytes_per_workshop,
      do: :ok,
      else: {:error, :media_quota}
  end

  defp ensure_espaco(byte_size) do
    case Storage.free_bytes() do
      :unknown -> :ok
      free when free - byte_size > @min_free_bytes -> :ok
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

    case insert_with_job(atributos) do
      {:ok, media} -> {:ok, Repo.preload(media, :uploaded_by)}
      {:error, reason} -> discard_file(key, reason)
    end
  end

  # Media and transcode job go in the SAME transaction: either the video lands
  # with its conversion scheduled or nothing lands. Otherwise a failure to enqueue
  # would leave the row in "processing" forever with no job, and Lifeline does not
  # rescue a job that does not exist.
  defp insert_with_job(atributos) do
    Repo.transact(fn ->
      with {:ok, media} <- Repo.insert(WorkshopMedia.changeset(%WorkshopMedia{}, atributos)) do
        enqueued(media)
      end
    end)
  end

  # A video leaves the upload as `:processing`: the file is already stored and the
  # conversion happens later, so nobody watches a frozen progress bar while ffmpeg runs.
  defp enqueued(%WorkshopMedia{status: :processing, id: id} = media) do
    case Oban.insert(TranscodeWorkshopVideo.new(%{"media_id" => id})) do
      {:ok, _job} -> {:ok, media}
      {:error, reason} -> {:error, reason}
    end
  end

  defp enqueued(media), do: {:ok, media}

  defp discard_file(key, error) do
    Storage.delete_private(key)
    {:error, error}
  end

  @doc "How to serve a media file: `{:file, path}` or `{:redirect, url}`."
  @spec serve_media(WorkshopMedia.t()) ::
          {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}
  def serve_media(%WorkshopMedia{storage_key: key}), do: Storage.serve_private(key)

  @doc "How to serve the video poster. No poster is not_found, not an error."
  @spec serve_poster(WorkshopMedia.t()) ::
          {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}
  def serve_poster(%WorkshopMedia{poster_key: nil}), do: {:error, :not_found}
  def serve_poster(%WorkshopMedia{poster_key: key}), do: Storage.serve_private(key)

  @doc """
  Removes a media file from the gallery.

  The uploader removes their own; an admin removes any. It leaves the screen
  right away and the file goes with it.
  """
  @spec remove_media(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, WorkshopMedia.t()} | {:error, :unauthorized | :not_found}
  def remove_media(%Workshop{} = workshop, %User{} = user, media_id) do
    with %WorkshopMedia{} = media <- MediaQuery.get_scoped(media_id, workshop.id),
         :ok <- ensure_can_delete(workshop, user, media) do
      delete_media(media)
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_can_delete(workshop, user, media),
    do: Policy.authorize(:delete_media, user, {media, access_for(workshop, user)})

  defp delete_media(media) do
    agora = DateTime.utc_now() |> DateTime.truncate(:second)

    case media |> Ecto.Changeset.change(deleted_at: agora) |> Repo.update() do
      {:ok, deleted} ->
        Storage.delete_private(media.storage_key)
        delete_poster(media.poster_key)
        {:ok, deleted}

      error ->
        error
    end
  end

  defp delete_poster(nil), do: :ok
  defp delete_poster(key), do: Storage.delete_private(key)

  @doc """
  Converts the video of a media row to 720p H.264 and marks it as ready.

  Called by `Workers.TranscodeWorkshopVideo`, never straight from the boundary:
  ffmpeg takes tens of seconds and does not fit in a `handle_event`.

  Always ends in `:ready`, even when it goes wrong. A video stuck in "processing"
  forever is worse than a large video: the uploader sees theirs in the gallery
  either way, and it is the person on an old Android who may not be able to open
  it. Failing the upload over that would trade a partial problem for a total one.
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
    mark_ready(media, %{})
  end

  defp converter(media, true) do
    output = temp_path("mp4")

    try do
      run_transcode(media, output)
    after
      File.rm(output)
    end
  end

  # with_private_file exists because on an external provider the original is not
  # a local file: the adapter downloads to a temporary one and ffmpeg reads from there.
  defp run_transcode(media, output) do
    case Storage.with_private_file(media.storage_key, &Video.transcode(&1, output)) do
      {:ok, :ok} -> store_converted(media, output, size(output))
      {:ok, {:error, reason}} -> give_up(media, reason)
      {:error, reason} -> give_up(media, reason)
    end
  end

  # An ffmpeg that exits 0 and writes an empty file exists. Storing that would
  # delete the uploaded video and put nothing in its place.
  defp store_converted(media, _output, 0), do: give_up(media, :empty_output)

  defp store_converted(media, output, bytes) do
    case Storage.put_private(gallery_folder(media.workshop_id), output, ".mp4") do
      {:ok, key} -> replace_file(media, key, bytes, generate_poster(media, output))
      {:error, reason} -> give_up(media, reason)
    end
  end

  defp replace_file(media, key, bytes, poster_key) do
    atributos = %{
      storage_key: key,
      content_type: "video/mp4",
      byte_size: bytes,
      poster_key: poster_key
    }

    case mark_ready(media, atributos) do
      :ok -> Storage.delete_private(media.storage_key)
      # Whoever deleted during the transcode wins: the converted file and the poster
      # go away instead of becoming orphans, and there is nothing to retry.
      {:error, :deleted} -> discard_converted(key, poster_key)
    end
  end

  defp discard_converted(key, poster_key) do
    Storage.delete_private(key)
    delete_poster(poster_key)
    :ok
  end

  defp give_up(media, reason) do
    Logger.warning("[Transcode] mídia #{media.id} falhou (#{inspect(reason)}), fica o original")

    case mark_ready(media, %{}) do
      :ok -> :ok
      {:error, :deleted} -> :ok
    end
  end

  # Conditioned on `deleted_at` AGAIN, not only at the job entry: ffmpeg takes
  # minutes, and a deletion in between cannot be run over.
  defp mark_ready(media, atributos) do
    campos =
      atributos
      |> Map.put(:status, :ready)
      |> Map.put(:updated_at, NaiveDateTime.utc_now(:second))
      |> Map.to_list()

    viva = from(m in WorkshopMedia, where: m.id == ^media.id and is_nil(m.deleted_at))

    case Repo.update_all(viva, set: campos) do
      {1, _} -> :ok
      {0, _} -> {:error, :deleted}
    end
  end

  # The poster is decoration: without it the gallery shows the first frame, which
  # is usually black. Not a reason to hold the media in "processing".
  defp generate_poster(media, video) do
    dest = temp_path("jpg")

    try do
      store_poster(media, video, dest)
    after
      File.rm(dest)
    end
  end

  defp store_poster(media, video, dest) do
    case Video.poster(video, dest) do
      :ok -> poster_key_for(media, dest)
      {:error, _reason} -> nil
    end
  end

  defp poster_key_for(media, dest) do
    case Storage.put_private(gallery_folder(media.workshop_id), dest, ".jpg") do
      {:ok, key} -> key
      {:error, _reason} -> nil
    end
  end

  # One folder per workshop: the bucket stays browsable by context, and what
  # belongs to a workshop lives together (original, converted and poster).
  defp gallery_folder(workshop_id), do: Path.join(@media_dir, workshop_id)

  defp temp_path(ext) do
    name = "workshop_video_#{System.unique_integer([:positive])}.#{ext}"
    Path.join(System.tmp_dir!(), name)
  end

  defp size(path) do
    case File.stat(path) do
      {:ok, %{size: bytes}} -> bytes
      {:error, _reason} -> 0
    end
  end

  @doc """
  Buys the package: joins ALL published workshops of the program.

  All or nothing, unlike single enrollment. Whoever paid for three days cannot
  end up in two: if one class fills up midway, the enrollments already made are
  undone and nobody stays halfway in.
  """
  @spec enroll_in_package(WorkshopProgram.t(), User.t()) ::
          {:ok, ProgramEnrollment.t()}
          | {:error,
             :no_package | :organizer | :already_enrolled | {:full, Workshop.t()} | term()}
  def enroll_in_package(%WorkshopProgram{} = program, %User{} = user) do
    with :ok <- ensure_package(program),
         :ok <- ensure_not_organizer(program, user),
         {:ok, program_enrollment} <- create_membership(program, user) do
      cover_workshops(program, user, program_enrollment)
    end
  end

  defp ensure_package(program) do
    if WorkshopProgram.pacote?(program), do: :ok, else: {:error, :no_package}
  end

  defp ensure_not_organizer(%WorkshopProgram{owner_id: id}, %User{id: id}),
    do: {:error, :organizer}

  defp ensure_not_organizer(_program, _user), do: :ok

  defp create_membership(program, user) do
    %ProgramEnrollment{}
    |> ProgramEnrollment.changeset(%{program_id: program.id, user_id: user.id})
    |> Repo.insert()
    |> case do
      {:ok, program_enrollment} -> {:ok, program_enrollment}
      {:error, %Ecto.Changeset{}} -> {:error, :already_enrolled}
    end
  end

  # Each workshop gets its own transaction (same reason as enroll_many), and the
  # compensation undoes whatever already landed if one fails.
  defp cover_workshops(program, user, program_enrollment) do
    workshops = ProgramQuery.list_workshops(program.id)

    case Enum.reduce_while(workshops, [], &cover_one(&1, user, program_enrollment, &2)) do
      {:error, reason, created} -> undo_package(program_enrollment, created, reason)
      _criadas -> {:ok, program_enrollment}
    end
  end

  defp cover_one(workshop, user, program_enrollment, created) do
    case ensure_enrollment(workshop, user, program_enrollment) do
      {:ok, :created} -> {:cont, [workshop | created]}
      {:ok, :already_there} -> {:cont, created}
      {:error, reason} -> {:halt, {:error, {reason, workshop}, created}}
    end
  end

  # Whoever was already enrolled in one of the workshops moves to the package
  # without a duplicated enrollment.
  defp ensure_enrollment(workshop, user, program_enrollment) do
    case EnrollmentQuery.get_for_user(workshop.id, user.id) do
      nil -> enroll_through_package(workshop, user, program_enrollment)
      enrollment -> link_to_package(enrollment, program_enrollment)
    end
  end

  defp enroll_through_package(workshop, user, program_enrollment) do
    case insert_enrollment_locked(workshop, user) do
      {:ok, enrollment} ->
        enrollment
        |> Ecto.Changeset.change(program_enrollment_id: program_enrollment.id)
        |> Repo.update()
        |> case do
          {:ok, _} -> {:ok, :created}
          error -> error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp link_to_package(enrollment, program_enrollment) do
    enrollment
    |> Ecto.Changeset.change(program_enrollment_id: program_enrollment.id)
    |> Repo.update()
    |> case do
      {:ok, _} -> {:ok, :already_there}
      error -> error
    end
  end

  defp undo_package(program_enrollment, created, {reason, workshop}) do
    for w <- created, do: delete_enrollment(w.id, program_enrollment.user_id)
    Repo.delete(program_enrollment)
    {:error, {reason, workshop}}
  end

  defp delete_enrollment(workshop_id, user_id) do
    case EnrollmentQuery.get_for_user(workshop_id, user_id) do
      nil -> :ok
      enrollment -> Repo.delete(enrollment)
    end
  end

  @doc "Who bought the package. Only the program creator sees it."
  @spec list_package_enrollments(WorkshopProgram.t(), User.t()) ::
          {:ok, [map()]} | {:error, :unauthorized}
  def list_package_enrollments(%WorkshopProgram{} = program, %User{} = user) do
    with :ok <- ensure_program_owner(program, user) do
      {:ok, PackageQuery.list_for_program(program.id)}
    end
  end

  @doc "Whoever enrolled in every workshop by hand: the package they meant, not bought."
  @spec list_package_candidates(WorkshopProgram.t(), User.t()) ::
          {:ok, [map()]} | {:error, :unauthorized}
  def list_package_candidates(%WorkshopProgram{} = program, %User{} = user) do
    with :ok <- ensure_program_owner(program, user) do
      {:ok, PackageQuery.list_candidates(program.id)}
    end
  end

  @doc """
  Turns a hand-made pile of daily enrollments into the package it meant to be.

  Converting is bookkeeping, not enrolling: whoever is missing a workshop is
  refused instead of silently enrolled, and capacity is never touched. The new
  package starts pending so the organizer records what was actually received;
  the old daily paid flags stop counting on their own (see `EnrollmentPayment`).
  """
  @spec convert_to_package(WorkshopProgram.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, ProgramEnrollment.t()}
          | {:error,
             :unauthorized
             | :not_found
             | :not_fully_enrolled
             | :already_enrolled
             | :no_package
             | term()}
  def convert_to_package(%WorkshopProgram{} = program, %User{} = actor, user_id) do
    with :ok <- ensure_program_owner(program, actor),
         {:ok, student} <- fetch_student(user_id),
         :ok <- ensure_fully_enrolled(program, student) do
      join_or_adopt(program, student)
    end
  end

  defp join_or_adopt(program, student) do
    case PackageQuery.get_for_user(program.id, student.id) do
      nil -> enroll_in_package(program, student)
      membership -> adopt_loose_enrollments(program, student, membership)
    end
  end

  # A membership can exist while the daily enrollments sit loose: a package
  # bought while the program had no published workshop covered nothing, and the
  # days enrolled afterwards never pointed at it. Adopting links them and keeps
  # whatever payment the membership already recorded.
  defp adopt_loose_enrollments(program, student, membership) do
    linked =
      program.id
      |> ProgramQuery.list_workshops()
      |> Enum.count(&link_loose(&1, student, membership))

    if linked > 0, do: {:ok, membership}, else: {:error, :already_enrolled}
  end

  defp link_loose(workshop, student, membership) do
    case EnrollmentQuery.get_for_user(workshop.id, student.id) do
      %WorkshopEnrollment{program_enrollment_id: nil} = enrollment ->
        {:ok, _} = link_enrollment(enrollment, membership)
        true

      _linked_or_absent ->
        false
    end
  end

  defp fetch_student(user_id) do
    case Accounts.get_user_by_id(user_id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  defp ensure_fully_enrolled(program, user) do
    if PackageQuery.fully_enrolled?(program.id, user.id) do
      :ok
    else
      {:error, :not_fully_enrolled}
    end
  end

  @doc "Resumo do pacote: quantos compraram, quantos pagaram, quanto entrou."
  @spec package_summary(WorkshopProgram.t(), User.t()) :: {:ok, map()} | {:error, :unauthorized}
  def package_summary(%WorkshopProgram{} = program, %User{} = user) do
    with :ok <- ensure_program_owner(program, user) do
      {:ok, PackageQuery.summary(program.id, program.price_cents)}
    end
  end

  @doc """
  How the package price lands on each workshop of the program.

  This is the division of the price as it stands today, which is what the
  organizer needs while setting it. What an individual package actually paid is
  in the roster of each workshop: someone who bought before a workshop was
  published covers a smaller set, and their slices are bigger.
  """
  @spec package_shares(WorkshopProgram.t(), User.t()) ::
          {:ok, [%{id: Ecto.UUID.t(), title: String.t(), share_cents: non_neg_integer()}]}
          | {:error, :unauthorized}
  def package_shares(%WorkshopProgram{} = program, %User{} = user) do
    with :ok <- ensure_program_owner(program, user) do
      workshops = ProgramQuery.list_workshops(program.id)

      shares =
        PackageSplit.shares(program.price_cents, Enum.map(workshops, &{&1.id, &1.price_cents}))

      {:ok,
       Enum.map(workshops, fn w ->
         %{id: w.id, title: w.title, share_cents: Map.get(shares, w.id, 0)}
       end)}
    end
  end

  @doc """
  The balance of the whole program: what each workshop made and what came in
  altogether.

  A program is not only what was sold as a package. Someone who bought a single
  day paid the workshop, and that money belongs to the event just the same, so
  each line separates the two sources and the total is the two added up.

  One query for every enrollment of the program instead of one per workshop:
  the panel already shows a dozen lines and would otherwise open a dozen round
  trips to draw a single table.
  """
  @spec program_revenue(WorkshopProgram.t(), User.t()) :: {:ok, map()} | {:error, :unauthorized}
  def program_revenue(%WorkshopProgram{} = program, %User{} = user) do
    with :ok <- ensure_program_owner(program, user) do
      workshops = ProgramQuery.list_workshops(program.id)
      {:ok, balance(workshops)}
    end
  end

  defp balance(workshops) do
    rows = workshops |> Enum.map(& &1.id) |> EnrollmentQuery.list_for_workshops()

    covered =
      rows |> EnrollmentPayment.package_ids() |> EnrollmentQuery.covered_workshops_by_package()

    by_workshop = Enum.group_by(rows, & &1.workshop_id)
    lines = Enum.map(workshops, &workshop_line(&1, by_workshop, covered))

    %{
      workshops: lines,
      package_cents: sum_of(lines, :package_cents),
      individual_cents: sum_of(lines, :individual_cents),
      total_cents: sum_of(lines, :total_cents)
    }
  end

  defp workshop_line(workshop, by_workshop, covered) do
    summary =
      by_workshop
      |> Map.get(workshop.id, [])
      |> EnrollmentPayment.enrich(covered, workshop.id)
      |> EnrollmentPayment.summarize(workshop.price_cents)

    %{
      id: workshop.id,
      title: workshop.title,
      paid: summary.paid,
      package_cents: summary.package_cents,
      individual_cents: summary.individual_cents,
      total_cents: summary.revenue_cents
    }
  end

  defp sum_of(lines, key), do: lines |> Enum.map(&Map.fetch!(&1, key)) |> Enum.sum()

  @doc "Marks the package payment."
  @spec set_package_payment(WorkshopProgram.t(), User.t(), Ecto.UUID.t(), atom()) ::
          {:ok, ProgramEnrollment.t()} | {:error, :unauthorized | :not_found | term()}
  def set_package_payment(%WorkshopProgram{} = program, %User{} = user, enrollment_id, status)
      when status in [:pending, :paid, :waived] do
    with :ok <- ensure_program_owner(program, user),
         %ProgramEnrollment{} = program_enrollment <-
           PackageQuery.get_scoped(enrollment_id, program.id) do
      program_enrollment |> ProgramEnrollment.payment_changeset(status) |> Repo.update()
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "The person's membership in this program package, or `nil`."
  @spec package_enrollment(WorkshopProgram.t(), User.t() | nil) :: ProgramEnrollment.t() | nil
  def package_enrollment(%WorkshopProgram{}, nil), do: nil

  def package_enrollment(%WorkshopProgram{} = program, %User{} = user),
    do: PackageQuery.get_for_user(program.id, user.id)

  @doc """
  The community agenda, mixing loose workshops and programs in date order.

  Without a search, a workshop inside a program does NOT show up loose: a festival
  with fifteen workshops would become fifteen lines repeating the same name. With
  a search the program opens, otherwise the workshop inside would be impossible to find.

  Each item is `%{kind: :workshop
   :program, starts_at: ...}`, so the screen
  renders without having to decide anything.
  """
  @spec list_agenda(keyword()) :: [map()]
  def list_agenda(opts \\ []) do
    searching = searching?(opts[:search])

    programs = ProgramQuery.list_feed(opts)
    summaries = ProgramQuery.summaries_by_ids(Enum.map(programs, fn {p, _} -> p.id end))

    opts
    |> Keyword.put(:only_loose, not searching)
    |> WorkshopQuery.list_feed()
    |> without_repeating_program(programs)
    |> Enum.map(&workshop_item/1)
    |> Enum.concat(Enum.map(programs, &program_item(&1, summaries)))
    |> sort_by_date(Keyword.get(opts, :period, :upcoming))
  end

  # In a search the program and its workshops can match at the same time. Without
  # this the festival card would come sandwiched between its own children, and the
  # counter would announce three events where there is one.
  defp without_repeating_program(workshops, programs) do
    already_listed = MapSet.new(programs, fn {program, _} -> program.id end)

    Enum.reject(workshops, &MapSet.member?(already_listed, &1.program_id))
  end

  defp searching?(nil), do: false
  defp searching?(""), do: false
  defp searching?(term), do: String.trim(term) != ""

  defp workshop_item(workshop) do
    %{kind: :workshop, id: workshop.id, starts_at: workshop.starts_at, workshop: workshop}
  end

  # The period decides WHICH programs come in; the summary shown is the whole
  # festival, otherwise the card would say "3 workshops" while the program page
  # shows fifteen.
  defp program_item({program, period}, summaries) do
    %{
      kind: :program,
      id: program.id,
      starts_at: period.starts_at,
      program: program,
      summary: Map.get(summaries, program.id, period)
    }
  end

  # In the past the agenda runs from most recent backwards: what just happened
  # matters more than what happened a year ago.
  defp sort_by_date(itens, :past), do: Enum.sort_by(itens, & &1.starts_at, {:desc, DateTime})
  defp sort_by_date(itens, _period), do: Enum.sort_by(itens, & &1.starts_at, DateTime)

  # One folder per poster owner, workshops and programs apart. The file name stays
  # random, which is what prevents scanning; the id in the folder only organizes
  # (the route is by slug, an id opens nothing).
  defp flyer_folder(%Workshop{id: id}), do: "flyers/workshops/#{id}"
  # The folder stays in Portuguese: it is where the flyers already are on disk,
  # and renaming it orphans every one of them.
  defp flyer_folder(%WorkshopProgram{id: id}), do: "flyers/programas/#{id}"

  @doc """
  Stores the promotional flyer of the workshop and deletes the previous one.

  Takes the temporary file from the upload, not a path chosen by the user: the
  storage decides where the file lives.
  """
  @spec put_workshop_flyer(Workshop.t(), User.t(), String.t(), String.t()) ::
          {:ok, Workshop.t()} | {:error, :unauthorized | term()}
  def put_workshop_flyer(%Workshop{} = workshop, %User{} = user, tmp_path, ext) do
    with :ok <- ensure_admin(workshop, user),
         {:ok, url} <- Storage.save_image(flyer_folder(workshop), tmp_path, ext) do
      previous = workshop.flyer_path
      result = workshop |> Workshop.flyer_changeset(url) |> Repo.update()
      discard_flyer(result, previous)
    end
  end

  @doc "Removes the workshop flyer and deletes the file."
  @spec remove_workshop_flyer(Workshop.t(), User.t()) ::
          {:ok, Workshop.t()} | {:error, :unauthorized | term()}
  def remove_workshop_flyer(%Workshop{} = workshop, %User{} = user) do
    with :ok <- ensure_admin(workshop, user) do
      previous = workshop.flyer_path
      result = workshop |> Workshop.flyer_changeset(nil) |> Repo.update()
      discard_flyer(result, previous)
    end
  end

  @doc "Stores the program flyer and deletes the previous one."
  @spec put_program_flyer(WorkshopProgram.t(), User.t(), String.t(), String.t()) ::
          {:ok, WorkshopProgram.t()} | {:error, :unauthorized | term()}
  def put_program_flyer(%WorkshopProgram{} = program, %User{} = user, tmp_path, ext) do
    with :ok <- ensure_program_owner(program, user),
         {:ok, url} <- Storage.save_image(flyer_folder(program), tmp_path, ext) do
      previous = program.flyer_path
      result = program |> WorkshopProgram.flyer_changeset(url) |> Repo.update()
      discard_flyer(result, previous)
    end
  end

  @doc "Removes the program flyer and deletes the file."
  @spec remove_program_flyer(WorkshopProgram.t(), User.t()) ::
          {:ok, WorkshopProgram.t()} | {:error, :unauthorized | term()}
  def remove_program_flyer(%WorkshopProgram{} = program, %User{} = user) do
    with :ok <- ensure_program_owner(program, user) do
      previous = program.flyer_path
      result = program |> WorkshopProgram.flyer_changeset(nil) |> Repo.update()
      discard_flyer(result, previous)
    end
  end

  # Only deletes the old file after the database confirms. The other way around, an
  # update error would leave the row pointing at a file that no longer exists.
  defp discard_flyer({:ok, _} = result, nil), do: result

  defp discard_flyer({:ok, _} = result, previous) do
    Storage.delete_image(previous)
    result
  end

  defp discard_flyer(error, _antigo), do: error

  defdelegate get_program_by_slug(slug), to: ProgramQuery, as: :get_by_slug
  defdelegate get_program(id), to: ProgramQuery, as: :get
  defdelegate list_programs_for_owner(owner_id), to: ProgramQuery, as: :list_for_owner
  defdelegate program_summaries(program_ids), to: ProgramQuery, as: :summaries_by_ids
  defdelegate program_slugs_by_ids(ids), to: ProgramQuery, as: :slugs_by_ids

  @doc "Workshops of the program, earliest to latest."
  @spec list_program_workshops(WorkshopProgram.t(), keyword()) :: [Workshop.t()]
  def list_program_workshops(%WorkshopProgram{} = program, opts \\ []),
    do: ProgramQuery.list_workshops(program.id, opts)

  @doc "Creates a program. Anyone with an account can."
  @spec create_program(User.t(), map()) ::
          {:ok, WorkshopProgram.t()} | {:error, Ecto.Changeset.t()}
  def create_program(%User{id: owner_id}, attrs) do
    %WorkshopProgram{}
    |> WorkshopProgram.changeset(Map.put(attrs, :owner_id, owner_id))
    |> Repo.insert()
  end

  @doc "Edits the program. Creator only."
  @spec update_program(User.t(), WorkshopProgram.t(), map()) ::
          {:ok, WorkshopProgram.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def update_program(%User{} = user, %WorkshopProgram{} = program, attrs) do
    with :ok <- ensure_program_owner(program, user) do
      program |> WorkshopProgram.changeset(attrs) |> Repo.update()
    end
  end

  @doc "Publishes: from here on the link opens for whoever has no account."
  @spec publish_program(User.t(), WorkshopProgram.t()) ::
          {:ok, WorkshopProgram.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def publish_program(%User{} = user, %WorkshopProgram{} = program) do
    with :ok <- ensure_program_owner(program, user) do
      program |> WorkshopProgram.status_changeset(:published) |> Repo.update()
    end
  end

  @doc "Cancels the program. The workshops inside keep existing."
  @spec cancel_program(User.t(), WorkshopProgram.t()) ::
          {:ok, WorkshopProgram.t()} | {:error, Ecto.Changeset.t() | :unauthorized}
  def cancel_program(%User{} = user, %WorkshopProgram{} = program) do
    with :ok <- ensure_program_owner(program, user) do
      program |> WorkshopProgram.status_changeset(:cancelled) |> Repo.update()
    end
  end

  @doc """
  Puts a workshop into the program.

  Requires administering both sides. That is how a festival works: the crew
  becomes co-organizer of each teacher's workshop and assembles the program.
  """
  @spec attach_workshop(WorkshopProgram.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, Workshop.t()} | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def attach_workshop(%WorkshopProgram{} = program, %User{} = user, workshop_id) do
    move_workshop(program, user, workshop_id, program.id)
  end

  @doc "Removes the workshop from the program. It keeps existing, loose."
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

  # Reading and running the program is open to the co-organizers; what stays
  # with the creator alone is the guest list of who administers it.
  defp ensure_program_owner(%WorkshopProgram{} = program, %User{} = user) do
    if program_admin?(program, user), do: :ok, else: {:error, :unauthorized}
  end

  defp ensure_program_creator(%WorkshopProgram{owner_id: id}, %User{id: id}), do: :ok
  defp ensure_program_creator(%WorkshopProgram{}, %User{}), do: {:error, :unauthorized}

  @doc "true when the person administers the program (creator or co-organizer)."
  @spec program_admin?(WorkshopProgram.t(), User.t() | nil) :: boolean()
  def program_admin?(%WorkshopProgram{}, nil), do: false
  def program_admin?(%WorkshopProgram{owner_id: id}, %User{id: id}), do: true

  def program_admin?(%WorkshopProgram{} = program, %User{} = user),
    do: ProgramAdminQuery.co_admin?(program.id, user.id)

  @doc "Co-organizers of the program, with display data."
  @spec list_program_admins(WorkshopProgram.t()) :: [map()]
  def list_program_admins(%WorkshopProgram{} = program),
    do: ProgramAdminQuery.list_co_admins(program.id)

  @doc """
  Promotes someone to co-organizer of the program.

  Only the creator promotes: whoever comes in sees the money of the event, and
  that door belongs to whoever opened the event. It does not hand over the
  workshops inside the program, which can be other people's.
  """
  @spec add_program_admin(WorkshopProgram.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, ProgramAdmin.t()} | {:error, :unauthorized | :already_admin | :not_found}
  def add_program_admin(%WorkshopProgram{} = program, %User{} = actor, user_id) do
    with :ok <- ensure_program_creator(program, actor),
         :ok <- ensure_not_program_admin(program, user_id),
         %User{} = user <- Accounts.get_user_by_id(user_id) do
      insert_program_admin(program, actor, user)
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_not_program_admin(program, user_id) do
    if program_admin?(program, %User{id: user_id}),
      do: {:error, :already_admin},
      else: :ok
  end

  defp insert_program_admin(program, actor, user) do
    %ProgramAdmin{}
    |> ProgramAdmin.changeset(%{
      program_id: program.id,
      user_id: user.id,
      invited_by_id: actor.id
    })
    |> Repo.insert()
    |> case do
      {:ok, admin} -> {:ok, admin}
      {:error, %Ecto.Changeset{}} -> {:error, :already_admin}
    end
  end

  @doc "Removes a co-organizer. The creator removes anyone; the others only themselves."
  @spec remove_program_admin(WorkshopProgram.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, ProgramAdmin.t()} | {:error, :unauthorized | :cannot_remove_owner | :not_found}
  def remove_program_admin(%WorkshopProgram{owner_id: id}, %User{}, id),
    do: {:error, :cannot_remove_owner}

  def remove_program_admin(%WorkshopProgram{} = program, %User{} = actor, user_id) do
    with :ok <- ensure_can_leave_program(program, actor, user_id) do
      ProgramAdminQuery.delete(program.id, user_id)
    end
  end

  defp ensure_can_leave_program(program, %User{id: actor_id}, actor_id) do
    if program_admin?(program, %User{id: actor_id}), do: :ok, else: {:error, :unauthorized}
  end

  defp ensure_can_leave_program(program, actor, _user_id),
    do: ensure_program_creator(program, actor)

  @doc "Ids of who administers: the creator plus the co-organizers."
  @spec admin_ids(Workshop.t()) :: [Ecto.UUID.t()]
  def admin_ids(%Workshop{} = workshop) do
    [workshop.organizer_id | AdminQuery.co_admin_ids(workshop.id)]
  end

  @doc "true when the person administers the workshop (creator or co-organizer)."
  @spec admin?(Workshop.t(), User.t() | nil) :: boolean()
  def admin?(%Workshop{}, nil), do: false
  def admin?(%Workshop{organizer_id: id}, %User{id: id}), do: true

  def admin?(%Workshop{} = workshop, %User{} = user),
    do: AdminQuery.co_admin?(workshop.id, user.id)

  @doc """
  Resolves in one pass what the person can do in this workshop.

  The Policy is pure and does not query the database; this struct carries the facts.
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

  @doc "Co-organizers with display data."
  @spec list_co_admins(Workshop.t()) :: [map()]
  def list_co_admins(%Workshop{} = workshop), do: AdminQuery.list_co_admins(workshop.id)

  @doc """
  Promotes someone to co-organizer. Only the creator promotes: whoever comes in
  gets to see the payment control, and that door belongs to the creator.
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

  @doc "Removes a co-organizer. The creator removes anyone; the others only themselves."
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
  Enrolls someone in a published workshop.

  The seat is checked inside a transaction with the workshop locked (`FOR UPDATE`):
  the unique index prevents the same person twice, but not two different people
  taking the last seat at the same time.
  """
  @spec enroll(Workshop.t(), User.t()) ::
          {:ok, WorkshopEnrollment.t()}
          | {:error, :organizer | :not_open | :full | :already_enrolled}
  def enroll(%Workshop{} = workshop, %User{} = user) do
    case admin?(workshop, user) do
      true ->
        {:error, :organizer}

      false ->
        workshop
        |> insert_enrollment_locked(user)
        |> link_to_held_package(workshop, user)
        |> notify_organizers(workshop, user)
    end
  end

  # Whoever holds the package of this workshop's program enrolls already linked
  # to it. A loose enrollment next to a membership miscounts the money (a full
  # daily price beside the package) and put the same person on the package list
  # and on the candidates at once. Found in production on 2026-08-04.
  #
  # The membership comes from the database and not from the struct in hand: the
  # caller may hold a workshop loaded before it joined the program.
  defp link_to_held_package({:ok, enrollment}, %Workshop{}, user) do
    case PackageQuery.held_for_workshop(enrollment.workshop_id, user.id) do
      nil -> {:ok, enrollment}
      membership -> link_enrollment(enrollment, membership)
    end
  end

  defp link_to_held_package(result, _workshop, _user), do: result

  defp link_enrollment(enrollment, membership) do
    enrollment
    |> Ecto.Changeset.change(program_enrollment_id: membership.id)
    |> Repo.update()
  end

  @doc """
  Enrolls in a list of program workshops at once.

  Each workshop gets its own transaction, on purpose. A single transaction would
  hold N locks, and two people picking {A,B} and {B,A} at the same time would
  deadlock; worse, one seat running out would make the other enrollments vanish
  too. Whoever picked three and lost one wants the other two.

  Being already enrolled counts as success: the person asked to be there, and is.
  """
  @spec enroll_many(WorkshopProgram.t(), User.t(), [Ecto.UUID.t()]) ::
          {:ok, %{enrolled: [Workshop.t()], failed: [{Workshop.t(), atom()}]}}
          | {:error, :none_selected}
  def enroll_many(%WorkshopProgram{} = program, %User{} = user, workshop_ids) do
    case ProgramQuery.workshops_scoped(program.id, workshop_ids) do
      [] -> {:error, :none_selected}
      workshops -> {:ok, enroll_batch(program, user, workshops)}
    end
  end

  defp enroll_batch(program, user, workshops) do
    result =
      Enum.reduce(workshops, %{enrolled: [], failed: []}, fn workshop, acc ->
        accumulate(acc, workshop, enroll_one(workshop, user))
      end)

    notify_batch_organizers(result, program, user)
    %{result | enrolled: Enum.reverse(result.enrolled)}
  end

  defp enroll_one(workshop, user) do
    case admin?(workshop, user) do
      true -> {:error, :organizer}
      false -> workshop |> insert_enrollment_locked(user) |> handle_repeat()
    end
  end

  defp handle_repeat({:error, :already_enrolled}), do: {:ok, :was_already_in}
  defp handle_repeat(other), do: other

  defp accumulate(acc, workshop, {:ok, _}),
    do: %{acc | enrolled: [workshop | acc.enrolled]}

  defp accumulate(acc, workshop, {:error, reason}),
    do: %{acc | failed: acc.failed ++ [{workshop, reason}]}

  defp notify_batch_organizers(%{enrolled: []}, _program, _user), do: :ok

  defp notify_batch_organizers(%{enrolled: workshops}, program, user) do
    SafeDispatch.run(fn ->
      workshops
      |> batch_recipients(user)
      |> Enum.each(fn {organizer_id, workshop} ->
        Dispatcher.notify_program_enrollment(user.id, organizer_id, workshop.id, program.id)
      end)
    end)
  end

  # One notice per person, even when they organize several workshops of the batch:
  # three identical lines in the inbox is the spam a program exists to kill.
  defp batch_recipients(workshops, user) do
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

  @doc "Cancels one's own enrollment, freeing the seat."
  @spec cancel_enrollment(Workshop.t(), User.t()) ::
          {:ok, WorkshopEnrollment.t()} | {:error, :not_found}
  def cancel_enrollment(%Workshop{} = workshop, %User{id: user_id}) do
    case EnrollmentQuery.get_for_user(workshop.id, user_id) do
      nil -> {:error, :not_found}
      enrollment -> enrollment |> Repo.delete() |> promote_from_waitlist(workshop)
    end
  end

  # An open seat calls whoever waited longest. One person per seat: the waitlist
  # moves one step, it does not drain.
  defp promote_from_waitlist({:ok, _apagada} = result, workshop) do
    case WaitlistQuery.first_in_line(workshop.id) do
      nil -> result
      entry -> promote(entry, workshop, result)
    end
  end

  defp promote_from_waitlist(error, _workshop), do: error

  defp promote(entry, workshop, result) do
    with %User{} = pessoa <- Accounts.get_user_by_id(entry.user_id),
         {:ok, _enrollment} <- enroll_overbooking(workshop, pessoa) do
      Repo.delete(entry)
      notify_promotion(workshop, pessoa)
    end

    result
  end

  defp notify_promotion(workshop, pessoa) do
    SafeDispatch.run(fn ->
      Dispatcher.notify_waitlist_promoted(workshop.organizer_id, pessoa.id, workshop.id)
    end)
  end

  defdelegate list_waitlist(workshop_id), to: WaitlistQuery, as: :list_for_workshop
  defdelegate waitlist_count(workshop_id), to: WaitlistQuery, as: :count

  @doc "Where in the waitlist the person is, counting from 1. `nil` when not in it."
  @spec waitlist_position(Workshop.t(), User.t() | nil) :: pos_integer() | nil
  def waitlist_position(%Workshop{}, nil), do: nil

  def waitlist_position(%Workshop{} = workshop, %User{} = user),
    do: WaitlistQuery.position(workshop.id, user.id)

  @doc """
  Whether accepting one more person would exceed the capacity.

  It exists to warn the organizer before accepting, not to block: in a class with
  approval, fitting one more is the teacher's call.
  """
  @spec passaria_do_limite?(Workshop.t()) :: boolean()
  def passaria_do_limite?(%Workshop{} = workshop),
    do: Workshop.full?(workshop, EnrollmentQuery.count(workshop.id))

  @doc """
  Joins the waitlist of a full class.

  It only makes sense with the class full: with a seat left the person enrolls,
  and waiting would be worse for them.
  """
  @spec join_waitlist(Workshop.t(), User.t() | nil) ::
          {:ok, WaitlistEntry.t()}
          | {:error, :unauthorized | :has_room | :already_enrolled | :already_waiting}
  def join_waitlist(%Workshop{}, nil), do: {:error, :unauthorized}

  def join_waitlist(%Workshop{} = workshop, %User{} = user) do
    with :ok <- ensure_lotado(workshop),
         :ok <- ensure_not_enrolled(workshop, user) do
      insert_in_waitlist(workshop, user)
    end
  end

  defp ensure_lotado(workshop) do
    if passaria_do_limite?(workshop), do: :ok, else: {:error, :has_room}
  end

  defp ensure_not_enrolled(workshop, user) do
    case EnrollmentQuery.get_for_user(workshop.id, user.id) do
      nil -> :ok
      _ja_esta -> {:error, :already_enrolled}
    end
  end

  defp insert_in_waitlist(workshop, user) do
    %WaitlistEntry{}
    |> WaitlistEntry.changeset(%{workshop_id: workshop.id, user_id: user.id})
    |> Repo.insert()
    |> case do
      {:ok, entry} -> {:ok, entry}
      {:error, %Ecto.Changeset{}} -> {:error, :already_waiting}
    end
  end

  @doc "Leaves the waitlist."
  @spec leave_waitlist(Workshop.t(), User.t() | nil) ::
          {:ok, WaitlistEntry.t()} | {:error, :not_found}
  def leave_waitlist(%Workshop{}, nil), do: {:error, :not_found}

  def leave_waitlist(%Workshop{} = workshop, %User{} = user) do
    case WaitlistQuery.get(workshop.id, user.id) do
      nil -> {:error, :not_found}
      entry -> Repo.delete(entry)
    end
  end

  @doc """
  Enrollment list WITH payment. Organizer only.

  Whoever is covered by a package comes with `covered_by_package?`, the program
  title and `package_share_cents`, the slice of the package that belongs to this
  workshop. The payment state of those rows is the package's, not their own.
  """
  @spec list_enrollments_for_organizer(Workshop.t(), User.t()) ::
          {:ok, [map()]} | {:error, :unauthorized}
  def list_enrollments_for_organizer(%Workshop{} = workshop, %User{} = user) do
    with :ok <- ensure_admin(workshop, user) do
      {:ok, organizer_roster(workshop)}
    end
  end

  @doc """
  Payment summary (enrolled, paid, waived, and how much came in). Admins see it.

  `revenue_cents` adds the full price for whoever paid this workshop alone and
  only the package slice for whoever paid the set, so one payment never lands
  twice in the totals.
  """
  @spec payment_summary(Workshop.t(), User.t()) :: {:ok, map()} | {:error, :unauthorized}
  def payment_summary(%Workshop{} = workshop, %User{} = user) do
    with :ok <- ensure_admin(workshop, user) do
      {:ok, EnrollmentPayment.summarize(organizer_roster(workshop), workshop.price_cents)}
    end
  end

  defp organizer_roster(%Workshop{} = workshop) do
    rows = EnrollmentQuery.list_for_organizer(workshop.id)

    covered =
      rows |> EnrollmentPayment.package_ids() |> EnrollmentQuery.covered_workshops_by_package()

    EnrollmentPayment.enrich(rows, covered, workshop.id)
  end

  @doc """
  Marks the payment state of an enrollment.

  The enrollment is fetched scoped to the organizer's workshop, so a forged id
  from another event finds nothing.

  An enrollment covered by a package is refused: that payment already happened
  on the program, and marking it again here would count the same money twice.
  The refusal lives here, not only in the panel, because a hidden button is not
  a rule.
  """
  @spec set_payment_status(Workshop.t(), User.t(), Ecto.UUID.t(), atom()) ::
          {:ok, WorkshopEnrollment.t()}
          | {:error, :unauthorized | :not_found | :covered_by_package | Ecto.Changeset.t()}
  def set_payment_status(%Workshop{} = workshop, %User{} = user, enrollment_id, status)
      when status in [:pending, :paid, :waived] do
    with :ok <- ensure_admin(workshop, user),
         %WorkshopEnrollment{} = enrollment <-
           EnrollmentQuery.get_scoped(enrollment_id, workshop.id),
         :ok <- ensure_not_covered(enrollment) do
      enrollment |> WorkshopEnrollment.payment_changeset(status) |> Repo.update()
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def set_payment_status(%Workshop{}, %User{}, _enrollment_id, _status),
    do: {:error, :unauthorized}

  defp ensure_not_covered(%WorkshopEnrollment{program_enrollment_id: nil}), do: :ok
  defp ensure_not_covered(_enrollment), do: {:error, :covered_by_package}

  @doc """
  Attaches the receipt of whoever is enrolled in the workshop.

  Sending it again replaces the previous file: a receipt is the state of one
  payment, not a history of attempts.
  """
  @spec send_workshop_receipt(Workshop.t(), User.t(), Receipts.upload()) ::
          {:ok, WorkshopEnrollment.t()} | {:error, :not_enrolled | Receipts.reason()}
  def send_workshop_receipt(%Workshop{} = workshop, %User{} = user, upload) do
    with %WorkshopEnrollment{} = enrollment <-
           EnrollmentQuery.get_for_user(workshop.id, user.id),
         {:ok, updated} <- Receipts.attach(enrollment, receipt_folder(workshop), upload) do
      notify_receipt(workshop, user)
      {:ok, updated}
    else
      nil -> {:error, :not_enrolled}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Takes the receipt down. Whoever sent it, or whoever runs the workshop."
  @spec remove_workshop_receipt(Workshop.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, WorkshopEnrollment.t()} | {:error, :unauthorized | :not_found}
  def remove_workshop_receipt(%Workshop{} = workshop, %User{} = user, enrollment_id) do
    with %WorkshopEnrollment{} = enrollment <-
           EnrollmentQuery.get_scoped(enrollment_id, workshop.id),
         :ok <- Policy.authorize(:manage_receipt, user, {enrollment, access_for(workshop, user)}) do
      Receipts.detach(enrollment)
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Attaches the receipt of whoever bought the package of a program."
  @spec send_program_receipt(WorkshopProgram.t(), User.t(), Receipts.upload()) ::
          {:ok, ProgramEnrollment.t()} | {:error, :not_enrolled | Receipts.reason()}
  def send_program_receipt(%WorkshopProgram{} = program, %User{} = user, upload) do
    with %ProgramEnrollment{} = enrollment <- PackageQuery.get_for_user(program.id, user.id),
         {:ok, updated} <- Receipts.attach(enrollment, program_receipt_folder(program), upload) do
      notify_program_receipt(program, user)
      {:ok, updated}
    else
      nil -> {:error, :not_enrolled}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Takes the package receipt down. Whoever sent it, or whoever owns the program."
  @spec remove_program_receipt(WorkshopProgram.t(), User.t(), Ecto.UUID.t()) ::
          {:ok, ProgramEnrollment.t()} | {:error, :unauthorized | :not_found}
  def remove_program_receipt(%WorkshopProgram{} = program, %User{} = user, enrollment_id) do
    with %ProgramEnrollment{} = enrollment <- PackageQuery.get_scoped(enrollment_id, program.id),
         :ok <- Policy.authorize(:manage_receipt, user, {enrollment, program}) do
      Receipts.detach(enrollment)
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  What a person needs to know about their own receipt on this workshop.

  A projection, not the enrollment: `payment_status` is the organizer's business
  and does not leave the context on this path.
  """
  @spec my_receipt(Workshop.t(), User.t() | nil) ::
          %{enrollment_id: Ecto.UUID.t(), sent_at: DateTime.t() | nil} | nil
  def my_receipt(%Workshop{}, nil), do: nil

  def my_receipt(%Workshop{} = workshop, %User{} = user),
    do: workshop.id |> EnrollmentQuery.get_for_user(user.id) |> receipt_view()

  @doc "The same projection for whoever bought the package of a program."
  @spec my_package_receipt(WorkshopProgram.t(), User.t() | nil) ::
          %{enrollment_id: Ecto.UUID.t(), sent_at: DateTime.t() | nil} | nil
  def my_package_receipt(%WorkshopProgram{}, nil), do: nil

  def my_package_receipt(%WorkshopProgram{} = program, %User{} = user),
    do: program.id |> PackageQuery.get_for_user(user.id) |> receipt_view()

  defp receipt_view(nil), do: nil

  defp receipt_view(%{id: id, receipt_sent_at: sent_at}),
    do: %{enrollment_id: id, sent_at: sent_at}

  @doc """
  The workshop receipt of an enrollment, when this person may open it.

  Everything that is not a yes answers `:not_found`: a receipt someone may not
  see should not even confirm that it exists.
  """
  @spec fetch_workshop_receipt(Ecto.UUID.t(), User.t() | nil) ::
          {:ok, WorkshopEnrollment.t()} | {:error, :not_found}
  def fetch_workshop_receipt(enrollment_id, %User{} = user) do
    with %WorkshopEnrollment{receipt_key: key} = enrollment when is_binary(key) <-
           EnrollmentQuery.get(enrollment_id),
         %Workshop{} = workshop <- WorkshopQuery.get(enrollment.workshop_id),
         :ok <- Policy.authorize(:manage_receipt, user, {enrollment, access_for(workshop, user)}) do
      {:ok, enrollment}
    else
      _refused -> {:error, :not_found}
    end
  end

  def fetch_workshop_receipt(_enrollment_id, nil), do: {:error, :not_found}

  @doc "The package receipt of a membership, by the same rule."
  @spec fetch_program_receipt(Ecto.UUID.t(), User.t() | nil) ::
          {:ok, ProgramEnrollment.t()} | {:error, :not_found}
  def fetch_program_receipt(enrollment_id, %User{} = user) do
    with %ProgramEnrollment{receipt_key: key} = enrollment when is_binary(key) <-
           PackageQuery.get(enrollment_id),
         %WorkshopProgram{} = program <- ProgramQuery.get(enrollment.program_id),
         :ok <- Policy.authorize(:manage_receipt, user, {enrollment, program}) do
      {:ok, enrollment}
    else
      _refused -> {:error, :not_found}
    end
  end

  def fetch_program_receipt(_enrollment_id, nil), do: {:error, :not_found}

  @doc "How to serve a receipt file. Permission belongs to whoever calls."
  @spec serve_receipt(struct()) ::
          {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}
  defdelegate serve_receipt(enrollment), to: Receipts, as: :serve

  @doc """
  Records that this person opened WhatsApp to send the receipt.

  Only the first time counts: what is being measured is how many people take
  that path, not how many times they tapped the button.
  """
  @spec mark_whatsapp_receipt(Workshop.t(), User.t()) ::
          {:ok, WorkshopEnrollment.t()} | {:error, :not_enrolled}
  def mark_whatsapp_receipt(%Workshop{} = workshop, %User{} = user) do
    workshop.id |> EnrollmentQuery.get_for_user(user.id) |> stamp_whatsapp()
  end

  defp stamp_whatsapp(nil), do: {:error, :not_enrolled}

  defp stamp_whatsapp(%WorkshopEnrollment{whatsapp_opened_at: %DateTime{}} = enrollment),
    do: {:ok, enrollment}

  defp stamp_whatsapp(%WorkshopEnrollment{} = enrollment) do
    agora = DateTime.utc_now() |> DateTime.truncate(:second)

    enrollment |> Ecto.Changeset.change(whatsapp_opened_at: agora) |> Repo.update()
  end

  defdelegate receipt_summary(workshop_id), to: EnrollmentQuery

  defp receipt_folder(%Workshop{id: id}), do: "workshop_receipts/#{id}"
  defp program_receipt_folder(%WorkshopProgram{id: id}), do: "program_receipts/#{id}"

  defp notify_receipt(%Workshop{} = workshop, %User{} = user) do
    SafeDispatch.run(fn ->
      Dispatcher.notify_workshop_receipt(user.id, admin_ids(workshop), workshop.id)
    end)
  end

  defp notify_program_receipt(%WorkshopProgram{} = program, %User{} = user) do
    SafeDispatch.run(fn ->
      Dispatcher.notify_program_receipt(user.id, program.owner_id, program.id)
    end)
  end

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
