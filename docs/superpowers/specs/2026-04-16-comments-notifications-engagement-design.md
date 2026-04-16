# Comments + Notifications + Engagement Ranking — Design Spec

**Data:** 2026-04-16
**Status:** Approved — pronto para plano de implementação
**Sub-projeto:** A (da decomposição em `2026-04-16-comments-and-inline-expansion-decomposition.md`)
**Escopo expandido:** inclui notificações real-time e ranking por engajamento (originalmente separados)

---

## Resumo executivo

Transformar o Forrózin/OGrupoDeEstudos de um app de consulta em uma **rede social de dança** onde:

1. **Comentários** existem em 3 contextos: passos, sequências e perfis
2. **Nesting 1-nível** (Instagram-style): comentário raiz → respostas flat
3. **Likes como moeda social**: ordenam comments por engajamento, rankeiam steps/sequences na listagem de /community
4. **Notificações real-time**: PubSub push, badge animado, agrupamento Instagram-style, tela dedicada
5. **Performance-first**: denormalização via triggers, batch preloads, índices compostos, zero N+1

---

## 1. Schema de Dados

### 1.1 Tabelas de comments (3)

Cada tabela segue o mesmo padrão, com FK pro contexto específico.

#### `step_comments`

| Coluna | Tipo | Notas |
|--------|------|-------|
| id | binary_id | PK |
| body | text | max 2000 chars, NOT NULL |
| user_id | binary_id | FK `users`, NOT NULL, on_delete: :delete_all |
| step_id | binary_id | FK `steps`, NOT NULL, on_delete: :delete_all |
| parent_step_comment_id | binary_id | FK self-ref `step_comments`, nullable (NULL = raiz), on_delete: :nilify_all |
| like_count | integer | default 0, NOT NULL, denormalizado via trigger |
| reply_count | integer | default 0, NOT NULL, denormalizado via trigger |
| deleted_at | naive_datetime | nullable, pra tombstone |
| inserted_at / updated_at | timestamps | |

**Índices:**
- `(step_id, like_count DESC, inserted_at DESC) WHERE deleted_at IS NULL` — listagem por engagement
- `(parent_step_comment_id, inserted_at ASC) WHERE parent_step_comment_id IS NOT NULL` — replies de um parent
- `(user_id)` — "meus comentários"

#### `sequence_comments`

Idêntica a `step_comments`, trocando:
- `step_id` → `sequence_id` (FK `sequences`)
- `parent_step_comment_id` → `parent_sequence_comment_id` (FK self-ref `sequence_comments`)

**Mesmos índices**, com nomes adequados.

#### `profile_comments` (ALTER, não recriar)

Tabela já existe. Adicionar:

| Coluna nova | Tipo | Notas |
|-------------|------|-------|
| parent_profile_comment_id | binary_id | FK self-ref, nullable, on_delete: :nilify_all |
| like_count | integer | default 0, NOT NULL |
| reply_count | integer | default 0, NOT NULL |

Backfill de `like_count` com subquery dos likes existentes. `reply_count` = 0 (sem replies existentes).

**Novos índices:**
- `(parent_profile_comment_id)` — replies lookup
- `(profile_id, like_count DESC, inserted_at DESC) WHERE deleted_at IS NULL` — engagement sort

### 1.2 Tabela `notifications`

| Coluna | Tipo | Notas |
|--------|------|-------|
| id | binary_id | PK |
| user_id | binary_id | FK `users`, NOT NULL — quem recebe |
| actor_id | binary_id | FK `users`, NOT NULL — quem causou |
| action | string | enum: "liked_comment", "replied_comment", "liked_step", "liked_sequence" |
| group_key | string | ex: "comment:step_comment:uuid-123" — chave de agrupamento |
| target_type | string | "step_comment", "sequence_comment", "profile_comment", "step", "sequence" |
| target_id | binary_id | FK polimórfico (sem constraint DB, validado no app) |
| parent_type | string | "step", "sequence", "profile" — pra navegação |
| parent_id | binary_id | ID do step/sequence/profile pra onde navegar |
| read_at | naive_datetime | nullable, NULL = não lida |
| inserted_at | timestamp | |

**Índices:**
- `(user_id, read_at NULLS FIRST, inserted_at DESC)` — feed principal (unread first)
- `(user_id, group_key)` — agrupamento
- `(actor_id, target_type, target_id)` — dedup e cleanup

**Sem `updated_at`** — notificações são imutáveis exceto `read_at`.

### 1.3 Denormalização via triggers Postgres

#### Trigger: `like_count` em comments

Atualiza `like_count` na tabela correta quando um like é criado/deletado. O campo `likeable_type` do `likes` identifica a tabela alvo.

```sql
CREATE OR REPLACE FUNCTION update_comment_like_count() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.likeable_type = 'step_comment' THEN
      UPDATE step_comments SET like_count = like_count + 1 WHERE id = NEW.likeable_id;
    ELSIF NEW.likeable_type = 'sequence_comment' THEN
      UPDATE sequence_comments SET like_count = like_count + 1 WHERE id = NEW.likeable_id;
    ELSIF NEW.likeable_type = 'profile_comment' THEN
      UPDATE profile_comments SET like_count = like_count + 1 WHERE id = NEW.likeable_id;
    ELSIF NEW.likeable_type = 'step' THEN
      UPDATE steps SET like_count = like_count + 1 WHERE id = NEW.likeable_id;
    ELSIF NEW.likeable_type = 'sequence' THEN
      UPDATE sequences SET like_count = like_count + 1 WHERE id = NEW.likeable_id;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.likeable_type = 'step_comment' THEN
      UPDATE step_comments SET like_count = like_count - 1 WHERE id = OLD.likeable_id;
    ELSIF OLD.likeable_type = 'sequence_comment' THEN
      UPDATE sequence_comments SET like_count = like_count - 1 WHERE id = OLD.likeable_id;
    ELSIF OLD.likeable_type = 'profile_comment' THEN
      UPDATE profile_comments SET like_count = like_count - 1 WHERE id = OLD.likeable_id;
    ELSIF OLD.likeable_type = 'step' THEN
      UPDATE steps SET like_count = like_count - 1 WHERE id = OLD.likeable_id;
    ELSIF OLD.likeable_type = 'sequence' THEN
      UPDATE sequences SET like_count = like_count - 1 WHERE id = OLD.likeable_id;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER likes_update_count
  AFTER INSERT OR DELETE ON likes
  FOR EACH ROW EXECUTE FUNCTION update_comment_like_count();
```

#### Trigger: `reply_count` em comments

Incrementa/decrementa `reply_count` no parent comment quando reply é inserida/deletada.

```sql
-- step_comments
CREATE OR REPLACE FUNCTION update_step_comment_reply_count() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.parent_step_comment_id IS NOT NULL THEN
    UPDATE step_comments SET reply_count = reply_count + 1 WHERE id = NEW.parent_step_comment_id;
  ELSIF TG_OP = 'DELETE' AND OLD.parent_step_comment_id IS NOT NULL THEN
    UPDATE step_comments SET reply_count = reply_count - 1 WHERE id = OLD.parent_step_comment_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER step_comments_reply_count
  AFTER INSERT OR DELETE ON step_comments
  FOR EACH ROW EXECUTE FUNCTION update_step_comment_reply_count();
```

Triggers análogos para `sequence_comments` e `profile_comments`.

### 1.4 Alterações em tabelas existentes

#### `steps` — adicionar `like_count`

```elixir
alter table(:steps) do
  add :like_count, :integer, default: 0, null: false
end
```

Backfill com subquery dos likes existentes (tipo "step").

#### `sequences` — adicionar `like_count`

```elixir
alter table(:sequences) do
  add :like_count, :integer, default: 0, null: false
end
```

Backfill com subquery dos likes existentes (tipo "sequence").

#### `likes` — expandir tipos válidos

Changeset validation atualizada:

```elixir
@valid_types ~w(step sequence step_link profile_comment step_comment sequence_comment)
```

Nenhuma migration necessária — `likeable_type` é string livre no DB.

---

## 2. Arquitetura de Contextos

### 2.1 Estrutura de módulos

```
lib/o_grupo_de_estudos/engagement/
├── engagement.ex                    # API pública (expandida)
├── comments/
│   ├── commentable.ex               # Behaviour — contrato compartilhado
│   ├── step_comment.ex              # Schema
│   ├── step_comment_query.ex        # Query reducers
│   ├── sequence_comment.ex          # Schema
│   ├── sequence_comment_query.ex    # Query reducers
│   ├── profile_comment.ex           # Existente, modificado
│   └── profile_comment_query.ex     # Existente, expandido
├── like.ex                          # Existente (expandir @valid_types)
├── like_query.ex                    # Existente (sem mudança)
├── notifications/
│   ├── notification.ex              # Schema
│   ├── notification_query.ex        # Query reducers
│   ├── dispatcher.ex                # Cria notificações + PubSub broadcast
│   └── grouper.ex                   # Agrupa pra UI ("3 pessoas curtiram")
├── feedback.ex                      # Existente (intocado)
└── page_visit.ex                    # Existente (intocado)
```

### 2.2 Commentable Behaviour

Define contrato que os 3 query modules implementam:

```elixir
defmodule OGrupoDeEstudos.Engagement.Comments.Commentable do
  @doc "Query base da tabela"
  @callback base_query() :: Ecto.Query.t()

  @doc "Filtra por parent (step_id, sequence_id, ou profile_id)"
  @callback for_parent(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()

  @doc "Apenas comments raiz (parent_*_comment_id IS NULL)"
  @callback roots_only(Ecto.Query.t()) :: Ecto.Query.t()

  @doc "Replies de um comment específico"
  @callback replies_for(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()

  @doc "Ordenação por engajamento: like_count DESC, inserted_at DESC"
  @callback ordered_by_engagement(Ecto.Query.t()) :: Ecto.Query.t()

  @doc "O schema Ecto module (ex: StepComment)"
  @callback schema() :: module()

  @doc "Nome do campo FK pro parent (ex: :step_id)"
  @callback parent_field() :: atom()

  @doc "Nome do campo FK pro parent comment (ex: :parent_step_comment_id)"
  @callback parent_comment_field() :: atom()

  @doc "String do likeable_type (ex: \"step_comment\")"
  @callback likeable_type() :: String.t()
end
```

### 2.3 Lógica compartilhada no Engagement context

```elixir
defmodule OGrupoDeEstudos.Engagement do
  # ── Comments genérico (privado) ──────────────────────

  defp list_comments(query_mod, parent_id, opts) do
    query_mod.base_query()
    |> query_mod.for_parent(parent_id)
    |> query_mod.roots_only()
    |> query_mod.ordered_by_engagement()
    |> paginate(opts)
    |> Repo.all()
    |> preload_author()
  end

  defp create_comment(schema_mod, query_mod, user, parent_id, attrs) do
    parent_field = query_mod.parent_field()
    parent_comment_field = query_mod.parent_comment_field()

    changeset =
      struct(schema_mod)
      |> schema_mod.changeset(
        attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(parent_field, parent_id)
      )

    Multi.new()
    |> Multi.insert(:comment, changeset)
    |> Multi.run(:bump_reply_count, fn repo, %{comment: comment} ->
      parent_comment_id = Map.get(comment, parent_comment_field)
      if parent_comment_id do
        {1, _} = repo.update_all(
          from(c in schema_mod, where: c.id == ^parent_comment_id),
          inc: [reply_count: 1]
        )
        {:ok, :bumped}
      else
        {:ok, :root}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{comment: comment}} ->
        Dispatcher.notify(:new_comment, comment, user, query_mod)
        {:ok, Repo.preload(comment, :user)}
      {:error, :comment, changeset, _} ->
        {:error, changeset}
    end
  end

  defp delete_comment(schema_mod, query_mod, user, comment) do
    with :ok <- Authorization.Policy.authorize(:delete_comment, user, comment) do
      parent_comment_field = query_mod.parent_comment_field()

      if comment.reply_count == 0 do
        # Hard delete — sem replies, some completamente
        Multi.new()
        |> Multi.delete(:comment, comment)
        |> Multi.run(:decrement_parent, fn repo, _ ->
          parent_id = Map.get(comment, parent_comment_field)
          if parent_id do
            repo.update_all(
              from(c in schema_mod, where: c.id == ^parent_id),
              inc: [reply_count: -1]
            )
          end
          {:ok, :done}
        end)
        |> Repo.transaction()
        |> case do
          {:ok, _} -> {:ok, :deleted}
          {:error, _, reason, _} -> {:error, reason}
        end
      else
        # Tombstone — tem replies, preservar placeholder
        comment
        |> Ecto.Changeset.change(%{
          body: nil,
          deleted_at: NaiveDateTime.utc_now()
        })
        |> Repo.update()
        |> case do
          {:ok, comment} -> {:ok, comment}
          {:error, changeset} -> {:error, changeset}
        end
      end
    end
  end

  # ── API pública tipada ───────────────────────────────

  # Step comments
  def list_step_comments(step_id, opts \\ []),
    do: list_comments(StepCommentQuery, step_id, opts)

  def create_step_comment(user, step_id, attrs),
    do: create_comment(StepComment, StepCommentQuery, user, step_id, attrs)

  def delete_step_comment(user, comment),
    do: delete_comment(StepComment, StepCommentQuery, user, comment)

  # Sequence comments
  def list_sequence_comments(sequence_id, opts \\ []),
    do: list_comments(SequenceCommentQuery, sequence_id, opts)

  def create_sequence_comment(user, sequence_id, attrs),
    do: create_comment(SequenceComment, SequenceCommentQuery, user, sequence_id, attrs)

  def delete_sequence_comment(user, comment),
    do: delete_comment(SequenceComment, SequenceCommentQuery, user, comment)

  # Profile comments (existente, refatorar pra usar genérico)
  def list_profile_comments(profile_id, opts \\ []),
    do: list_comments(ProfileCommentQuery, profile_id, opts)

  def create_profile_comment(user, profile_id, attrs),
    do: create_comment(ProfileComment, ProfileCommentQuery, user, profile_id, attrs)

  def delete_profile_comment(user, comment),
    do: delete_comment(ProfileComment, ProfileCommentQuery, user, comment)

  # Replies (genérico pra qualquer tipo)
  def list_replies(query_mod, comment_id, opts \\ []) do
    query_mod.base_query()
    |> query_mod.replies_for(comment_id)
    |> query_mod.ordered_by_engagement()
    |> paginate(opts)
    |> Repo.all()
    |> preload_author()
  end

  # ── Likes (existente, expandir com dispatch de notificação) ──

  def toggle_like(user, likeable_type, likeable_id)
  # Após toggle, se liked: Dispatcher.notify(:new_like, likeable_type, likeable_id, user)
  def liked?(user_id, likeable_type, likeable_id)
  def count_likes(likeable_type, likeable_id)
  def likes_map(user_id, likeable_type, ids)

  # ── Notifications (novo) ─────────────────────────────

  def list_notifications(user_id, opts \\ [])
  def unread_count(user_id)
  def mark_as_read(user, notification_id)
  def mark_all_read(user)

  # ── Comment counts batch (pra preload em listagens) ──

  def comment_counts_for(type, parent_ids)
  # type: "step" | "sequence" | "profile"
  # Returns: %{uuid => count}
end
```

### 2.4 Authorization — expansão do Policy

```elixir
# Novas clauses no Policy existente:
def authorize(:delete_comment, %User{role: :admin}, _comment), do: :ok
def authorize(:delete_comment, %User{id: uid}, %{user_id: uid}), do: :ok
def authorize(:delete_comment, _, _), do: {:error, :unauthorized}

def authorize(:create_comment, %User{} = _user, _), do: :ok
def authorize(:create_comment, nil, _), do: {:error, :unauthenticated}
```

---

## 3. Notificações Real-Time

### 3.1 Fluxo completo

```
Ação (reply/like)
  → Engagement.create_*() / toggle_like()
    → Dispatcher.notify() [fora da Multi transaction]
      → Repo.insert_all(notifications)
      → PubSub.broadcast("notifications:#{user_id}", {:new_notification, count})
        → Todos LiveViews do user recebem handle_info
          → Badge atualiza instantaneamente
```

### 3.2 Dispatcher

```elixir
defmodule OGrupoDeEstudos.Engagement.Notifications.Dispatcher do
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias Phoenix.PubSub

  @pubsub OGrupoDeEstudos.PubSub

  def notify(:new_comment, comment, actor, query_mod) do
    recipients = determine_comment_recipients(comment, actor, query_mod)
    insert_and_broadcast(recipients, build_comment_notification(comment, actor, query_mod))
  end

  def notify(:new_like, likeable_type, likeable_id, actor) do
    recipients = determine_like_recipients(likeable_type, likeable_id, actor)
    insert_and_broadcast(recipients, build_like_notification(likeable_type, likeable_id, actor))
  end

  # ── Recipients ───────────────────────────────────────

  # Reply: notifica autor do parent comment (exceto self)
  # query_mod.schema() retorna o Ecto schema module (ex: StepComment)
  defp determine_comment_recipients(comment, actor, query_mod) do
    parent_field = query_mod.parent_comment_field()
    parent_id = Map.get(comment, parent_field)

    if parent_id do
      parent = Repo.get!(query_mod.schema(), parent_id)
      if parent.user_id != actor.id and parent.deleted_at == nil do
        [parent.user_id]
      else
        []
      end
    else
      []  # Root comment: ninguém recebe (sem follow por enquanto)
    end
  end

  # Like em comment: notifica autor do comment
  # Like em step/sequence: não notifica (sem owner concept robusto por ora)
  defp determine_like_recipients(likeable_type, likeable_id, actor)
      when likeable_type in ~w(step_comment sequence_comment profile_comment) do
    schema = schema_for_type(likeable_type)
    comment = Repo.get!(schema, likeable_id)
    if comment.user_id != actor.id and comment.deleted_at == nil do
      [comment.user_id]
    else
      []
    end
  end

  defp determine_like_recipients(_, _, _), do: []

  # ── Insert + Broadcast ──────────────────────────────

  defp insert_and_broadcast([], _), do: :ok
  defp insert_and_broadcast(recipients, notification_builder) do
    notifications = Enum.map(recipients, notification_builder)
    Repo.insert_all(Notification, notifications)

    Enum.each(recipients, fn user_id ->
      PubSub.broadcast(@pubsub, "notifications:#{user_id}", {:new_notification, 1})
    end)
  end
end
```

### 3.3 on_mount hook — subscribe ao conectar

```elixir
defmodule OGrupoDeEstudosWeb.Hooks.NotificationSubscriber do
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) && socket.assigns[:current_user] do
      user_id = socket.assigns.current_user.id
      Phoenix.PubSub.subscribe(OGrupoDeEstudos.PubSub, "notifications:#{user_id}")
      unread = OGrupoDeEstudos.Engagement.unread_count(user_id)
      {:cont, assign(socket, :notification_count, unread)}
    else
      {:cont, assign(socket, :notification_count, 0)}
    end
  end
end
```

Registrado em **todas as live_sessions autenticadas** no router.

### 3.4 handle_info compartilhado

```elixir
defmodule OGrupoDeEstudosWeb.NotificationHandlers do
  defmacro __using__(_) do
    quote do
      def handle_info({:new_notification, _count}, socket) do
        unread = OGrupoDeEstudos.Engagement.unread_count(socket.assigns.current_user.id)
        {:noreply, assign(socket, :notification_count, unread)}
      end

      def handle_info({:notifications_read, _}, socket) do
        {:noreply, assign(socket, :notification_count, 0)}
      end
    end
  end
end
```

Incluído em cada LiveView autenticado via `use OGrupoDeEstudosWeb.NotificationHandlers`.

### 3.5 Badge animado no header

Componente no layout de navegação:

```heex
<.link navigate={~p"/notifications"} class="relative group">
  <.icon name="hero-bell-solid" class={[
    "w-6 h-6 transition-colors",
    @notification_count > 0 && "text-accent-orange",
    @notification_count == 0 && "text-ink-400 group-hover:text-ink-600"
  ]} />
  <span :if={@notification_count > 0} class={[
    "absolute -top-1.5 -right-1.5 min-w-[20px] h-5 px-1",
    "flex items-center justify-center",
    "bg-accent-red text-white text-xs font-bold rounded-full",
    "animate-notification-pop"
  ]}>
    <%= if @notification_count > 99, do: "99+", else: @notification_count %>
  </span>
</.link>
```

CSS animation:

```css
@keyframes notification-pop {
  0% { transform: scale(0); opacity: 0; }
  50% { transform: scale(1.3); }
  100% { transform: scale(1); opacity: 1; }
}
.animate-notification-pop {
  animation: notification-pop 0.3s ease-out;
}
```

### 3.6 NotificationsLive — tela dedicada

Nova rota: `/notifications` (autenticada).

**Funcionalidades:**
- Lista paginada (20 por page, "Carregar mais" load_more)
- Agrupamento via `Grouper.group/1`: "Fulano e mais 2 curtiram seu comentário"
- Avatar stack (até 3 atores sobrepostos)
- Dot laranja pra unread, fundo dourado sutil `bg-gold-400/8`
- "Marcar tudo como lido" button
- Click em notificação: marca como lida + navega pra contexto (`/steps/:code#comments`, `/sequences/:id#comments`, `/users/:username#comments`)
- Sem notificações: empty state com ícone de sino + "Nenhuma notificação ainda"

### 3.7 Auto-cleanup via Oban

Job semanal (adicionar ao crontab existente):

```elixir
{"0 3 * * 0", OGrupoDeEstudos.Workers.NotificationCleanup}
```

Remove notificações **lidas** com mais de 90 dias. Não-lidas ficam indefinidamente.

---

## 4. UI Components

### 4.1 CommentThread — componente reutilizável

Usado em StepLive, SequenceLive (futuro), UserProfileLive. Recebe:

```elixir
attr :comments, :list, required: true        # root comments paginados
attr :current_user, :map, required: true
attr :likes_map, :map, required: true         # %{liked_ids: MapSet, counts: map}
attr :comment_type, :string, required: true   # "step_comment" | "sequence_comment" | "profile_comment"
attr :parent_id, :string, required: true      # step_id | sequence_id | profile_id
attr :replying_to, :string, default: nil      # comment_id que está com reply form aberto
attr :total_count, :integer, default: 0       # total de comments (pra "Ver todos")
```

### 4.2 Layout do comment

```
┌──────────────────────────────────────────────────┐
│ [Avatar 32px] @username · 2h                     │
│ Texto do comentário que pode ter                 │
│ várias linhas de conteúdo...                     │
│                                                  │
│ ♡ 12   💬 3 respostas   Responder                │
│                                                  │
│   ┌─ [Avatar 24px] @fulano · 1h                 │
│   │  Resposta ao comentário...                   │
│   │  ♡ 4   Responder                            │
│   │                                              │
│   ┌─ [Avatar 24px] @cicrana · 30min             │
│   │  Outra resposta...                           │
│   │  ♡ 1   Responder                            │
│   │                                              │
│   [Ver mais 2 respostas]                         │
│                                                  │
│ ┌────── [comentário removido] ──────┐            │
│ │  ♡ —   💬 1 resposta               │            │
│ │  ┌─ [Avatar] @alguem · 5min       │            │
│ │  │  Reply a um comment deletado    │            │
│ └────────────────────────────────────┘            │
│                                                  │
│ [Ver mais 5 comentários]                         │
└──────────────────────────────────────────────────┘
```

### 4.3 Like button

```heex
<button phx-click="toggle_like"
  phx-value-type={@comment_type}
  phx-value-id={@comment.id}
  class="flex items-center gap-1 text-sm group">
  <.icon
    name={if @liked?, do: "hero-heart-solid", else: "hero-heart"}
    class={[
      "w-5 h-5 transition-all duration-200",
      @liked? && "text-accent-red scale-110",
      !@liked? && "text-ink-400 group-hover:text-accent-red/60"
    ]}
  />
  <span class={[
    "tabular-nums",
    @liked? && "text-accent-red font-medium",
    !@liked? && "text-ink-400"
  ]}>
    <%= @comment.like_count %>
  </span>
</button>
```

### 4.4 Reply form inline

Aparece abaixo do comment ao clicar "Responder":

```heex
<form :if={@replying_to == comment.id}
  phx-submit="create_reply"
  phx-value-parent-id={comment.id}
  class="flex items-start gap-2 ml-10 mt-2">
  <img src={avatar_url(@current_user)} class="w-7 h-7 rounded-full flex-shrink-0" />
  <div class="flex-1 flex items-center gap-2 bg-ink-50 rounded-full px-3 py-1.5">
    <input name="body" placeholder="Responder..."
      class="flex-1 bg-transparent text-sm outline-none"
      phx-hook="AutoFocus" id={"reply-#{comment.id}"}
      maxlength="2000" required />
    <button type="submit" class="text-accent-orange font-semibold text-sm hover:text-accent-orange/80">
      Enviar
    </button>
  </div>
</form>
```

### 4.5 Tombstone (comment deletado com replies)

```heex
<div :if={@comment.deleted_at} class="flex items-center gap-2 py-2 px-3 bg-ink-50 rounded-lg">
  <.icon name="hero-trash" class="w-4 h-4 text-ink-300" />
  <span class="text-sm text-ink-400 italic">Comentário removido</span>
</div>
```

### 4.6 Create comment form (root)

Na base da seção de comments:

```heex
<form phx-submit="create_comment" class="flex items-start gap-2 mt-4 pt-4 border-t border-ink-100">
  <img src={avatar_url(@current_user)} class="w-8 h-8 rounded-full flex-shrink-0" />
  <div class="flex-1 flex items-center gap-2 bg-ink-50 rounded-full px-4 py-2">
    <input name="body" placeholder="Adicionar comentário..."
      class="flex-1 bg-transparent text-sm outline-none"
      maxlength="2000" required />
    <button type="submit" class="text-accent-orange font-semibold text-sm hover:text-accent-orange/80">
      Publicar
    </button>
  </div>
</form>
```

### 4.7 Notification item

```heex
<div class={[
  "flex items-start gap-3 px-4 py-3 border-b border-ink-100 transition-colors",
  !notif.read && "bg-gold-400/8"
]}>
  <%!-- Avatar stack (até 3) --%>
  <div class="relative flex-shrink-0 w-10 h-10">
    <img :for={{actor, i} <- Enum.take(notif.actors_data, 3) |> Enum.with_index()}
      src={actor.avatar_url || "/images/default-avatar.svg"}
      class={[
        "w-7 h-7 rounded-full border-2 border-white absolute",
        i == 0 && "top-0 left-0 z-20",
        i == 1 && "top-1 left-2 z-10",
        i == 2 && "top-2 left-4 z-0"
      ]}
    />
  </div>

  <.link navigate={notification_path(notif)} phx-click="mark_read" phx-value-id={notif.id}
    class="flex-1 min-w-0">
    <p class="text-sm text-ink-700">
      <span class="font-semibold"><%= primary_actor_name(notif) %></span>
      <span :if={notif.count > 1} class="text-ink-500">e mais <%= notif.count - 1 %></span>
      <span class="text-ink-600"><%= action_text(notif) %></span>
    </p>
    <p class="text-xs text-ink-400 mt-0.5"><%= time_ago(notif.latest_at) %></p>
  </.link>

  <div :if={!notif.read} class="w-2.5 h-2.5 rounded-full bg-accent-orange flex-shrink-0 mt-2" />
</div>
```

Textos de ação:
- `"liked_comment"` → "curtiu seu comentário"
- `"replied_comment"` → "respondeu ao seu comentário"
- `"liked_step"` → "curtiu o passo X"
- `"liked_sequence"` → "curtiu a sequência X"

---

## 5. Ranking por Engajamento em /community

### 5.1 Steps na listagem

Query de steps na community ordenada por `like_count DESC, inserted_at DESC`:

```elixir
def list_community_steps(opts \\ []) do
  from(s in Step,
    where: s.status == :published and s.wip == false and is_nil(s.deleted_at),
    order_by: [desc: s.like_count, desc: s.inserted_at]
  )
  |> paginate(opts)
  |> Repo.all()
end
```

Sem JOIN, sem GROUP BY. Index `steps_engagement_idx` resolve com index scan.

### 5.2 Like indicator nos cards

Badge sutil com coração no card do step na listagem:

```heex
<div :if={step.like_count > 0} class="flex items-center gap-1 text-xs text-accent-red/80">
  <.icon name="hero-heart-solid" class="w-3.5 h-3.5" />
  <span class="font-medium tabular-nums"><%= step.like_count %></span>
</div>
```

### 5.3 Sequences ranking

Mesma lógica: `sequences.like_count` denormalizado via trigger, ordenação na listagem "Sequências da comunidade".

---

## 6. Performance

### 6.1 Anti-N+1: batch preload

Para qualquer listagem de items (steps, sequences) com engagement data:

```elixir
# 1. Carregar items paginados (1 query)
steps = Encyclopedia.list_community_steps(page: 1, per_page: 20)
step_ids = Enum.map(steps, & &1.id)

# 2. Comment counts batch (1 query)
comment_counts = Engagement.comment_counts_for("step", step_ids)
# => %{"uuid-1" => 5, "uuid-2" => 0}

# 3. User likes batch (1 query)
user_likes = Engagement.likes_map(current_user.id, "step", step_ids)
# => %{liked_ids: MapSet<["uuid-1"]>, counts: %{"uuid-1" => 12}}
```

**Total: 3 queries** para qualquer N de items. Componentes recebem dados via assigns.

### 6.2 Paginação de comments

- **Root comments**: 10 por page, "Ver mais comentários" carrega +10 via `load_more_comments` event
- **Replies**: carregar até 3 por parent inicialmente, "Ver mais N respostas" carrega todas via `load_replies` event
- **Cursor**: `(like_count DESC, inserted_at DESC, id)` — estável com likes mudando (id como tiebreaker final)

### 6.3 Cache

| Dado | Estratégia | TTL |
|------|-----------|-----|
| `unread_count` | ETS cache, invalidado por PubSub broadcast | 30s |
| `likes_map` | Sem cache (query rápida com index, dados mudam frequentemente) | — |
| `comment_counts` | Computed no batch preload (1 query) | — |

### 6.4 Índices críticos

```sql
-- Comments: listagem por engagement (3 tabelas, padrão idêntico)
CREATE INDEX step_comments_engagement_idx
  ON step_comments (step_id, like_count DESC, inserted_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX sequence_comments_engagement_idx
  ON sequence_comments (sequence_id, like_count DESC, inserted_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX profile_comments_engagement_idx
  ON profile_comments (profile_id, like_count DESC, inserted_at DESC)
  WHERE deleted_at IS NULL;

-- Replies lookup (3 tabelas)
CREATE INDEX step_comments_parent_idx
  ON step_comments (parent_step_comment_id, inserted_at ASC)
  WHERE parent_step_comment_id IS NOT NULL;

CREATE INDEX sequence_comments_parent_idx
  ON sequence_comments (parent_sequence_comment_id, inserted_at ASC)
  WHERE parent_sequence_comment_id IS NOT NULL;

CREATE INDEX profile_comments_parent_idx
  ON profile_comments (parent_profile_comment_id, inserted_at ASC)
  WHERE parent_profile_comment_id IS NOT NULL;

-- Notifications feed
CREATE INDEX notifications_user_feed_idx
  ON notifications (user_id, read_at NULLS FIRST, inserted_at DESC);

-- Steps/Sequences ranking
CREATE INDEX steps_engagement_idx
  ON steps (like_count DESC, inserted_at DESC)
  WHERE status = 'published' AND wip = false;

CREATE INDEX sequences_engagement_idx
  ON sequences (like_count DESC, inserted_at DESC)
  WHERE deleted_at IS NULL;
```

---

## 7. Migration Strategy

### 7.1 Ordem das migrations

1. **Alter `steps`**: add `like_count` + backfill
2. **Alter `sequences`**: add `like_count` + backfill
3. **Alter `profile_comments`**: add `parent_profile_comment_id`, `like_count`, `reply_count` + backfill
4. **Create `step_comments`**: tabela nova + índices
5. **Create `sequence_comments`**: tabela nova + índices
6. **Create `notifications`**: tabela nova + índices
7. **Create triggers**: like_count + reply_count (todas tabelas)
8. **Add Oban cron job**: notification cleanup

### 7.2 profile_comments retrofit

```elixir
def change do
  alter table(:profile_comments) do
    add :parent_profile_comment_id, references(:profile_comments, type: :binary_id, on_delete: :nilify_all)
    add :like_count, :integer, default: 0, null: false
    add :reply_count, :integer, default: 0, null: false
  end

  create index(:profile_comments, [:parent_profile_comment_id])
  create index(:profile_comments, [:profile_id, :like_count, :inserted_at],
    name: :profile_comments_engagement_idx,
    where: "deleted_at IS NULL")

  # Backfill like_count
  execute("""
    UPDATE profile_comments pc
    SET like_count = COALESCE((
      SELECT COUNT(*) FROM likes
      WHERE likeable_type = 'profile_comment' AND likeable_id = pc.id
    ), 0)
  """, "")
end
```

### 7.3 Dados existentes

- Todos `profile_comments` existentes ficam com `parent_profile_comment_id = NULL` (raiz)
- `like_count` backfilled com contagem real dos likes existentes
- `reply_count` = 0 (sem replies existentes)
- Zero data loss, zero downtime

### 7.4 likes — expandir tipos aceitos

Apenas mudança no changeset validation (nenhuma migration necessária):

```elixir
@valid_types ~w(step sequence step_link profile_comment step_comment sequence_comment)
```

---

## 8. Decisões de Design Resumidas

| # | Decisão | Escolha | Razão |
|---|---------|---------|-------|
| 1 | Schema | Multi-tabela (step/sequence/profile_comments) | Queries diretas, sem WHERE type, FK real |
| 2 | Nesting | 1 nível (Instagram flat) | Conversas curtas/didáticas, mobile-friendly |
| 3 | Delete | Híbrido (sem replies → hard, com replies → tombstone) | Rede limpa + preserva contexto |
| 4 | Ordenação | Engagement-based (like_count DESC) | Likes como moeda social, incentivar cultura |
| 5 | Moderação | Estrita (self + admin) | Simples, seguro, extensível depois |
| 6 | Notificações | Real-time completo (PubSub + badge + agrupamento) | Engajamento depende de feedback loop |
| 7 | Ranking | like_count denormalizado + triggers | Performance, zero JOIN em listagens |

---

## 9. Fora de escopo (deferido)

- **Sub-projeto B**: Inline expansion no /collection (expandir comments/links sem navegar)
- **Sub-projeto C**: Audit de performance geral
- **Follow/subscribe**: seguir um step/sequence pra receber notificações de novos comments
- **Reports/flags**: denúncia de comments inapropriados
- **Moderação contextual**: owner do step modera comments no seu step
- **Notificação por email**: apenas in-app por enquanto
- **Rich text comments**: apenas texto plano por enquanto
- **Mentions (@user)**: expansão futura natural
