defmodule OGrupoDeEstudos.Engagement.Notifications.Dispatcher do
  @moduledoc """
  Creates notification records and broadcasts via PubSub.

  Called from Engagement context OUTSIDE Ecto.Multi transactions,
  wrapped in try/rescue so notification failures never break CRUD.

  Admin users receive a copy of ALL notifications.
  """

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Engagement.Comments
  alias OGrupoDeEstudos.Engagement.Comments.WorkshopCommentQuery
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Sequences
  alias OGrupoDeEstudos.Workshops
  alias Phoenix.PubSub

  @pubsub OGrupoDeEstudos.PubSub

  # ── Comment notifications ──────────────────────────────

  @doc """
  Dispatches notification when a comment is created.

  Resposta avisa o autor do comentario pai. Comentario raiz so avisa alguem em
  workshop, onde existe um dono da pagina para avisar; passo, sequencia e
  perfil seguem sem notificacao de raiz.
  """
  def notify(:new_comment, comment, actor, query_mod) do
    {recipients, action, group_key} = comment_context(comment, actor, query_mod)
    parent_id = Map.get(comment, query_mod.parent_field())

    builder = fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: actor.id,
        action: action,
        group_key: group_key,
        target_type: query_mod.likeable_type(),
        target_id: comment.id,
        parent_type: parent_type_from(query_mod),
        parent_id: parent_id,
        inserted_at: now()
      }
    end

    recipients
    |> add_admin_recipients(actor.id)
    |> insert_and_broadcast(builder)
  end

  @doc """
  Avisa o organizador de que alguem se inscreveu no workshop.

  Sem copia para admin: um workshop de 100 pessoas geraria 100 x N_admins
  linhas. O `group_key` por workshop faz o Grouper colapsar as inscricoes em
  uma entrada so ("Fulano e mais 99 se inscreveram").
  """
  @spec notify_workshop_enrollment(Ecto.UUID.t(), [Ecto.UUID.t()], Ecto.UUID.t()) :: :ok
  def notify_workshop_enrollment(actor_id, organizer_ids, workshop_id)
      when is_list(organizer_ids) do
    builder = fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: actor_id,
        action: :workshop_enrolled,
        group_key: "workshop_enrolled:#{workshop_id}",
        target_type: "workshop",
        target_id: workshop_id,
        parent_type: "workshop",
        parent_id: workshop_id,
        inserted_at: now()
      }
    end

    organizer_ids
    |> Enum.reject(&(&1 == actor_id))
    |> insert_and_broadcast(builder)
  end

  @doc """
  Avisa um organizador de que alguem se inscreveu em workshops de uma
  programacao.

  O `group_key` e da programacao, nao do workshop: inscrever em tres de uma vez
  vira uma linha so na caixa de quem organiza, em vez de tres que nem colapsam.
  """
  @spec notify_program_enrollment(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          :ok
  def notify_program_enrollment(actor_id, organizer_id, workshop_id, program_id)
      when actor_id != organizer_id do
    builder = fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: actor_id,
        action: :workshop_enrolled,
        group_key: "workshop_enrolled:program:#{program_id}",
        target_type: "workshop",
        target_id: workshop_id,
        parent_type: "workshop",
        parent_id: workshop_id,
        inserted_at: now()
      }
    end

    insert_and_broadcast([organizer_id], builder)
  end

  def notify_program_enrollment(_actor_id, _organizer_id, _workshop_id, _program_id), do: :ok

  @doc "Avisa quem organiza que alguem pediu para entrar no workshop privado."
  @spec notify_workshop_join_request(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) :: :ok
  def notify_workshop_join_request(actor_id, organizer_id, workshop_id)
      when actor_id != organizer_id do
    avisar_sobre_pedido(actor_id, organizer_id, workshop_id, :workshop_join_requested)
  end

  def notify_workshop_join_request(_actor_id, _organizer_id, _workshop_id), do: :ok

  @doc "Avisa quem pediu que o pedido foi respondido."
  @spec notify_workshop_join_review(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), atom()) :: :ok
  def notify_workshop_join_review(actor_id, user_id, workshop_id, acao)
      when actor_id != user_id do
    avisar_sobre_pedido(actor_id, user_id, workshop_id, acao)
  end

  def notify_workshop_join_review(_actor_id, _user_id, _workshop_id, _acao), do: :ok

  @doc "Avisa que abriu vaga e a pessoa saiu da fila direto para a turma."
  @spec notify_waitlist_promoted(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) :: :ok
  def notify_waitlist_promoted(actor_id, user_id, workshop_id) when actor_id != user_id do
    avisar_sobre_pedido(actor_id, user_id, workshop_id, :workshop_waitlist_promoted)
  end

  def notify_waitlist_promoted(_actor_id, _user_id, _workshop_id), do: :ok

  defp avisar_sobre_pedido(actor_id, destinatario_id, workshop_id, acao) do
    builder = fn destinatario ->
      %{
        id: Ecto.UUID.generate(),
        user_id: destinatario,
        actor_id: actor_id,
        action: acao,
        group_key: "#{acao}:#{workshop_id}",
        target_type: "workshop",
        target_id: workshop_id,
        parent_type: "workshop",
        parent_id: workshop_id,
        inserted_at: now()
      }
    end

    insert_and_broadcast([destinatario_id], builder)
  end

  @doc """
  Avisa alguem de que tem workshop amanha.

  O ator e o organizador: a notificacao exige actor_id, e "Tavano: amanha tem
  workshop com voce" le natural.
  """
  @spec notify_workshop_reminder(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) :: :ok
  def notify_workshop_reminder(organizer_id, user_id, workshop_id) do
    builder = fn destinatario ->
      %{
        id: Ecto.UUID.generate(),
        user_id: destinatario,
        actor_id: organizer_id,
        action: :workshop_reminder,
        group_key: "workshop_reminder:#{workshop_id}",
        target_type: "workshop",
        target_id: workshop_id,
        parent_type: "workshop",
        parent_id: workshop_id,
        inserted_at: now()
      }
    end

    insert_and_broadcast([user_id], builder)
  end

  # ── Like notifications ─────────────────────────────────

  @doc """
  Dispatches notification when a like is created.

  Recipients:
  - Like on comment → comment author
  - Like on step (community) → step's suggested_by user
  - Like on sequence → sequence owner
  - Admin always gets a copy
  """
  def notify_like(actor_id, likeable_type, likeable_id) do
    {recipients, action, target_type, parent_type, parent_id} =
      determine_like_context(actor_id, likeable_type, likeable_id)

    builder = fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: actor_id,
        action: action,
        group_key: "like:#{likeable_type}:#{likeable_id}",
        target_type: target_type,
        target_id: likeable_id,
        parent_type: parent_type,
        parent_id: parent_id,
        inserted_at: now()
      }
    end

    all_recipients = add_admin_recipients(recipients, actor_id)
    insert_and_broadcast(all_recipients, builder)
  end

  @doc "Dispatches a notification when one user starts following another."
  def notify_follow(follower_id, followed_id) when follower_id != followed_id do
    insert_and_broadcast([followed_id], fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: follower_id,
        action: :followed_user,
        group_key: "follow:#{followed_id}",
        target_type: "profile",
        target_id: follower_id,
        parent_type: "profile",
        parent_id: follower_id,
        inserted_at: now()
      }
    end)
  end

  def notify_follow(_follower_id, _followed_id), do: :ok

  # ── Study request notifications ────────────────────────

  @doc "Notifies the recipient that someone wants to study with them."
  def notify_study_request(initiator_id, recipient_id, link_id) do
    insert_and_broadcast([recipient_id], fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: initiator_id,
        action: :study_request,
        group_key: "study_request:#{link_id}",
        target_type: "study_link",
        target_id: link_id,
        parent_type: "study_link",
        parent_id: link_id,
        inserted_at: now()
      }
    end)
  end

  @doc "Notifies student that teacher accepted their study request."
  def notify_study_accepted(teacher_id, student_id, link_id) do
    insert_and_broadcast([student_id], fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: teacher_id,
        action: :study_accepted,
        group_key: "study_accepted:#{link_id}",
        target_type: "study_link",
        target_id: link_id,
        parent_type: "study_link",
        parent_id: link_id,
        inserted_at: now()
      }
    end)
  end

  @doc "Teacher sends a gentle reminder to an inactive student."
  def notify_nudge(teacher, student_id, link_id) do
    insert_and_broadcast([student_id], fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: teacher.id,
        action: :study_nudge,
        group_key: "nudge:#{link_id}:#{Date.utc_today()}",
        target_type: "study_link",
        target_id: link_id,
        parent_type: "study_link",
        parent_id: link_id,
        inserted_at: now()
      }
    end)
  end

  @doc "Notifica o aluno quando o professor compartilha uma lição no vínculo."
  def notify_lesson(teacher_id, student_id, link_id, lesson_id) do
    insert_and_broadcast([student_id], fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: teacher_id,
        action: :lesson_shared,
        group_key: "lesson:#{lesson_id}:#{link_id}",
        target_type: "lesson",
        target_id: lesson_id,
        parent_type: "study_link",
        parent_id: link_id,
        inserted_at: now()
      }
    end)
  end

  @doc "Notifies the student when their teacher writes in the shared diary."
  def notify_shared_note(teacher, student_id, link_id) do
    insert_and_broadcast([student_id], fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: teacher.id,
        action: :shared_note_updated,
        group_key: "shared_note:#{link_id}:#{Date.utc_today()}",
        target_type: "study_link",
        target_id: link_id,
        parent_type: "study_link",
        parent_id: link_id,
        inserted_at: now()
      }
    end)
  end

  # ── Private: recipient determination ───────────────────

  defp comment_context(comment, actor, query_mod) do
    case Map.get(comment, query_mod.parent_comment_field()) do
      nil -> root_comment_context(comment, actor, query_mod)
      parent_comment_id -> reply_context(parent_comment_id, actor, query_mod)
    end
  end

  # Raiz em workshop: quem recebe e o organizador, e o agrupamento e por
  # workshop, para varios comentarios virarem uma linha so.
  defp root_comment_context(comment, actor, WorkshopCommentQuery) do
    {workshop_organizer_recipients(comment.workshop_id, actor.id), :workshop_commented,
     "workshop_comment:#{comment.workshop_id}"}
  end

  defp root_comment_context(comment, _actor, query_mod),
    do: {[], :replied_comment, "comment:#{query_mod.likeable_type()}:#{comment.id}"}

  defp reply_context(parent_comment_id, actor, query_mod) do
    parent = Repo.get(query_mod.schema(), parent_comment_id)
    user_field = query_mod.user_field()

    {comment_author_recipients(parent, user_field, Map.get(actor, :id)), :replied_comment,
     "comment:#{query_mod.likeable_type()}:#{parent_comment_id}"}
  end

  defp workshop_organizer_recipients(workshop_id, actor_id) do
    case Workshops.organizer_id(workshop_id) do
      nil -> []
      ^actor_id -> []
      organizer_id -> [organizer_id]
    end
  end

  defp determine_like_context(actor_id, "step_comment", comment_id) do
    comment = Comments.get_step_comment(comment_id)
    recipients = comment_author_recipients(comment, :user_id, actor_id)
    {recipients, :liked_comment, "step_comment", "step", comment && comment.step_id}
  end

  defp determine_like_context(actor_id, "sequence_comment", comment_id) do
    comment = Comments.get_sequence_comment(comment_id)
    recipients = comment_author_recipients(comment, :user_id, actor_id)
    {recipients, :liked_comment, "sequence_comment", "sequence", comment && comment.sequence_id}
  end

  defp determine_like_context(actor_id, "profile_comment", comment_id) do
    comment = Comments.get_profile_comment(comment_id)
    recipients = comment_author_recipients(comment, :author_id, actor_id)
    {recipients, :liked_comment, "profile_comment", "profile", comment && comment.profile_id}
  end

  defp determine_like_context(actor_id, "workshop_comment", comment_id) do
    comment = Comments.get_workshop_comment(comment_id)
    recipients = comment_author_recipients(comment, :user_id, actor_id)
    {recipients, :liked_comment, "workshop_comment", "workshop", comment && comment.workshop_id}
  end

  defp determine_like_context(actor_id, "workshop", workshop_id) do
    recipients = workshop_organizer_recipients(workshop_id, actor_id)
    {recipients, :liked_workshop, "workshop", "workshop", workshop_id}
  end

  defp determine_like_context(actor_id, "step", step_id) do
    # Notify step creator if it's a community step
    recipients =
      case Encyclopedia.steps_by_ids([step_id]) do
        %{^step_id => %{suggested_by_id: suggester_id}}
        when not is_nil(suggester_id) and suggester_id != actor_id ->
          [suggester_id]

        _ ->
          []
      end

    {recipients, :liked_step, "step", "step", step_id}
  end

  defp determine_like_context(actor_id, "sequence", sequence_id) do
    recipients =
      case Sequences.sequence_owner_id(sequence_id) do
        nil -> []
        ^actor_id -> []
        owner_id -> [owner_id]
      end

    {recipients, :liked_sequence, "sequence", "sequence", sequence_id}
  end

  defp determine_like_context(_actor_id, _type, _id) do
    {[], :liked_comment, "step_comment", "step", nil}
  end

  # ── Private: admin broadcast ───────────────────────────

  defp add_admin_recipients(recipients, actor_id) do
    # Add admins that aren't already recipients and aren't the actor
    extra_admins =
      Accounts.list_admin_ids()
      |> Enum.reject(fn id -> id == actor_id || id in recipients end)

    Enum.uniq(recipients ++ extra_admins)
  end

  defp comment_author_recipients(nil, _author_field, _actor_id), do: []

  defp comment_author_recipients(comment, author_field, actor_id) do
    author_id = Map.get(comment, author_field)

    if author_id != actor_id and is_nil(comment.deleted_at), do: [author_id], else: []
  end

  # ── Private: insert + broadcast ────────────────────────

  defp insert_and_broadcast([], _builder), do: :ok

  defp insert_and_broadcast(recipients, builder) do
    notifications = Enum.map(recipients, builder)
    Repo.insert_all(Notification, notifications)

    Enum.each(recipients, fn user_id ->
      PubSub.broadcast(@pubsub, "notifications:#{user_id}", {:new_notification, 1})
    end)
  end

  # ── Helpers ────────────────────────────────────────────

  defp parent_type_from(query_mod) do
    case query_mod.parent_field() do
      :step_id -> "step"
      :sequence_id -> "sequence"
      :profile_id -> "profile"
      :workshop_id -> "workshop"
    end
  end

  # ── Suggestion notifications ───────────────────────────────

  @doc """
  Notifies all admins that a new suggestion was submitted.
  The suggestion author is excluded from receiving the notification.
  """
  def notify_suggestion(:suggestion_created, suggestion) do
    recipients = Accounts.list_admin_ids() -- [suggestion.user_id]

    insert_and_broadcast(recipients, fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: suggestion.user_id,
        action: :suggestion_created,
        group_key: "suggestion:#{suggestion.id}",
        target_type: "suggestion",
        target_id: suggestion.id,
        parent_type: Atom.to_string(suggestion.target_type),
        parent_id: suggestion.target_id,
        inserted_at: now()
      }
    end)
  end

  @doc """
  Dispatches a notification to the suggestion author when an admin reviews it.

  Sends `suggestion_approved` or `suggestion_rejected` based on `suggestion.status`.
  The admin never receives their own notification (excluded from recipients).
  """
  def notify_suggestion(:suggestion_reviewed, suggestion, admin) do
    action =
      case suggestion.status do
        :approved -> :suggestion_approved
        :rejected -> :suggestion_rejected
        _ -> nil
      end

    if action do
      recipients = [suggestion.user_id] -- [admin.id]

      insert_and_broadcast(recipients, fn user_id ->
        %{
          id: Ecto.UUID.generate(),
          user_id: user_id,
          actor_id: admin.id,
          action: action,
          group_key: "suggestion:#{suggestion.id}",
          target_type: "suggestion",
          target_id: suggestion.id,
          parent_type: Atom.to_string(suggestion.target_type),
          parent_id: suggestion.target_id,
          inserted_at: now()
        }
      end)
    else
      :ok
    end
  end

  defp now, do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
end
