# Comments + Notifications + Engagement Ranking — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform OGrupoDeEstudos into a social network with nested comments on steps/sequences/profiles, real-time notifications via PubSub, and engagement-based ranking.

**Architecture:** Multi-table comments (step_comments, sequence_comments, profile_comments) with 1-level nesting, Commentable behaviour for shared query logic, Postgres triggers for like_count/reply_count denormalization, PubSub-driven notification badge updates, and Oban cleanup jobs.

**Tech Stack:** Phoenix 1.7, LiveView 1.0+, Ecto 3.10, PostgreSQL 17 (Neon), Oban 2.17, Tailwind v4, PubSub

**Spec:** `docs/superpowers/specs/2026-04-16-comments-notifications-engagement-design.md`

---

## File Structure

### Create

| File | Responsibility |
|------|---------------|
| `priv/repo/migrations/TIMESTAMP_add_like_count_to_steps_and_sequences.exs` | Add `like_count` column to steps + sequences + backfill |
| `priv/repo/migrations/TIMESTAMP_add_nesting_to_profile_comments.exs` | Add parent_id, like_count, reply_count to profile_comments + backfill |
| `priv/repo/migrations/TIMESTAMP_create_step_comments.exs` | New step_comments table + indices |
| `priv/repo/migrations/TIMESTAMP_create_sequence_comments.exs` | New sequence_comments table + indices |
| `priv/repo/migrations/TIMESTAMP_create_notifications.exs` | New notifications table + indices |
| `priv/repo/migrations/TIMESTAMP_create_engagement_triggers.exs` | Postgres triggers for like_count + reply_count |
| `lib/o_grupo_de_estudos/engagement/comments/commentable.ex` | Behaviour: shared query contract for all comment types |
| `lib/o_grupo_de_estudos/engagement/comments/step_comment.ex` | Ecto schema for step_comments |
| `lib/o_grupo_de_estudos/engagement/comments/step_comment_query.ex` | Query reducers implementing Commentable |
| `lib/o_grupo_de_estudos/engagement/comments/sequence_comment.ex` | Ecto schema for sequence_comments |
| `lib/o_grupo_de_estudos/engagement/comments/sequence_comment_query.ex` | Query reducers implementing Commentable |
| `lib/o_grupo_de_estudos/engagement/notifications/notification.ex` | Ecto schema for notifications |
| `lib/o_grupo_de_estudos/engagement/notifications/notification_query.ex` | Query reducers for notifications |
| `lib/o_grupo_de_estudos/engagement/notifications/dispatcher.ex` | Create notifications + PubSub broadcast |
| `lib/o_grupo_de_estudos/engagement/notifications/grouper.ex` | Group notifications for Instagram-style display |
| `lib/o_grupo_de_estudos/authorization/policy.ex` | Centralized authorization (delete_comment, create_comment) |
| `lib/o_grupo_de_estudos_web/hooks/notification_subscriber.ex` | on_mount hook: subscribe to PubSub + load unread_count |
| `lib/o_grupo_de_estudos_web/notification_handlers.ex` | Macro: shared handle_info for notification updates |
| `lib/o_grupo_de_estudos_web/components/ui/comment_thread.ex` | Reusable comment thread component |
| `lib/o_grupo_de_estudos_web/live/notifications_live.ex` | LiveView: dedicated notifications page |
| `lib/o_grupo_de_estudos_web/live/notifications_live.html.heex` | Template: notifications page |
| `lib/o_grupo_de_estudos/workers/notification_cleanup.ex` | Oban worker: purge old read notifications |
| `test/o_grupo_de_estudos/engagement/comments/step_comment_query_test.exs` | Tests for StepCommentQuery |
| `test/o_grupo_de_estudos/engagement/comments/sequence_comment_query_test.exs` | Tests for SequenceCommentQuery |
| `test/o_grupo_de_estudos/engagement/notifications/dispatcher_test.exs` | Tests for Dispatcher |
| `test/o_grupo_de_estudos/engagement/notifications/grouper_test.exs` | Tests for Grouper |
| `test/o_grupo_de_estudos/authorization/policy_test.exs` | Tests for Policy |

### Modify

| File | Change |
|------|--------|
| `lib/o_grupo_de_estudos/encyclopedia/step.ex` | Add `like_count` field |
| `lib/o_grupo_de_estudos/sequences/sequence.ex` | Add `like_count` field |
| `lib/o_grupo_de_estudos/engagement/like.ex` | Expand `@valid_types` |
| `lib/o_grupo_de_estudos/engagement/profile_comment.ex` | Add parent_id, like_count, reply_count fields |
| `lib/o_grupo_de_estudos/engagement/profile_comment_query.ex` | Implement Commentable behaviour |
| `lib/o_grupo_de_estudos/engagement.ex` | Add generic comment CRUD + notifications API + comment_counts_for |
| `lib/o_grupo_de_estudos_web/router.ex` | Add `/notifications` route |
| `lib/o_grupo_de_estudos_web/components/ui/top_nav.ex` | Add notification bell badge |
| `lib/o_grupo_de_estudos_web/components/ui/bottom_nav.ex` | Add notification bell tab |
| `lib/o_grupo_de_estudos_web/live/step_live.ex` | Add comments section |
| `lib/o_grupo_de_estudos_web/live/step_live.html.heex` | Render CommentThread |
| `lib/o_grupo_de_estudos_web/live/user_profile_live.ex` | Refactor to use generic comments |
| `lib/o_grupo_de_estudos_web/live/user_profile_live.html.heex` | Use CommentThread component |
| `lib/o_grupo_de_estudos_web/live/community_live.ex` | Sort by like_count |
| `lib/o_grupo_de_estudos_web/live/community_live.html.heex` | Show like_count badge |
| `config/config.exs` | Add maintenance queue + notification cleanup cron |
| `assets/css/app.css` | Add notification-pop animation |
| `test/support/factory.ex` | Add step_comment, sequence_comment, notification factories |
| `test/o_grupo_de_estudos/engagement_test.exs` | Add comment CRUD + notification tests |

---

### Task 1: Migrations — like_count on steps + sequences

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_like_count_to_steps_and_sequences.exs`

- [ ] **Step 1: Create the migration**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.gen.migration add_like_count_to_steps_and_sequences
```

- [ ] **Step 2: Write the migration**

Open the generated file and replace contents with:

```elixir
defmodule OGrupoDeEstudos.Repo.Migrations.AddLikeCountToStepsAndSequences do
  use Ecto.Migration

  def change do
    alter table(:steps) do
      add :like_count, :integer, default: 0, null: false
    end

    alter table(:sequences) do
      add :like_count, :integer, default: 0, null: false
    end

    # Backfill steps like_count from existing likes
    execute(
      """
      UPDATE steps s
      SET like_count = COALESCE((
        SELECT COUNT(*) FROM likes
        WHERE likeable_type = 'step' AND likeable_id = s.id
      ), 0)
      """,
      ""
    )

    # Backfill sequences like_count from existing likes
    execute(
      """
      UPDATE sequences s
      SET like_count = COALESCE((
        SELECT COUNT(*) FROM likes
        WHERE likeable_type = 'sequence' AND likeable_id = s.id
      ), 0)
      """,
      ""
    )

    # Index for community ranking
    create index(:steps, ["like_count DESC", "inserted_at DESC"],
      name: :steps_engagement_idx,
      where: "status = 'published' AND wip = false"
    )

    create index(:sequences, ["like_count DESC", "inserted_at DESC"],
      name: :sequences_engagement_idx,
      where: "deleted_at IS NULL"
    )
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.migrate
```

Expected: Migration runs successfully, 0 errors.

- [ ] **Step 4: Update Step schema**

In `lib/o_grupo_de_estudos/encyclopedia/step.ex`, add `like_count` field to the schema and optional fields:

Add to the schema block after `field :deleted_at, :naive_datetime`:
```elixir
field :like_count, :integer, default: 0
```

Add `:like_count` to `@optional_fields`.

- [ ] **Step 5: Update Sequence schema**

In `lib/o_grupo_de_estudos/sequences/sequence.ex`, add to schema after `field :deleted_at, :naive_datetime`:
```elixir
field :like_count, :integer, default: 0
```

Add `:like_count` to the cast list in changeset.

- [ ] **Step 6: Run tests**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test
```

Expected: All existing tests pass (no regressions).

- [ ] **Step 7: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add priv/repo/migrations/*like_count* lib/o_grupo_de_estudos/encyclopedia/step.ex lib/o_grupo_de_estudos/sequences/sequence.ex && git commit -m "feat: add like_count to steps and sequences with backfill"
```

---

### Task 2: Migrations — nesting on profile_comments

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_nesting_to_profile_comments.exs`
- Modify: `lib/o_grupo_de_estudos/engagement/profile_comment.ex`

- [ ] **Step 1: Create the migration**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.gen.migration add_nesting_to_profile_comments
```

- [ ] **Step 2: Write the migration**

```elixir
defmodule OGrupoDeEstudos.Repo.Migrations.AddNestingToProfileComments do
  use Ecto.Migration

  def change do
    alter table(:profile_comments) do
      add :parent_profile_comment_id,
        references(:profile_comments, type: :binary_id, on_delete: :nilify_all)

      add :like_count, :integer, default: 0, null: false
      add :reply_count, :integer, default: 0, null: false
    end

    create index(:profile_comments, [:parent_profile_comment_id])

    create index(:profile_comments, ["like_count DESC", "inserted_at DESC"],
      name: :profile_comments_engagement_idx,
      where: "deleted_at IS NULL"
    )

    # Backfill like_count from existing likes
    execute(
      """
      UPDATE profile_comments pc
      SET like_count = COALESCE((
        SELECT COUNT(*) FROM likes
        WHERE likeable_type = 'profile_comment' AND likeable_id = pc.id
      ), 0)
      """,
      ""
    )
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.migrate
```

- [ ] **Step 4: Update ProfileComment schema**

In `lib/o_grupo_de_estudos/engagement/profile_comment.ex`, update the schema:

```elixir
defmodule OGrupoDeEstudos.Engagement.ProfileComment do
  @moduledoc """
  A comment posted on a user's profile page.

  Supports soft-deletion via `deleted_at`, 1-level nesting via
  `parent_profile_comment_id`, and denormalized engagement counters.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "profile_comments" do
    field :body, :string
    field :deleted_at, :naive_datetime
    field :like_count, :integer, default: 0
    field :reply_count, :integer, default: 0

    belongs_to :author, OGrupoDeEstudos.Accounts.User
    belongs_to :profile, OGrupoDeEstudos.Accounts.User
    belongs_to :parent_comment, __MODULE__,
      foreign_key: :parent_profile_comment_id

    has_many :replies, __MODULE__,
      foreign_key: :parent_profile_comment_id,
      where: [deleted_at: nil]

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :author_id, :profile_id, :parent_profile_comment_id])
    |> validate_required([:body, :author_id, :profile_id])
    |> validate_length(:body, min: 1, max: 2000)
    |> foreign_key_constraint(:author_id)
    |> foreign_key_constraint(:profile_id)
    |> foreign_key_constraint(:parent_profile_comment_id)
  end
end
```

- [ ] **Step 5: Run tests**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test
```

Expected: All existing tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add priv/repo/migrations/*nesting* lib/o_grupo_de_estudos/engagement/profile_comment.ex && git commit -m "feat: add nesting + engagement counters to profile_comments"
```

---

### Task 3: Migrations — create step_comments + sequence_comments

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_step_comments.exs`
- Create: `priv/repo/migrations/TIMESTAMP_create_sequence_comments.exs`

- [ ] **Step 1: Generate migrations**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.gen.migration create_step_comments && mix ecto.gen.migration create_sequence_comments
```

- [ ] **Step 2: Write step_comments migration**

```elixir
defmodule OGrupoDeEstudos.Repo.Migrations.CreateStepComments do
  use Ecto.Migration

  def change do
    create table(:step_comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :deleted_at, :naive_datetime
      add :like_count, :integer, default: 0, null: false
      add :reply_count, :integer, default: 0, null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :step_id, references(:steps, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_step_comment_id,
        references(:step_comments, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:step_comments, [:user_id])
    create index(:step_comments, [:parent_step_comment_id])

    create index(:step_comments, [:step_id, "like_count DESC", "inserted_at DESC"],
      name: :step_comments_engagement_idx,
      where: "deleted_at IS NULL"
    )

    create index(:step_comments, [:parent_step_comment_id, :inserted_at],
      name: :step_comments_parent_idx,
      where: "parent_step_comment_id IS NOT NULL"
    )
  end
end
```

- [ ] **Step 3: Write sequence_comments migration**

```elixir
defmodule OGrupoDeEstudos.Repo.Migrations.CreateSequenceComments do
  use Ecto.Migration

  def change do
    create table(:sequence_comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :deleted_at, :naive_datetime
      add :like_count, :integer, default: 0, null: false
      add :reply_count, :integer, default: 0, null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :sequence_id, references(:sequences, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_sequence_comment_id,
        references(:sequence_comments, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:sequence_comments, [:user_id])
    create index(:sequence_comments, [:parent_sequence_comment_id])

    create index(:sequence_comments, [:sequence_id, "like_count DESC", "inserted_at DESC"],
      name: :sequence_comments_engagement_idx,
      where: "deleted_at IS NULL"
    )

    create index(:sequence_comments, [:parent_sequence_comment_id, :inserted_at],
      name: :sequence_comments_parent_idx,
      where: "parent_sequence_comment_id IS NOT NULL"
    )
  end
end
```

- [ ] **Step 4: Run migrations**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.migrate
```

- [ ] **Step 5: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add priv/repo/migrations/*step_comments* priv/repo/migrations/*sequence_comments* && git commit -m "feat: create step_comments and sequence_comments tables"
```

---

### Task 4: Migration — create notifications table

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_notifications.exs`

- [ ] **Step 1: Generate migration**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.gen.migration create_notifications
```

- [ ] **Step 2: Write the migration**

```elixir
defmodule OGrupoDeEstudos.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action, :string, null: false
      add :group_key, :string, null: false
      add :target_type, :string, null: false
      add :target_id, :binary_id, null: false
      add :parent_type, :string, null: false
      add :parent_id, :binary_id, null: false
      add :read_at, :naive_datetime

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :actor_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end

    create index(:notifications, [:user_id, :read_at, :inserted_at],
      name: :notifications_user_feed_idx
    )

    create index(:notifications, [:user_id, :group_key],
      name: :notifications_user_group_idx
    )

    create index(:notifications, [:actor_id, :target_type, :target_id],
      name: :notifications_actor_target_idx
    )
  end
end
```

- [ ] **Step 3: Run migration**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.migrate
```

- [ ] **Step 4: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add priv/repo/migrations/*notifications* && git commit -m "feat: create notifications table"
```

---

### Task 5: Migration — Postgres triggers for denormalized counters

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_engagement_triggers.exs`

- [ ] **Step 1: Generate migration**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.gen.migration create_engagement_triggers
```

- [ ] **Step 2: Write the trigger migration**

```elixir
defmodule OGrupoDeEstudos.Repo.Migrations.CreateEngagementTriggers do
  use Ecto.Migration

  def up do
    # ── like_count trigger on all likeable tables ���─────────────────
    execute("""
    CREATE OR REPLACE FUNCTION update_like_count() RETURNS TRIGGER AS $$
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
    """)

    execute("""
    CREATE TRIGGER likes_update_count
      AFTER INSERT OR DELETE ON likes
      FOR EACH ROW EXECUTE FUNCTION update_like_count();
    """)

    # ── reply_count triggers for each comment table ────────────────

    # step_comments
    execute("""
    CREATE OR REPLACE FUNCTION update_step_comment_reply_count() RETURNS TRIGGER AS $$
    BEGIN
      IF TG_OP = 'INSERT' AND NEW.parent_step_comment_id IS NOT NULL THEN
        UPDATE step_comments SET reply_count = reply_count + 1
        WHERE id = NEW.parent_step_comment_id;
      ELSIF TG_OP = 'DELETE' AND OLD.parent_step_comment_id IS NOT NULL THEN
        UPDATE step_comments SET reply_count = reply_count - 1
        WHERE id = OLD.parent_step_comment_id;
      END IF;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER step_comments_reply_count
      AFTER INSERT OR DELETE ON step_comments
      FOR EACH ROW EXECUTE FUNCTION update_step_comment_reply_count();
    """)

    # sequence_comments
    execute("""
    CREATE OR REPLACE FUNCTION update_sequence_comment_reply_count() RETURNS TRIGGER AS $$
    BEGIN
      IF TG_OP = 'INSERT' AND NEW.parent_sequence_comment_id IS NOT NULL THEN
        UPDATE sequence_comments SET reply_count = reply_count + 1
        WHERE id = NEW.parent_sequence_comment_id;
      ELSIF TG_OP = 'DELETE' AND OLD.parent_sequence_comment_id IS NOT NULL THEN
        UPDATE sequence_comments SET reply_count = reply_count - 1
        WHERE id = OLD.parent_sequence_comment_id;
      END IF;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER sequence_comments_reply_count
      AFTER INSERT OR DELETE ON sequence_comments
      FOR EACH ROW EXECUTE FUNCTION update_sequence_comment_reply_count();
    """)

    # profile_comments
    execute("""
    CREATE OR REPLACE FUNCTION update_profile_comment_reply_count() RETURNS TRIGGER AS $$
    BEGIN
      IF TG_OP = 'INSERT' AND NEW.parent_profile_comment_id IS NOT NULL THEN
        UPDATE profile_comments SET reply_count = reply_count + 1
        WHERE id = NEW.parent_profile_comment_id;
      ELSIF TG_OP = 'DELETE' AND OLD.parent_profile_comment_id IS NOT NULL THEN
        UPDATE profile_comments SET reply_count = reply_count - 1
        WHERE id = OLD.parent_profile_comment_id;
      END IF;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER profile_comments_reply_count
      AFTER INSERT OR DELETE ON profile_comments
      FOR EACH ROW EXECUTE FUNCTION update_profile_comment_reply_count();
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS likes_update_count ON likes")
    execute("DROP FUNCTION IF EXISTS update_like_count()")

    execute("DROP TRIGGER IF EXISTS step_comments_reply_count ON step_comments")
    execute("DROP FUNCTION IF EXISTS update_step_comment_reply_count()")

    execute("DROP TRIGGER IF EXISTS sequence_comments_reply_count ON sequence_comments")
    execute("DROP FUNCTION IF EXISTS update_sequence_comment_reply_count()")

    execute("DROP TRIGGER IF EXISTS profile_comments_reply_count ON profile_comments")
    execute("DROP FUNCTION IF EXISTS update_profile_comment_reply_count()")
  end
end
```

- [ ] **Step 3: Run migration**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.migrate
```

- [ ] **Step 4: Run all tests to verify no regressions**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test
```

Expected: All pass. The like_count trigger now auto-updates on toggle_like — existing tests should still pass since they don't assert on `like_count` column yet.

- [ ] **Step 5: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add priv/repo/migrations/*triggers* && git commit -m "feat: Postgres triggers for like_count + reply_count denormalization"
```

---

### Task 6: Schemas + Commentable behaviour + Like expansion

**Files:**
- Create: `lib/o_grupo_de_estudos/engagement/comments/commentable.ex`
- Create: `lib/o_grupo_de_estudos/engagement/comments/step_comment.ex`
- Create: `lib/o_grupo_de_estudos/engagement/comments/step_comment_query.ex`
- Create: `lib/o_grupo_de_estudos/engagement/comments/sequence_comment.ex`
- Create: `lib/o_grupo_de_estudos/engagement/comments/sequence_comment_query.ex`
- Create: `lib/o_grupo_de_estudos/engagement/notifications/notification.ex`
- Modify: `lib/o_grupo_de_estudos/engagement/profile_comment_query.ex`
- Modify: `lib/o_grupo_de_estudos/engagement/like.ex`

- [ ] **Step 1: Create Commentable behaviour**

Create `lib/o_grupo_de_estudos/engagement/comments/commentable.ex`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Comments.Commentable do
  @moduledoc """
  Behaviour defining the shared query contract for all comment types.

  Each comment query module (StepCommentQuery, SequenceCommentQuery,
  ProfileCommentQuery) implements these callbacks so the Engagement
  context can use generic CRUD logic.
  """

  @callback base_query() :: Ecto.Query.t()
  @callback for_parent(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  @callback roots_only(Ecto.Query.t()) :: Ecto.Query.t()
  @callback replies_for(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  @callback ordered_by_engagement(Ecto.Query.t()) :: Ecto.Query.t()
  @callback schema() :: module()
  @callback parent_field() :: atom()
  @callback parent_comment_field() :: atom()
  @callback likeable_type() :: String.t()
end
```

- [ ] **Step 2: Create StepComment schema**

Create `lib/o_grupo_de_estudos/engagement/comments/step_comment.ex`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Comments.StepComment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "step_comments" do
    field :body, :string
    field :deleted_at, :naive_datetime
    field :like_count, :integer, default: 0
    field :reply_count, :integer, default: 0

    belongs_to :user, OGrupoDeEstudos.Accounts.User
    belongs_to :step, OGrupoDeEstudos.Encyclopedia.Step
    belongs_to :parent_comment, __MODULE__,
      foreign_key: :parent_step_comment_id

    has_many :replies, __MODULE__,
      foreign_key: :parent_step_comment_id,
      where: [deleted_at: nil]

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :user_id, :step_id, :parent_step_comment_id])
    |> validate_required([:body, :user_id, :step_id])
    |> validate_length(:body, min: 1, max: 2000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:step_id)
    |> foreign_key_constraint(:parent_step_comment_id)
  end
end
```

- [ ] **Step 3: Create StepCommentQuery**

Create `lib/o_grupo_de_estudos/engagement/comments/step_comment_query.ex`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Comments.StepCommentQuery do
  @behaviour OGrupoDeEstudos.Engagement.Comments.Commentable

  import Ecto.Query

  alias OGrupoDeEstudos.Engagement.Comments.StepComment

  @impl true
  def base_query, do: from(c in StepComment, where: is_nil(c.deleted_at))

  @impl true
  def for_parent(query, step_id),
    do: where(query, [c], c.step_id == ^step_id)

  @impl true
  def roots_only(query),
    do: where(query, [c], is_nil(c.parent_step_comment_id))

  @impl true
  def replies_for(query, comment_id),
    do: where(query, [c], c.parent_step_comment_id == ^comment_id)

  @impl true
  def ordered_by_engagement(query),
    do: order_by(query, [c], [desc: c.like_count, desc: c.inserted_at])

  @impl true
  def schema, do: StepComment

  @impl true
  def parent_field, do: :step_id

  @impl true
  def parent_comment_field, do: :parent_step_comment_id

  @impl true
  def likeable_type, do: "step_comment"
end
```

- [ ] **Step 4: Create SequenceComment schema**

Create `lib/o_grupo_de_estudos/engagement/comments/sequence_comment.ex`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Comments.SequenceComment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sequence_comments" do
    field :body, :string
    field :deleted_at, :naive_datetime
    field :like_count, :integer, default: 0
    field :reply_count, :integer, default: 0

    belongs_to :user, OGrupoDeEstudos.Accounts.User
    belongs_to :sequence, OGrupoDeEstudos.Sequences.Sequence
    belongs_to :parent_comment, __MODULE__,
      foreign_key: :parent_sequence_comment_id

    has_many :replies, __MODULE__,
      foreign_key: :parent_sequence_comment_id,
      where: [deleted_at: nil]

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :user_id, :sequence_id, :parent_sequence_comment_id])
    |> validate_required([:body, :user_id, :sequence_id])
    |> validate_length(:body, min: 1, max: 2000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:sequence_id)
    |> foreign_key_constraint(:parent_sequence_comment_id)
  end
end
```

- [ ] **Step 5: Create SequenceCommentQuery**

Create `lib/o_grupo_de_estudos/engagement/comments/sequence_comment_query.ex`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Comments.SequenceCommentQuery do
  @behaviour OGrupoDeEstudos.Engagement.Comments.Commentable

  import Ecto.Query

  alias OGrupoDeEstudos.Engagement.Comments.SequenceComment

  @impl true
  def base_query, do: from(c in SequenceComment, where: is_nil(c.deleted_at))

  @impl true
  def for_parent(query, sequence_id),
    do: where(query, [c], c.sequence_id == ^sequence_id)

  @impl true
  def roots_only(query),
    do: where(query, [c], is_nil(c.parent_sequence_comment_id))

  @impl true
  def replies_for(query, comment_id),
    do: where(query, [c], c.parent_sequence_comment_id == ^comment_id)

  @impl true
  def ordered_by_engagement(query),
    do: order_by(query, [c], [desc: c.like_count, desc: c.inserted_at])

  @impl true
  def schema, do: SequenceComment

  @impl true
  def parent_field, do: :sequence_id

  @impl true
  def parent_comment_field, do: :parent_sequence_comment_id

  @impl true
  def likeable_type, do: "sequence_comment"
end
```

- [ ] **Step 6: Refactor ProfileCommentQuery to implement Commentable**

Replace `lib/o_grupo_de_estudos/engagement/profile_comment_query.ex` with:

```elixir
defmodule OGrupoDeEstudos.Engagement.ProfileCommentQuery do
  @moduledoc """
  Query reducers for ProfileComment. Implements Commentable behaviour
  and retains legacy `list_by/1` for backwards compatibility.
  """

  @behaviour OGrupoDeEstudos.Engagement.Comments.Commentable

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Engagement.ProfileComment

  # ── Commentable behaviour ─────────────────────────────

  @impl true
  def base_query, do: from(c in ProfileComment, where: is_nil(c.deleted_at))

  @impl true
  def for_parent(query, profile_id),
    do: where(query, [c], c.profile_id == ^profile_id)

  @impl true
  def roots_only(query),
    do: where(query, [c], is_nil(c.parent_profile_comment_id))

  @impl true
  def replies_for(query, comment_id),
    do: where(query, [c], c.parent_profile_comment_id == ^comment_id)

  @impl true
  def ordered_by_engagement(query),
    do: order_by(query, [c], [desc: c.like_count, desc: c.inserted_at])

  @impl true
  def schema, do: ProfileComment

  @impl true
  def parent_field, do: :profile_id

  @impl true
  def parent_comment_field, do: :parent_profile_comment_id

  @impl true
  def likeable_type, do: "profile_comment"

  # ── Legacy list_by (kept for backward compat) ─────────

  def list_by(opts \\ []) do
    opts = Keyword.put_new(opts, :include_deleted, false)
    opts = Keyword.put_new(opts, :order_by, desc: :inserted_at)

    ProfileComment
    |> apply_filters(opts)
    |> Repo.all()
    |> maybe_preload(Keyword.get(opts, :preload, []))
  end

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, &apply_filter/2)
  end

  defp apply_filter({:profile_id, id}, query),
    do: where(query, [c], c.profile_id == ^id)

  defp apply_filter({:author_id, id}, query),
    do: where(query, [c], c.author_id == ^id)

  defp apply_filter({:include_deleted, false}, query),
    do: where(query, [c], is_nil(c.deleted_at))

  defp apply_filter({:include_deleted, true}, query), do: query

  defp apply_filter({:order_by, order}, query),
    do: order_by(query, ^order)

  defp apply_filter(_unknown, query), do: query

  defp maybe_preload(results, []), do: results
  defp maybe_preload(results, preloads), do: Repo.preload(results, preloads)
end
```

- [ ] **Step 7: Create Notification schema**

Create `lib/o_grupo_de_estudos/engagement/notifications/notification.ex`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notifications" do
    field :action, :string
    field :group_key, :string
    field :target_type, :string
    field :target_id, :binary_id
    field :parent_type, :string
    field :parent_id, :binary_id
    field :read_at, :naive_datetime

    belongs_to :user, OGrupoDeEstudos.Accounts.User
    belongs_to :actor, OGrupoDeEstudos.Accounts.User

    timestamps(updated_at: false)
  end

  @valid_actions ~w(liked_comment replied_comment liked_step liked_sequence)
  @valid_target_types ~w(step_comment sequence_comment profile_comment step sequence)
  @valid_parent_types ~w(step sequence profile)

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :action, :group_key, :target_type, :target_id,
      :parent_type, :parent_id, :user_id, :actor_id, :read_at
    ])
    |> validate_required([
      :action, :group_key, :target_type, :target_id,
      :parent_type, :parent_id, :user_id, :actor_id
    ])
    |> validate_inclusion(:action, @valid_actions)
    |> validate_inclusion(:target_type, @valid_target_types)
    |> validate_inclusion(:parent_type, @valid_parent_types)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:actor_id)
  end
end
```

- [ ] **Step 8: Expand Like valid_types**

In `lib/o_grupo_de_estudos/engagement/like.ex`, change line 19:

From:
```elixir
|> validate_inclusion(:likeable_type, ["step", "sequence", "step_link", "profile_comment"])
```

To:
```elixir
|> validate_inclusion(:likeable_type, ~w(step sequence step_link profile_comment step_comment sequence_comment))
```

- [ ] **Step 9: Update Factory with new schemas**

In `test/support/factory.ex`, add the new aliases and factories:

Add to the alias block:
```elixir
alias OGrupoDeEstudos.Engagement.Comments.{StepComment, SequenceComment}
alias OGrupoDeEstudos.Engagement.Notifications.Notification
```

Add these factories at the end (before the closing `end`):

```elixir
def step_comment_factory do
  %StepComment{
    body: sequence(:step_comment_body, &"Comentário no passo #{&1}"),
    user: build(:user),
    step: build(:step)
  }
end

def sequence_comment_factory do
  %SequenceComment{
    body: sequence(:sequence_comment_body, &"Comentário na sequência #{&1}"),
    user: build(:user),
    sequence: build(:sequence)
  }
end

def notification_factory do
  %Notification{
    action: "replied_comment",
    group_key: sequence(:group_key, &"comment:step_comment:#{Ecto.UUID.generate()}_#{&1}"),
    target_type: "step_comment",
    target_id: Ecto.UUID.generate(),
    parent_type: "step",
    parent_id: Ecto.UUID.generate(),
    user: build(:user),
    actor: build(:user)
  }
end
```

- [ ] **Step 10: Verify compilation + tests**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

Expected: Compiles clean, all existing tests pass.

- [ ] **Step 11: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add lib/o_grupo_de_estudos/engagement/comments/ lib/o_grupo_de_estudos/engagement/notifications/notification.ex lib/o_grupo_de_estudos/engagement/like.ex lib/o_grupo_de_estudos/engagement/profile_comment_query.ex test/support/factory.ex && git commit -m "feat: Commentable behaviour, StepComment/SequenceComment schemas, Notification schema, Like expansion"
```

---

### Task 7: Authorization Policy

**Files:**
- Create: `lib/o_grupo_de_estudos/authorization/policy.ex`
- Create: `test/o_grupo_de_estudos/authorization/policy_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/o_grupo_de_estudos/authorization/policy_test.exs`:

```elixir
defmodule OGrupoDeEstudos.Authorization.PolicyTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Authorization.Policy

  describe "authorize(:delete_comment, user, comment)" do
    test "admin can delete any comment" do
      admin = insert(:admin)
      comment = insert(:step_comment)
      assert :ok = Policy.authorize(:delete_comment, admin, comment)
    end

    test "author can delete own comment" do
      user = insert(:user)
      comment = insert(:step_comment, user: user)
      assert :ok = Policy.authorize(:delete_comment, user, comment)
    end

    test "other user cannot delete someone else's comment" do
      user = insert(:user)
      comment = insert(:step_comment)
      assert {:error, :unauthorized} = Policy.authorize(:delete_comment, user, comment)
    end
  end

  describe "authorize(:create_comment, user, _)" do
    test "authenticated user can create comments" do
      user = insert(:user)
      assert :ok = Policy.authorize(:create_comment, user, nil)
    end

    test "nil user cannot create comments" do
      assert {:error, :unauthenticated} = Policy.authorize(:create_comment, nil, nil)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test test/o_grupo_de_estudos/authorization/policy_test.exs
```

Expected: FAIL — module `Policy` not found.

- [ ] **Step 3: Implement Policy**

Create `lib/o_grupo_de_estudos/authorization/policy.ex`:

```elixir
defmodule OGrupoDeEstudos.Authorization.Policy do
  @moduledoc """
  Centralized authorization rules.

  Pattern: `authorize(action, user, resource) :: :ok | {:error, reason}`
  """

  alias OGrupoDeEstudos.Accounts.User

  def authorize(:delete_comment, %User{role: "admin"}, _comment), do: :ok

  def authorize(:delete_comment, %User{id: user_id}, %{user_id: comment_user_id})
      when user_id == comment_user_id,
      do: :ok

  def authorize(:delete_comment, _, _), do: {:error, :unauthorized}

  def authorize(:create_comment, %User{}, _), do: :ok
  def authorize(:create_comment, nil, _), do: {:error, :unauthenticated}
end
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test test/o_grupo_de_estudos/authorization/policy_test.exs
```

Expected: All 5 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add lib/o_grupo_de_estudos/authorization/ test/o_grupo_de_estudos/authorization/ && git commit -m "feat: Authorization.Policy with delete_comment + create_comment rules"
```

---

### Task 8: Engagement context — generic comment CRUD

**Files:**
- Modify: `lib/o_grupo_de_estudos/engagement.ex`
- Modify: `test/o_grupo_de_estudos/engagement_test.exs`

- [ ] **Step 1: Write failing tests for step comments**

Add to `test/o_grupo_de_estudos/engagement_test.exs`:

```elixir
describe "step comments" do
  test "create_step_comment/3 creates a root comment", %{user: user, step: step} do
    assert {:ok, comment} =
             Engagement.create_step_comment(user, step.id, %{body: "Ótimo passo!"})

    assert comment.body == "Ótimo passo!"
    assert comment.user_id == user.id
    assert comment.step_id == step.id
    assert is_nil(comment.parent_step_comment_id)
    assert comment.user != nil
  end

  test "create_step_comment/3 creates a reply and bumps reply_count", %{user: user, step: step} do
    {:ok, parent} = Engagement.create_step_comment(user, step.id, %{body: "Parent"})

    other_user = insert(:user)

    {:ok, reply} =
      Engagement.create_step_comment(other_user, step.id, %{
        body: "Reply",
        parent_step_comment_id: parent.id
      })

    assert reply.parent_step_comment_id == parent.id

    # Reload parent to check trigger-updated reply_count
    updated_parent = Repo.get!(StepComment, parent.id)
    assert updated_parent.reply_count == 1
  end

  test "list_step_comments/2 returns roots ordered by engagement", %{user: user, step: step} do
    {:ok, c1} = Engagement.create_step_comment(user, step.id, %{body: "First"})
    {:ok, _c2} = Engagement.create_step_comment(user, step.id, %{body: "Second"})

    # Like c1 to boost it (trigger updates like_count)
    Engagement.toggle_like(user.id, "step_comment", c1.id)

    comments = Engagement.list_step_comments(step.id)
    assert length(comments) == 2
    assert hd(comments).id == c1.id
  end

  test "delete_step_comment/2 hard deletes when no replies", %{user: user, step: step} do
    {:ok, comment} = Engagement.create_step_comment(user, step.id, %{body: "Delete me"})
    assert {:ok, :deleted} = Engagement.delete_step_comment(user, comment)
    assert Repo.get(StepComment, comment.id) == nil
  end

  test "delete_step_comment/2 tombstones when has replies", %{user: user, step: step} do
    {:ok, parent} = Engagement.create_step_comment(user, step.id, %{body: "Parent"})

    other = insert(:user)
    {:ok, _reply} =
      Engagement.create_step_comment(other, step.id, %{
        body: "Reply",
        parent_step_comment_id: parent.id
      })

    # Reload to get updated reply_count from trigger
    parent = Repo.get!(StepComment, parent.id)
    assert {:ok, tombstoned} = Engagement.delete_step_comment(user, parent)
    assert is_nil(tombstoned.body)
    assert tombstoned.deleted_at != nil
  end

  test "delete_step_comment/2 rejects unauthorized user", %{step: step} do
    author = insert(:user)
    other = insert(:user)
    {:ok, comment} = Engagement.create_step_comment(author, step.id, %{body: "Mine"})
    assert {:error, :unauthorized} = Engagement.delete_step_comment(other, comment)
  end

  test "list_replies/3 returns replies for a comment", %{user: user, step: step} do
    {:ok, parent} = Engagement.create_step_comment(user, step.id, %{body: "Parent"})
    other = insert(:user)

    {:ok, _r1} =
      Engagement.create_step_comment(other, step.id, %{
        body: "Reply 1",
        parent_step_comment_id: parent.id
      })

    {:ok, _r2} =
      Engagement.create_step_comment(user, step.id, %{
        body: "Reply 2",
        parent_step_comment_id: parent.id
      })

    alias OGrupoDeEstudos.Engagement.Comments.StepCommentQuery
    replies = Engagement.list_replies(StepCommentQuery, parent.id)
    assert length(replies) == 2
  end

  test "comment_counts_for/2 returns counts per step", %{user: user, step: step} do
    other_step = insert(:step)
    {:ok, _} = Engagement.create_step_comment(user, step.id, %{body: "A"})
    {:ok, _} = Engagement.create_step_comment(user, step.id, %{body: "B"})
    {:ok, _} = Engagement.create_step_comment(user, other_step.id, %{body: "C"})

    counts = Engagement.comment_counts_for("step", [step.id, other_step.id])
    assert counts[step.id] == 2
    assert counts[other_step.id] == 1
  end
end
```

- [ ] **Step 2: Run test to verify failures**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test test/o_grupo_de_estudos/engagement_test.exs
```

Expected: New tests fail — functions not defined.

- [ ] **Step 3: Implement the expanded Engagement context**

Replace `lib/o_grupo_de_estudos/engagement.ex` with:

```elixir
defmodule OGrupoDeEstudos.Engagement do
  @moduledoc """
  Context for user engagement: likes, comments (step/sequence/profile),
  notifications, and engagement metrics.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Authorization.Policy

  alias OGrupoDeEstudos.Engagement.{Like, LikeQuery, ProfileComment, ProfileCommentQuery}

  alias OGrupoDeEstudos.Engagement.Comments.{
    StepComment,
    StepCommentQuery,
    SequenceComment,
    SequenceCommentQuery
  }

  alias OGrupoDeEstudos.Engagement.Notifications.{Notification, NotificationQuery, Dispatcher}

  # ── Likes (existing API, unchanged signatures) ─────────

  def toggle_like(user_id, likeable_type, likeable_id) do
    case Repo.get_by(Like,
           user_id: user_id,
           likeable_type: likeable_type,
           likeable_id: likeable_id
         ) do
      nil ->
        %Like{}
        |> Like.changeset(%{
          user_id: user_id,
          likeable_type: likeable_type,
          likeable_id: likeable_id
        })
        |> Repo.insert()
        |> case do
          {:ok, _} -> {:ok, :liked}
          error -> error
        end

      like ->
        Repo.delete(like)
        {:ok, :unliked}
    end
  end

  def liked?(user_id, likeable_type, likeable_id),
    do: LikeQuery.exists?(user_id, likeable_type, likeable_id)

  def count_likes(likeable_type, likeable_id),
    do: LikeQuery.count(likeable_type, likeable_id)

  def likes_map(user_id, likeable_type, likeable_ids),
    do: LikeQuery.batch_map(user_id, likeable_type, likeable_ids)

  # ── Step comments ──────────────────────────────────────

  def list_step_comments(step_id, opts \\ []),
    do: list_comments(StepCommentQuery, step_id, opts)

  def create_step_comment(user, step_id, attrs),
    do: create_comment(StepComment, StepCommentQuery, user, step_id, attrs)

  def delete_step_comment(user, comment),
    do: delete_comment(StepComment, StepCommentQuery, user, comment)

  # ── Sequence comments ──────────────────────────────────

  def list_sequence_comments(sequence_id, opts \\ []),
    do: list_comments(SequenceCommentQuery, sequence_id, opts)

  def create_sequence_comment(user, sequence_id, attrs),
    do: create_comment(SequenceComment, SequenceCommentQuery, user, sequence_id, attrs)

  def delete_sequence_comment(user, comment),
    do: delete_comment(SequenceComment, SequenceCommentQuery, user, comment)

  # ── Profile comments (backwards-compatible) ────────────

  def list_profile_comments(opts) when is_list(opts) do
    ProfileCommentQuery.list_by(opts)
  end

  def list_profile_comments(profile_id, opts) when is_binary(profile_id) do
    list_comments(ProfileCommentQuery, profile_id, opts)
  end

  def create_profile_comment(%{} = attrs) when not is_struct(attrs) do
    %ProfileComment{}
    |> ProfileComment.changeset(attrs)
    |> Repo.insert()
  end

  def create_profile_comment(user, profile_id, attrs),
    do: create_comment(ProfileComment, ProfileCommentQuery, user, profile_id, attrs)

  def delete_profile_comment(%ProfileComment{} = comment) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    comment
    |> Ecto.Changeset.change(deleted_at: now)
    |> Repo.update()
  end

  def delete_profile_comment(user, comment),
    do: delete_comment(ProfileComment, ProfileCommentQuery, user, comment)

  # ── Replies (generic) ──────────────────────────────────

  def list_replies(query_mod, comment_id, opts \\ []) do
    query_mod.base_query()
    |> query_mod.replies_for(comment_id)
    |> query_mod.ordered_by_engagement()
    |> maybe_limit(opts)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  # ── Comment counts batch ───────────────────────────────

  def comment_counts_for("step", parent_ids) do
    count_comments(StepComment, :step_id, parent_ids)
  end

  def comment_counts_for("sequence", parent_ids) do
    count_comments(SequenceComment, :sequence_id, parent_ids)
  end

  def comment_counts_for("profile", parent_ids) do
    count_comments(ProfileComment, :profile_id, parent_ids)
  end

  defp count_comments(schema, parent_field, parent_ids) do
    from(c in schema,
      where: field(c, ^parent_field) in ^parent_ids and is_nil(c.deleted_at),
      group_by: field(c, ^parent_field),
      select: {field(c, ^parent_field), count(c.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  # ── Notifications ──────────────────────────────────────

  def list_notifications(user_id, opts \\ []) do
    NotificationQuery.list_for_user(user_id, opts)
  end

  def unread_count(user_id) do
    NotificationQuery.unread_count(user_id)
  end

  def mark_as_read(_user, notification_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    from(n in Notification, where: n.id == ^notification_id and is_nil(n.read_at))
    |> Repo.update_all(set: [read_at: now])

    :ok
  end

  def mark_all_read(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    from(n in Notification, where: n.user_id == ^user.id and is_nil(n.read_at))
    |> Repo.update_all(set: [read_at: now])

    :ok
  end

  # ── Private: generic comment CRUD ──────────────────────

  defp list_comments(query_mod, parent_id, opts) do
    query_mod.base_query()
    |> query_mod.for_parent(parent_id)
    |> query_mod.roots_only()
    |> query_mod.ordered_by_engagement()
    |> maybe_limit(opts)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  defp create_comment(schema_mod, query_mod, user, parent_id, attrs) do
    parent_field = query_mod.parent_field()
    parent_comment_field = query_mod.parent_comment_field()

    full_attrs =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.put(parent_field, parent_id)

    changeset = schema_mod.changeset(struct(schema_mod), full_attrs)

    Multi.new()
    |> Multi.insert(:comment, changeset)
    |> Multi.run(:bump_reply_count, fn repo, %{comment: comment} ->
      parent_comment_id = Map.get(comment, parent_comment_field)

      if parent_comment_id do
        repo.update_all(
          from(c in schema_mod, where: c.id == ^parent_comment_id),
          inc: [reply_count: 1]
        )
      end

      {:ok, :done}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{comment: comment}} ->
        comment = Repo.preload(comment, :user)
        # Dispatch notification asynchronously (won't fail the create)
        safe_dispatch(:new_comment, comment, user, query_mod)
        {:ok, comment}

      {:error, :comment, changeset, _} ->
        {:error, changeset}
    end
  end

  defp delete_comment(schema_mod, query_mod, user, comment) do
    with :ok <- Policy.authorize(:delete_comment, user, comment) do
      parent_comment_field = query_mod.parent_comment_field()

      if comment.reply_count == 0 do
        # Hard delete — no replies, remove completely
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
        # Tombstone — has replies, keep placeholder
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        comment
        |> Ecto.Changeset.change(%{body: nil, deleted_at: now})
        |> Repo.update()
      end
    end
  end

  defp safe_dispatch(action, comment, user, query_mod) do
    try do
      Dispatcher.notify(action, comment, user, query_mod)
    rescue
      _ -> :ok
    end
  end

  defp maybe_limit(query, opts) do
    case Keyword.get(opts, :limit) do
      nil -> query
      n -> limit(query, ^n)
    end
  end
end
```

- [ ] **Step 4: Create stub NotificationQuery (needed for compilation)**

Create `lib/o_grupo_de_estudos/engagement/notifications/notification_query.ex`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Notifications.NotificationQuery do
  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Engagement.Notifications.Notification

  def list_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    from(n in Notification,
      where: n.user_id == ^user_id,
      order_by: [asc: n.read_at, desc: n.inserted_at],
      limit: ^limit,
      offset: ^offset,
      preload: [:actor]
    )
    |> Repo.all()
  end

  def unread_count(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      select: count(n.id)
    )
    |> Repo.one()
  end
end
```

- [ ] **Step 5: Create stub Dispatcher (needed for compilation)**

Create `lib/o_grupo_de_estudos/engagement/notifications/dispatcher.ex`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Notifications.Dispatcher do
  @moduledoc """
  Creates notification records and broadcasts via PubSub.
  """

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias Phoenix.PubSub

  @pubsub OGrupoDeEstudos.PubSub

  def notify(:new_comment, comment, actor, query_mod) do
    recipients = determine_comment_recipients(comment, actor, query_mod)
    parent_field = query_mod.parent_field()
    parent_id = Map.get(comment, parent_field)

    insert_and_broadcast(recipients, fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: actor.id,
        action: "replied_comment",
        group_key: "comment:#{query_mod.likeable_type()}:#{root_comment_id(comment, query_mod)}",
        target_type: query_mod.likeable_type(),
        target_id: comment.id,
        parent_type: parent_type_from(query_mod),
        parent_id: parent_id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    end)
  end

  def notify(:new_like, likeable_type, likeable_id, actor, recipient_user_id) do
    insert_and_broadcast([recipient_user_id], fn user_id ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user_id,
        actor_id: actor.id,
        action: "liked_comment",
        group_key: "like:#{likeable_type}:#{likeable_id}",
        target_type: likeable_type,
        target_id: likeable_id,
        parent_type: parent_type_for_likeable(likeable_type),
        parent_id: likeable_id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    end)
  end

  # ── Recipients ─────────────────────────────────────────

  defp determine_comment_recipients(comment, actor, query_mod) do
    parent_comment_field = query_mod.parent_comment_field()
    parent_comment_id = Map.get(comment, parent_comment_field)

    if parent_comment_id do
      parent = Repo.get(query_mod.schema(), parent_comment_id)

      if parent && parent.user_id != actor.id && is_nil(parent.deleted_at) do
        [parent.user_id]
      else
        []
      end
    else
      []
    end
  end

  # ── Insert + Broadcast ─────────────────────────────────

  defp insert_and_broadcast([], _builder), do: :ok

  defp insert_and_broadcast(recipients, builder) do
    notifications = Enum.map(recipients, builder)
    Repo.insert_all(Notification, notifications)

    Enum.each(recipients, fn user_id ->
      PubSub.broadcast(@pubsub, "notifications:#{user_id}", {:new_notification, 1})
    end)
  end

  # ── Helpers ──────────────────────────────────────��─────

  defp root_comment_id(comment, query_mod) do
    parent_comment_field = query_mod.parent_comment_field()
    Map.get(comment, parent_comment_field) || comment.id
  end

  defp parent_type_from(query_mod) do
    case query_mod.parent_field() do
      :step_id -> "step"
      :sequence_id -> "sequence"
      :profile_id -> "profile"
    end
  end

  defp parent_type_for_likeable(type) when type in ~w(step_comment step), do: "step"
  defp parent_type_for_likeable(type) when type in ~w(sequence_comment sequence), do: "sequence"
  defp parent_type_for_likeable(_), do: "profile"
end
```

- [ ] **Step 6: Run tests**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test test/o_grupo_de_estudos/engagement_test.exs
```

Expected: All tests pass (old + new).

- [ ] **Step 7: Run full test suite**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test
```

Expected: All pass, no regressions.

- [ ] **Step 8: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add lib/o_grupo_de_estudos/engagement.ex lib/o_grupo_de_estudos/engagement/notifications/notification_query.ex lib/o_grupo_de_estudos/engagement/notifications/dispatcher.ex test/o_grupo_de_estudos/engagement_test.exs && git commit -m "feat: generic comment CRUD in Engagement context with TDD"
```

---

### Task 9: Notifications — Grouper + Dispatcher tests

**Files:**
- Create: `lib/o_grupo_de_estudos/engagement/notifications/grouper.ex`
- Create: `test/o_grupo_de_estudos/engagement/notifications/grouper_test.exs`
- Create: `test/o_grupo_de_estudos/engagement/notifications/dispatcher_test.exs`

- [ ] **Step 1: Write Grouper test**

Create `test/o_grupo_de_estudos/engagement/notifications/grouper_test.exs`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Notifications.GrouperTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement.Notifications.Grouper

  test "groups notifications by group_key" do
    user1 = insert(:user)
    user2 = insert(:user)
    user3 = insert(:user)
    target_id = Ecto.UUID.generate()

    notifications = [
      insert(:notification, actor: user1, group_key: "like:step_comment:#{target_id}", action: "liked_comment"),
      insert(:notification, actor: user2, group_key: "like:step_comment:#{target_id}", action: "liked_comment"),
      insert(:notification, actor: user3, group_key: "other:key", action: "replied_comment")
    ]

    grouped = Grouper.group(notifications)
    assert length(grouped) == 2

    like_group = Enum.find(grouped, &(&1.action == "liked_comment"))
    assert length(like_group.actors) == 2
    assert like_group.count == 2
  end

  test "returns read: false when any notification in group is unread" do
    target_id = Ecto.UUID.generate()

    notifications = [
      insert(:notification, group_key: "like:sc:#{target_id}", read_at: nil),
      insert(:notification, group_key: "like:sc:#{target_id}",
        read_at: NaiveDateTime.utc_now())
    ]

    [group] = Grouper.group(notifications)
    refute group.read
  end

  test "returns read: true when all in group are read" do
    now = NaiveDateTime.utc_now()
    target_id = Ecto.UUID.generate()

    notifications = [
      insert(:notification, group_key: "like:sc:#{target_id}", read_at: now),
      insert(:notification, group_key: "like:sc:#{target_id}", read_at: now)
    ]

    [group] = Grouper.group(notifications)
    assert group.read
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test test/o_grupo_de_estudos/engagement/notifications/grouper_test.exs
```

- [ ] **Step 3: Implement Grouper**

Create `lib/o_grupo_de_estudos/engagement/notifications/grouper.ex`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Notifications.Grouper do
  @moduledoc """
  Groups raw notifications into Instagram-style display groups.

  Example: "Fulano, Cicrana e +2 curtiram seu comentário"
  """

  def group(notifications) do
    notifications
    |> Enum.group_by(& &1.group_key)
    |> Enum.map(fn {_key, group} ->
      latest = Enum.max_by(group, & &1.inserted_at, NaiveDateTime)

      %{
        id: latest.id,
        action: latest.action,
        actors: group |> Enum.map(& &1.actor_id) |> Enum.uniq(),
        actors_data: group |> Enum.map(& &1.actor) |> Enum.uniq_by(& &1.id),
        target_type: latest.target_type,
        target_id: latest.target_id,
        parent_type: latest.parent_type,
        parent_id: latest.parent_id,
        read: Enum.all?(group, &(not is_nil(&1.read_at))),
        latest_at: latest.inserted_at,
        count: length(group)
      }
    end)
    |> Enum.sort_by(& &1.latest_at, {:desc, NaiveDateTime})
  end
end
```

- [ ] **Step 4: Run Grouper tests**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test test/o_grupo_de_estudos/engagement/notifications/grouper_test.exs
```

Expected: All pass.

- [ ] **Step 5: Write Dispatcher test**

Create `test/o_grupo_de_estudos/engagement/notifications/dispatcher_test.exs`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Notifications.DispatcherTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Repo

  test "replying to a comment notifies the parent comment author" do
    step = insert(:step)
    author = insert(:user)
    replier = insert(:user)

    {:ok, parent} = Engagement.create_step_comment(author, step.id, %{body: "I'm the parent"})

    {:ok, _reply} =
      Engagement.create_step_comment(replier, step.id, %{
        body: "I'm the reply",
        parent_step_comment_id: parent.id
      })

    notifications = Repo.all(from n in Notification, where: n.user_id == ^author.id)
    assert length(notifications) == 1

    [notif] = notifications
    assert notif.action == "replied_comment"
    assert notif.actor_id == replier.id
  end

  test "replying to own comment does NOT create notification" do
    step = insert(:step)
    user = insert(:user)

    {:ok, parent} = Engagement.create_step_comment(user, step.id, %{body: "Parent"})

    {:ok, _reply} =
      Engagement.create_step_comment(user, step.id, %{
        body: "Self reply",
        parent_step_comment_id: parent.id
      })

    notifications = Repo.all(from n in Notification, where: n.user_id == ^user.id)
    assert notifications == []
  end

  test "root comment does not generate notification" do
    step = insert(:step)
    user = insert(:user)

    {:ok, _comment} = Engagement.create_step_comment(user, step.id, %{body: "Root"})

    assert Repo.aggregate(Notification, :count) == 0
  end
end
```

- [ ] **Step 6: Run Dispatcher tests**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test test/o_grupo_de_estudos/engagement/notifications/dispatcher_test.exs
```

Expected: All pass.

- [ ] **Step 7: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add lib/o_grupo_de_estudos/engagement/notifications/grouper.ex test/o_grupo_de_estudos/engagement/notifications/ && git commit -m "feat: notification Grouper + Dispatcher with TDD"
```

---

### Task 10: Notification hooks + handlers macro

**Files:**
- Create: `lib/o_grupo_de_estudos_web/hooks/notification_subscriber.ex`
- Create: `lib/o_grupo_de_estudos_web/notification_handlers.ex`

- [ ] **Step 1: Create NotificationSubscriber on_mount hook**

Create `lib/o_grupo_de_estudos_web/hooks/notification_subscriber.ex`:

```elixir
defmodule OGrupoDeEstudosWeb.Hooks.NotificationSubscriber do
  @moduledoc """
  on_mount hook that subscribes authenticated users to their
  notification PubSub topic and loads unread count.
  """

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

- [ ] **Step 2: Create NotificationHandlers macro**

Create `lib/o_grupo_de_estudos_web/notification_handlers.ex`:

```elixir
defmodule OGrupoDeEstudosWeb.NotificationHandlers do
  @moduledoc """
  Shared handle_info clauses for notification PubSub messages.

  Usage: `use OGrupoDeEstudosWeb.NotificationHandlers` in any LiveView
  that needs to react to real-time notification updates.
  """

  defmacro __using__(_opts) do
    quote do
      def handle_info({:new_notification, _count}, socket) do
        if socket.assigns[:current_user] do
          unread = OGrupoDeEstudos.Engagement.unread_count(socket.assigns.current_user.id)
          {:noreply, assign(socket, :notification_count, unread)}
        else
          {:noreply, socket}
        end
      end

      def handle_info({:notifications_read, _}, socket) do
        {:noreply, assign(socket, :notification_count, 0)}
      end
    end
  end
end
```

- [ ] **Step 3: Add on_mount to key LiveViews**

In every authenticated LiveView that has `on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}`, also add the notification subscriber. Since the router doesn't use live_sessions, we add it per-LiveView.

For the following files, add at the top of the module (after the existing `on_mount`):

`lib/o_grupo_de_estudos_web/live/step_live.ex`:
```elixir
on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}
use OGrupoDeEstudosWeb.NotificationHandlers
```

`lib/o_grupo_de_estudos_web/live/user_profile_live.ex`:
```elixir
on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}
use OGrupoDeEstudosWeb.NotificationHandlers
```

`lib/o_grupo_de_estudos_web/live/community_live.ex`:
```elixir
on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}
use OGrupoDeEstudosWeb.NotificationHandlers
```

`lib/o_grupo_de_estudos_web/live/collection_live.ex`:
```elixir
on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}
use OGrupoDeEstudosWeb.NotificationHandlers
```

`lib/o_grupo_de_estudos_web/live/graph_visual_live.ex`:
```elixir
on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}
use OGrupoDeEstudosWeb.NotificationHandlers
```

- [ ] **Step 4: Compile and test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

Expected: Compiles clean, all tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add lib/o_grupo_de_estudos_web/hooks/ lib/o_grupo_de_estudos_web/notification_handlers.ex lib/o_grupo_de_estudos_web/live/step_live.ex lib/o_grupo_de_estudos_web/live/user_profile_live.ex lib/o_grupo_de_estudos_web/live/community_live.ex lib/o_grupo_de_estudos_web/live/collection_live.ex lib/o_grupo_de_estudos_web/live/graph_visual_live.ex && git commit -m "feat: notification PubSub hooks + handlers macro in all authenticated LiveViews"
```

---

### Task 11: CommentThread UI component

**Files:**
- Create: `lib/o_grupo_de_estudos_web/components/ui/comment_thread.ex`

- [ ] **Step 1: Create the CommentThread component**

Create `lib/o_grupo_de_estudos_web/components/ui/comment_thread.ex`:

```elixir
defmodule OGrupoDeEstudosWeb.UI.CommentThread do
  @moduledoc """
  Reusable Instagram-style comment thread component.

  Renders root comments with like button, reply count, inline reply form,
  tombstone for deleted comments, and "load more" pagination.
  """

  use Phoenix.Component
  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  attr :comments, :list, required: true
  attr :current_user, :map, required: true
  attr :likes_map, :map, required: true
  attr :comment_type, :string, required: true
  attr :parent_id, :string, required: true
  attr :replying_to, :string, default: nil
  attr :replies_map, :map, default: %{}
  attr :total_count, :integer, default: 0
  attr :is_admin, :boolean, default: false

  def comment_thread(assigns) do
    ~H"""
    <section class="space-y-4">
      <div :for={comment <- @comments} class="space-y-2">
        <%= if comment.deleted_at do %>
          <%!-- Tombstone --%>
          <div class="flex items-center gap-2 py-2 px-3 bg-ink-50 rounded-lg">
            <.icon name="hero-trash" class="w-4 h-4 text-ink-300" />
            <span class="text-sm text-ink-400 italic">Comentário removido</span>
          </div>
        <% else %>
          <%!-- Normal comment --%>
          <div class="flex items-start gap-2.5">
            <div class="w-8 h-8 rounded-full bg-ink-200 flex items-center justify-center flex-shrink-0 text-xs font-bold text-ink-500">
              <%= String.first(comment.user.name || comment.user.username || "?") %>
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-baseline gap-1.5">
                <.link navigate={~p"/users/#{comment.user.username}"}
                  class="text-sm font-semibold text-ink-800 no-underline hover:underline">
                  <%= comment.user.username %>
                </.link>
                <span class="text-xs text-ink-400"><%= time_ago(comment.inserted_at) %></span>
              </div>
              <p class="text-sm text-ink-700 mt-0.5 whitespace-pre-wrap"><%= comment.body %></p>
              <div class="flex items-center gap-3 mt-1.5">
                <%!-- Like button --%>
                <button phx-click="toggle_comment_like"
                  phx-value-type={@comment_type}
                  phx-value-id={comment.id}
                  class="flex items-center gap-1 text-xs group">
                  <.icon
                    name={if MapSet.member?(@likes_map.liked_ids, comment.id), do: "hero-heart-solid", else: "hero-heart"}
                    class={[
                      "w-4 h-4 transition-all duration-200",
                      MapSet.member?(@likes_map.liked_ids, comment.id) && "text-accent-red",
                      !MapSet.member?(@likes_map.liked_ids, comment.id) && "text-ink-400 group-hover:text-accent-red/60"
                    ]}
                  />
                  <span :if={comment.like_count > 0} class={[
                    "tabular-nums",
                    MapSet.member?(@likes_map.liked_ids, comment.id) && "text-accent-red font-medium",
                    !MapSet.member?(@likes_map.liked_ids, comment.id) && "text-ink-400"
                  ]}>
                    <%= comment.like_count %>
                  </span>
                </button>
                <%!-- Reply count --%>
                <button :if={comment.reply_count > 0}
                  phx-click="toggle_replies"
                  phx-value-id={comment.id}
                  class="flex items-center gap-1 text-xs text-ink-400 hover:text-ink-600">
                  <.icon name="hero-chat-bubble-left" class="w-4 h-4" />
                  <span><%= comment.reply_count %></span>
                </button>
                <%!-- Reply action --%>
                <button phx-click="start_reply"
                  phx-value-id={comment.id}
                  class="text-xs text-ink-400 hover:text-ink-600 font-medium">
                  Responder
                </button>
                <%!-- Delete --%>
                <button :if={@current_user.id == comment.user_id || @is_admin}
                  phx-click="delete_comment"
                  phx-value-id={comment.id}
                  phx-value-type={@comment_type}
                  data-confirm="Apagar este comentário?"
                  class="text-xs text-ink-300 hover:text-accent-red">
                  <.icon name="hero-trash" class="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <%!-- Replies (indented) --%>
        <div :if={Map.get(@replies_map, comment.id)} class="ml-10 space-y-2 border-l-2 border-ink-100 pl-3">
          <div :for={reply <- Map.get(@replies_map, comment.id, [])} class="flex items-start gap-2">
            <div class="w-6 h-6 rounded-full bg-ink-200 flex items-center justify-center flex-shrink-0 text-[10px] font-bold text-ink-500">
              <%= String.first(reply.user.name || reply.user.username || "?") %>
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-baseline gap-1.5">
                <.link navigate={~p"/users/#{reply.user.username}"}
                  class="text-xs font-semibold text-ink-800 no-underline hover:underline">
                  <%= reply.user.username %>
                </.link>
                <span class="text-[10px] text-ink-400"><%= time_ago(reply.inserted_at) %></span>
              </div>
              <p class="text-xs text-ink-700 mt-0.5"><%= reply.body %></p>
              <div class="flex items-center gap-3 mt-1">
                <button phx-click="toggle_comment_like"
                  phx-value-type={@comment_type}
                  phx-value-id={reply.id}
                  class="flex items-center gap-1 text-[10px] group">
                  <.icon
                    name={if MapSet.member?(@likes_map.liked_ids, reply.id), do: "hero-heart-solid", else: "hero-heart"}
                    class={[
                      "w-3.5 h-3.5 transition-all duration-200",
                      MapSet.member?(@likes_map.liked_ids, reply.id) && "text-accent-red",
                      !MapSet.member?(@likes_map.liked_ids, reply.id) && "text-ink-400 group-hover:text-accent-red/60"
                    ]}
                  />
                  <span :if={reply.like_count > 0} class="tabular-nums text-ink-400">
                    <%= reply.like_count %>
                  </span>
                </button>
                <button phx-click="start_reply"
                  phx-value-id={comment.id}
                  class="text-[10px] text-ink-400 hover:text-ink-600 font-medium">
                  Responder
                </button>
                <button :if={@current_user.id == reply.user_id || @is_admin}
                  phx-click="delete_comment"
                  phx-value-id={reply.id}
                  phx-value-type={@comment_type}
                  data-confirm="Apagar esta resposta?"
                  class="text-[10px] text-ink-300 hover:text-accent-red">
                  <.icon name="hero-trash" class="w-3 h-3" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <%!-- Reply form --%>
        <form :if={@replying_to == comment.id}
          phx-submit="create_reply"
          phx-value-parent-id={comment.id}
          class="flex items-center gap-2 ml-10 mt-1">
          <div class="flex-1 flex items-center gap-2 bg-ink-50 rounded-full px-3 py-1.5">
            <input name="body" placeholder="Responder..."
              class="flex-1 bg-transparent text-sm outline-none text-ink-700"
              maxlength="2000" required
              phx-hook="AutoFocus" id={"reply-input-#{comment.id}"} />
            <button type="submit"
              class="text-accent-orange font-semibold text-sm hover:text-accent-orange/80 flex-shrink-0">
              Enviar
            </button>
          </div>
        </form>
      </div>

      <%!-- New comment form --%>
      <form phx-submit="create_comment"
        class="flex items-center gap-2 pt-3 border-t border-ink-100">
        <div class="flex-1 flex items-center gap-2 bg-ink-50 rounded-full px-4 py-2">
          <input name="body" placeholder="Adicionar comentário..."
            class="flex-1 bg-transparent text-sm outline-none text-ink-700"
            maxlength="2000" required />
          <button type="submit"
            class="text-accent-orange font-semibold text-sm hover:text-accent-orange/80 flex-shrink-0">
            Publicar
          </button>
        </div>
      </form>
    </section>
    """
  end

  defp time_ago(datetime) do
    diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "agora"
      diff < 3600 -> "#{div(diff, 60)}min"
      diff < 86400 -> "#{div(diff, 3600)}h"
      diff < 604_800 -> "#{div(diff, 86400)}d"
      true -> "#{div(diff, 604_800)}sem"
    end
  end
end
```

- [ ] **Step 2: Compile to verify**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors
```

- [ ] **Step 3: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add lib/o_grupo_de_estudos_web/components/ui/comment_thread.ex && git commit -m "feat: CommentThread Instagram-style reusable component"
```

---

### Task 12: StepLive — add comments section

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/step_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/step_live.html.heex`

- [ ] **Step 1: Add comment data loading to StepLive mount**

In `lib/o_grupo_de_estudos_web/live/step_live.ex`, in the `mount` function, after the existing likes loading, add:

```elixir
# Load step comments
step_comments = Engagement.list_step_comments(step.id)
step_comment_ids = Enum.map(step_comments, & &1.id)
step_comment_likes = Engagement.likes_map(current_user.id, "step_comment", step_comment_ids)
```

Add these to the `assign`:
```elixir
step_comments: step_comments,
step_comment_likes: step_comment_likes,
replying_to: nil,
replies_map: %{}
```

Import the CommentThread component at the top:
```elixir
import OGrupoDeEstudosWeb.UI.CommentThread
```

- [ ] **Step 2: Add comment event handlers to StepLive**

Add these handlers:

```elixir
def handle_event("create_comment", %{"body" => body}, socket) do
  user = socket.assigns.current_user
  step = socket.assigns.step

  case Engagement.create_step_comment(user, step.id, %{body: body}) do
    {:ok, _comment} ->
      {:noreply, reload_step_comments(socket)}

    {:error, _changeset} ->
      {:noreply, put_flash(socket, :error, "Não foi possível postar o comentário.")}
  end
end

def handle_event("create_reply", %{"body" => body, "parent-id" => parent_id}, socket) do
  user = socket.assigns.current_user
  step = socket.assigns.step

  case Engagement.create_step_comment(user, step.id, %{
         body: body,
         parent_step_comment_id: parent_id
       }) do
    {:ok, _reply} ->
      {:noreply, socket |> reload_step_comments() |> assign(:replying_to, nil)}

    {:error, _changeset} ->
      {:noreply, put_flash(socket, :error, "Não foi possível postar a resposta.")}
  end
end

def handle_event("toggle_comment_like", %{"type" => type, "id" => id}, socket) do
  user = socket.assigns.current_user

  case Engagement.toggle_like(user.id, type, id) do
    {:ok, _} -> {:noreply, reload_step_comments(socket)}
    {:error, _} -> {:noreply, socket}
  end
end

def handle_event("start_reply", %{"id" => comment_id}, socket) do
  {:noreply, assign(socket, :replying_to, comment_id)}
end

def handle_event("toggle_replies", %{"id" => comment_id}, socket) do
  alias OGrupoDeEstudos.Engagement.Comments.StepCommentQuery
  replies_map = socket.assigns.replies_map

  if Map.has_key?(replies_map, comment_id) do
    {:noreply, assign(socket, :replies_map, Map.delete(replies_map, comment_id))}
  else
    replies = Engagement.list_replies(StepCommentQuery, comment_id)
    {:noreply, assign(socket, :replies_map, Map.put(replies_map, comment_id, replies))}
  end
end

def handle_event("delete_comment", %{"id" => id, "type" => "step_comment"}, socket) do
  user = socket.assigns.current_user
  alias OGrupoDeEstudos.Engagement.Comments.StepComment
  comment = Repo.get!(StepComment, id)

  case Engagement.delete_step_comment(user, comment) do
    {:ok, _} -> {:noreply, reload_step_comments(socket)}
    {:error, _} -> {:noreply, put_flash(socket, :error, "Sem permissão.")}
  end
end
```

Add helper:

```elixir
defp reload_step_comments(socket) do
  step = socket.assigns.step
  user = socket.assigns.current_user

  comments = Engagement.list_step_comments(step.id)
  comment_ids = Enum.map(comments, & &1.id)
  comment_likes = Engagement.likes_map(user.id, "step_comment", comment_ids)

  assign(socket,
    step_comments: comments,
    step_comment_likes: comment_likes
  )
end
```

- [ ] **Step 3: Add comment section to template**

In `lib/o_grupo_de_estudos_web/live/step_live.html.heex`, add the comments section at the end (before the closing `</div>` of the main content):

```heex
<%!-- Comments section --%>
<section class="mt-8 pt-6 border-t border-ink-200">
  <h3 class="text-lg font-serif font-bold text-ink-800 mb-4">
    Comentários
    <span :if={length(@step_comments) > 0} class="text-sm font-sans font-normal text-ink-400 ml-1">
      (<%= length(@step_comments) %>)
    </span>
  </h3>

  <.comment_thread
    comments={@step_comments}
    current_user={@current_user}
    likes_map={@step_comment_likes}
    comment_type="step_comment"
    parent_id={@step.id}
    replying_to={@replying_to}
    replies_map={@replies_map}
    is_admin={@is_admin}
  />
</section>
```

- [ ] **Step 4: Compile and test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

- [ ] **Step 5: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add lib/o_grupo_de_estudos_web/live/step_live.ex lib/o_grupo_de_estudos_web/live/step_live.html.heex && git commit -m "feat: comments section on StepLive with replies + likes"
```

---

### Task 13: Notification bell in navigation

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/components/ui/top_nav.ex`
- Modify: `lib/o_grupo_de_estudos_web/components/ui/bottom_nav.ex`
- Modify: `assets/css/app.css`

- [ ] **Step 1: Add notification_count attr to TopNav**

In `lib/o_grupo_de_estudos_web/components/ui/top_nav.ex`, add attr:

```elixir
attr :notification_count, :integer, default: 0
```

In the desktop nav section (the `<nav class="flex items-center gap-4">` block), before the settings/logout links, add:

```heex
<.link navigate={~p"/notifications"} class="relative group no-underline">
  <.icon name="hero-bell-solid" class={[
    "size-5 transition-colors",
    @notification_count > 0 && "text-accent-orange",
    @notification_count == 0 && "text-ink-400 group-hover:text-ink-200"
  ]} />
  <span :if={@notification_count > 0} class={[
    "absolute -top-1.5 -right-1.5 min-w-[18px] h-[18px] px-0.5",
    "flex items-center justify-center",
    "bg-accent-red text-white text-[10px] font-bold rounded-full",
    "animate-notification-pop"
  ]}>
    <%= if @notification_count > 99, do: "99+", else: @notification_count %>
  </span>
</.link>
```

- [ ] **Step 2: Add notification bell to BottomNav**

In `lib/o_grupo_de_estudos_web/components/ui/bottom_nav.ex`, add attr:

```elixir
attr :notification_count, :integer, default: 0
```

Add a 5th tab for notifications. Update the tabs list in `bottom_nav/1`:

```elixir
tabs = [
  %{label: "Acervo", path: "/collection", icon: "hero-rectangle-stack"},
  %{label: "Mapa", path: "/graph/visual", icon: "hero-map"},
  %{label: "Comunidade", path: "/community", icon: "hero-users"},
  %{label: "Alertas", path: "/notifications", icon: "hero-bell"},
  %{label: "Perfil", path: "/users/#{assigns.current_user.username}", icon: "hero-user-circle"}
]
```

Also add `assigns = assign(assigns, :notification_count, assigns.notification_count)` and update the bell tab to show badge:

In the `<li>` rendering, add a conditional badge for the bell tab:

```heex
<li :for={tab <- @tabs} class="flex-1">
  <.link
    navigate={tab.path}
    data-active={active?(@current_path, tab.path)}
    class={[
      "relative flex flex-col items-center justify-center gap-0.5 h-full w-full no-underline font-sans",
      "text-ink-500 data-[active=true]:text-ink-900"
    ]}
  >
    <.icon name={tab.icon} class="size-6" />
    <span class="text-[10px] leading-none">{tab.label}</span>
    <span :if={tab.path == "/notifications" && @notification_count > 0}
      class={[
        "absolute top-1 right-1/4 min-w-[16px] h-4 px-0.5",
        "flex items-center justify-center",
        "bg-accent-red text-white text-[9px] font-bold rounded-full",
        "animate-notification-pop"
      ]}>
      <%= if @notification_count > 99, do: "99+", else: @notification_count %>
    </span>
  </.link>
</li>
```

- [ ] **Step 3: Add CSS animation**

In `assets/css/app.css`, add at the end (before any `@import` if present):

```css
/* Notification badge pop animation */
@keyframes notification-pop {
  0% { transform: scale(0); opacity: 0; }
  50% { transform: scale(1.3); }
  100% { transform: scale(1); opacity: 1; }
}
.animate-notification-pop {
  animation: notification-pop 0.3s ease-out;
}
```

- [ ] **Step 4: Pass notification_count to nav components**

In every layout/template that renders `<.top_nav>` and `<.bottom_nav>`, add the `notification_count` attr. Find where these are rendered (likely in `layouts/app.html.heex` or in each LiveView template) and add:

```heex
notification_count={assigns[:notification_count] || 0}
```

- [ ] **Step 5: Compile and test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

- [ ] **Step 6: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add lib/o_grupo_de_estudos_web/components/ui/top_nav.ex lib/o_grupo_de_estudos_web/components/ui/bottom_nav.ex assets/css/app.css && git commit -m "feat: notification bell badge in top_nav + bottom_nav with pop animation"
```

---

### Task 14: NotificationsLive page

**Files:**
- Create: `lib/o_grupo_de_estudos_web/live/notifications_live.ex`
- Create: `lib/o_grupo_de_estudos_web/live/notifications_live.html.heex`
- Modify: `lib/o_grupo_de_estudos_web/router.ex`

- [ ] **Step 1: Add route**

In `lib/o_grupo_de_estudos_web/router.ex`, in the authenticated scope (the 3rd scope block), add:

```elixir
live "/notifications", NotificationsLive
```

- [ ] **Step 2: Create NotificationsLive**

Create `lib/o_grupo_de_estudos_web/live/notifications_live.ex`:

```elixir
defmodule OGrupoDeEstudosWeb.NotificationsLive do
  use OGrupoDeEstudosWeb, :live_view
  use OGrupoDeEstudosWeb.NotificationHandlers

  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Engagement.Notifications.Grouper

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    raw = Engagement.list_notifications(user.id, limit: @page_size)
    grouped = Grouper.group(raw)

    {:ok,
     assign(socket,
       page_title: "Notificações",
       raw_notifications: raw,
       notifications: grouped,
       page: 0,
       has_more: length(raw) == @page_size,
       nav_mode: :primary,
       is_admin: OGrupoDeEstudos.Accounts.admin?(user)
     )}
  end

  @impl true
  def handle_event("mark_read", %{"id" => id}, socket) do
    Engagement.mark_as_read(socket.assigns.current_user, id)
    {:noreply, reload_notifications(socket)}
  end

  @impl true
  def handle_event("mark_all_read", _, socket) do
    user = socket.assigns.current_user
    Engagement.mark_all_read(user)

    Phoenix.PubSub.broadcast(
      OGrupoDeEstudos.PubSub,
      "notifications:#{user.id}",
      {:notifications_read, :all}
    )

    {:noreply, reload_notifications(socket)}
  end

  @impl true
  def handle_event("load_more", _, socket) do
    user = socket.assigns.current_user
    page = socket.assigns.page + 1
    more_raw = Engagement.list_notifications(user.id, limit: @page_size, offset: page * @page_size)

    all_raw = socket.assigns.raw_notifications ++ more_raw
    grouped = Grouper.group(all_raw)

    {:noreply,
     assign(socket,
       page: page,
       raw_notifications: all_raw,
       notifications: grouped,
       has_more: length(more_raw) == @page_size
     )}
  end

  defp reload_notifications(socket) do
    user = socket.assigns.current_user
    raw = Engagement.list_notifications(user.id, limit: @page_size)
    grouped = Grouper.group(raw)
    unread = Engagement.unread_count(user.id)

    assign(socket,
      raw_notifications: raw,
      notifications: grouped,
      page: 0,
      has_more: length(raw) == @page_size,
      notification_count: unread
    )
  end
end
```

- [ ] **Step 3: Create the template**

Create `lib/o_grupo_de_estudos_web/live/notifications_live.html.heex`:

```heex
<.top_nav current_user={@current_user} is_admin={@is_admin} nav_mode={@nav_mode}
  notification_count={@notification_count} />

<main class="max-w-2xl mx-auto px-4 pt-4 pb-24 font-sans">
  <div class="flex items-center justify-between mb-4">
    <h1 class="text-xl font-serif font-bold text-ink-800">Notificações</h1>
    <button :if={@notification_count > 0}
      phx-click="mark_all_read"
      class="text-xs text-accent-orange hover:text-accent-orange/80 font-medium">
      Marcar tudo como lido
    </button>
  </div>

  <%= if @notifications == [] do %>
    <div class="flex flex-col items-center justify-center py-16 text-center">
      <.icon name="hero-bell" class="w-12 h-12 text-ink-200 mb-3" />
      <p class="text-ink-500 font-medium">Nenhuma notificação ainda</p>
      <p class="text-ink-400 text-sm mt-1">
        Quando alguém curtir ou responder seus comentários, você verá aqui.
      </p>
    </div>
  <% else %>
    <div class="divide-y divide-ink-100 rounded-lg border border-ink-100 overflow-hidden">
      <div :for={notif <- @notifications} class={[
        "flex items-start gap-3 px-4 py-3 transition-colors",
        !notif.read && "bg-gold-400/8"
      ]}>
        <%!-- Avatar stack --%>
        <div class="relative flex-shrink-0 w-10 h-10">
          <%= for {actor, i} <- Enum.take(notif.actors_data, 3) |> Enum.with_index() do %>
            <div class={[
              "w-7 h-7 rounded-full bg-ink-200 border-2 border-white absolute",
              "flex items-center justify-center text-[10px] font-bold text-ink-500",
              i == 0 && "top-0 left-0 z-20",
              i == 1 && "top-1 left-2 z-10",
              i == 2 && "top-2 left-4 z-0"
            ]}>
              <%= String.first(actor.name || actor.username || "?") %>
            </div>
          <% end %>
        </div>

        <%!-- Content --%>
        <.link navigate={notification_path(notif)}
          phx-click="mark_read" phx-value-id={notif.id}
          class="flex-1 min-w-0 no-underline">
          <p class="text-sm text-ink-700">
            <span class="font-semibold">
              <%= primary_actor_name(notif) %>
            </span>
            <span :if={notif.count > 1} class="text-ink-500">
              e mais <%= notif.count - 1 %>
            </span>
            <span class="text-ink-600"><%= action_text(notif) %></span>
          </p>
          <p class="text-xs text-ink-400 mt-0.5"><%= time_ago(notif.latest_at) %></p>
        </.link>

        <%!-- Unread dot --%>
        <div :if={!notif.read}
          class="w-2.5 h-2.5 rounded-full bg-accent-orange flex-shrink-0 mt-2" />
      </div>
    </div>

    <button :if={@has_more}
      phx-click="load_more"
      class="w-full py-3 text-sm text-accent-orange hover:text-accent-orange/80 font-medium mt-4">
      Carregar mais
    </button>
  <% end %>
</main>

<.bottom_nav current_user={@current_user} current_path={~p"/notifications"}
  notification_count={@notification_count} />
```

Add helper functions in the LiveView module:

```elixir
defp notification_path(%{parent_type: "step", parent_id: id}) do
  # Need to look up step code for the URL
  case OGrupoDeEstudos.Repo.get(OGrupoDeEstudos.Encyclopedia.Step, id) do
    nil -> ~p"/collection"
    step -> ~p"/steps/#{step.code}"
  end
end

defp notification_path(%{parent_type: "sequence", parent_id: _id}),
  do: ~p"/community"

defp notification_path(%{parent_type: "profile", parent_id: id}) do
  case OGrupoDeEstudos.Repo.get(OGrupoDeEstudos.Accounts.User, id) do
    nil -> ~p"/collection"
    user -> ~p"/users/#{user.username}"
  end
end

defp notification_path(_), do: ~p"/collection"

defp primary_actor_name(%{actors_data: [actor | _]}),
  do: actor.name || actor.username

defp primary_actor_name(_), do: "Alguém"

defp action_text(%{action: "liked_comment"}), do: " curtiu seu comentário"
defp action_text(%{action: "replied_comment"}), do: " respondeu ao seu comentário"
defp action_text(%{action: "liked_step"}), do: " curtiu o passo"
defp action_text(%{action: "liked_sequence"}), do: " curtiu a sequência"
defp action_text(_), do: " interagiu"

defp time_ago(datetime) do
  diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), datetime, :second)

  cond do
    diff < 60 -> "agora"
    diff < 3600 -> "#{div(diff, 60)}min"
    diff < 86400 -> "#{div(diff, 3600)}h"
    diff < 604_800 -> "#{div(diff, 86400)}d"
    true -> "#{div(diff, 604_800)}sem"
  end
end
```

- [ ] **Step 4: Compile and test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

- [ ] **Step 5: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add lib/o_grupo_de_estudos_web/live/notifications_live.ex lib/o_grupo_de_estudos_web/live/notifications_live.html.heex lib/o_grupo_de_estudos_web/router.ex && git commit -m "feat: NotificationsLive page with grouped Instagram-style display"
```

---

### Task 15: Community ranking by engagement

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/community_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/community_live.html.heex`

- [ ] **Step 1: Update community_live.ex to sort sequences by like_count**

In `community_live.ex`, wherever sequences are loaded and sorted, change the sort to use `like_count`:

Replace any `Enum.sort_by(sequences, fn seq -> -Map.get(seq_likes.counts, seq.id, 0) end)` with:

```elixir
Enum.sort_by(sequences, fn seq -> {-seq.like_count, seq.inserted_at} end)
```

This uses the denormalized `like_count` field instead of the computed counts — faster, no extra query.

- [ ] **Step 2: Add like_count badge to sequence cards in template**

In `community_live.html.heex`, inside each sequence card, add:

```heex
<div :if={seq.like_count > 0}
  class="flex items-center gap-1 text-xs text-accent-red/80">
  <.icon name="hero-heart-solid" class="w-3.5 h-3.5" />
  <span class="font-medium tabular-nums"><%= seq.like_count %></span>
</div>
```

- [ ] **Step 3: Test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

- [ ] **Step 4: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add lib/o_grupo_de_estudos_web/live/community_live.ex lib/o_grupo_de_estudos_web/live/community_live.html.heex && git commit -m "feat: community ranking by like_count + badge on sequence cards"
```

---

### Task 16: Oban notification cleanup worker

**Files:**
- Create: `lib/o_grupo_de_estudos/workers/notification_cleanup.ex`
- Modify: `config/config.exs`

- [ ] **Step 1: Create the worker**

Create `lib/o_grupo_de_estudos/workers/notification_cleanup.ex`:

```elixir
defmodule OGrupoDeEstudos.Workers.NotificationCleanup do
  @moduledoc """
  Oban worker that purges old read notifications (>90 days).
  Runs weekly via cron. Unread notifications are never deleted.
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 1

  import Ecto.Query
  require Logger

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Engagement.Notifications.Notification

  @impl true
  def perform(_job) do
    cutoff =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-90, :day)
      |> NaiveDateTime.truncate(:second)

    {deleted, _} =
      from(n in Notification,
        where: not is_nil(n.read_at) and n.inserted_at < ^cutoff
      )
      |> Repo.delete_all()

    Logger.info("NotificationCleanup: purged #{deleted} old read notifications")
    :ok
  end
end
```

- [ ] **Step 2: Add maintenance queue + cron job to config**

In `config/config.exs`, update the Oban config:

Change:
```elixir
queues: [email: 10, backup: 1],
```
To:
```elixir
queues: [email: 10, backup: 1, maintenance: 1],
```

Add to the crontab list:
```elixir
{"0 3 * * 0", OGrupoDeEstudos.Workers.NotificationCleanup}
```

- [ ] **Step 3: Test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

- [ ] **Step 4: Commit**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git add lib/o_grupo_de_estudos/workers/notification_cleanup.ex config/config.exs && git commit -m "feat: Oban notification cleanup worker (weekly, >90d read)"
```

---

### Task 17: Gate — full test suite + manual validation

- [ ] **Step 1: Run full test suite**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test
```

Expected: All tests pass, zero failures.

- [ ] **Step 2: Run with warnings**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors
```

Expected: Clean compilation.

- [ ] **Step 3: Manual validation checklist**

Start dev server and verify:
```bash
cd /Users/tavano/projects/personal/forrozin_page && mix phx.server
```

Check:
- [ ] `/steps/:code` shows comments section at bottom
- [ ] Can post a new comment
- [ ] Can reply to a comment
- [ ] Can like/unlike a comment (heart toggles)
- [ ] Can delete own comment
- [ ] Deleted comment with replies shows "Comentário removido"
- [ ] Deleted comment without replies disappears
- [ ] Bell icon appears in top_nav and bottom_nav
- [ ] Bell shows orange + count when unread notifications exist
- [ ] `/notifications` page shows grouped notifications
- [ ] "Marcar tudo como lido" clears badge
- [ ] `/community` sequences sorted by like_count
- [ ] Sequence cards show heart badge when liked

- [ ] **Step 4: Push to production (user decision)**

```bash
cd /Users/tavano/projects/personal/forrozin_page && git push origin main && fly deploy
```
