# Suggestions Wiki-Style — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable any user to suggest edits to step fields and graph connections, with admin approval workflow, notifications, and public "last edited by" attribution.

**Architecture:** New `suggestions` table with polymorphic target (step/connection). `Suggestions` context handles CRUD + approval transaction (update suggestion + apply change + notify). Admin dashboard groups pending suggestions by type. StepLive gets inline pencil icons for suggestion forms. Dispatcher expanded with suggestion_approved/rejected actions.

**Tech Stack:** Phoenix 1.7, LiveView 1.0+, Ecto 3.10, PostgreSQL 17, Tailwind v4

**Spec:** `docs/superpowers/specs/2026-04-17-suggestions-wiki-style-design.md`

---

## File Structure

### Create

| File | Responsibility |
|------|---------------|
| `priv/repo/migrations/TIMESTAMP_create_suggestions.exs` | Suggestions table + indices |
| `priv/repo/migrations/TIMESTAMP_add_last_edited_to_steps.exs` | last_edited_by_id + last_edited_at on steps |
| `lib/o_grupo_de_estudos/suggestions/suggestion.ex` | Ecto schema |
| `lib/o_grupo_de_estudos/suggestions/suggestion_query.ex` | Query reducers |
| `lib/o_grupo_de_estudos/suggestions.ex` | Context: create, approve, reject, list |
| `lib/o_grupo_de_estudos_web/live/admin_suggestions_live.ex` | Admin dashboard LiveView |
| `lib/o_grupo_de_estudos_web/live/admin_suggestions_live.html.heex` | Admin dashboard template |
| `test/o_grupo_de_estudos/suggestions_test.exs` | Context tests |
| `test/o_grupo_de_estudos_web/live/admin_suggestions_live_test.exs` | LiveView tests |

### Modify

| File | Change |
|------|--------|
| `lib/o_grupo_de_estudos/encyclopedia/step.ex` | Add last_edited_by_id, last_edited_at fields |
| `lib/o_grupo_de_estudos_web/live/step_live.ex` | Pencil icons, suggestion form handlers, last edited by display |
| `lib/o_grupo_de_estudos_web/live/step_live.html.heex` | Inline suggestion UI |
| `lib/o_grupo_de_estudos_web/live/user_profile_live.ex` | Contributions tab |
| `lib/o_grupo_de_estudos_web/live/user_profile_live.html.heex` | Contributions list |
| `lib/o_grupo_de_estudos/engagement/notifications/dispatcher.ex` | suggestion_reviewed notification |
| `lib/o_grupo_de_estudos/engagement/notifications/notification.ex` | New valid actions |
| `lib/o_grupo_de_estudos_web/live/notifications_live.ex` | action_text for suggestions |
| `lib/o_grupo_de_estudos_web/components/ui/top_nav.ex` | Admin suggestions link |
| `lib/o_grupo_de_estudos_web/router.ex` | /admin/suggestions route |
| `test/support/factory.ex` | suggestion factory |

---

### Task 1: Migrations + Schema + Factory

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_suggestions.exs`
- Create: `priv/repo/migrations/TIMESTAMP_add_last_edited_to_steps.exs`
- Create: `lib/o_grupo_de_estudos/suggestions/suggestion.ex`
- Create: `lib/o_grupo_de_estudos/suggestions/suggestion_query.ex`
- Modify: `lib/o_grupo_de_estudos/encyclopedia/step.ex`
- Modify: `test/support/factory.ex`

- [ ] **Step 1: Generate migrations**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.gen.migration create_suggestions && mix ecto.gen.migration add_last_edited_to_steps
```

- [ ] **Step 2: Write create_suggestions migration**

```elixir
defmodule OGrupoDeEstudos.Repo.Migrations.CreateSuggestions do
  use Ecto.Migration

  def change do
    create table(:suggestions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :target_type, :string, null: false
      add :target_id, :binary_id, null: false
      add :action, :string, null: false
      add :field, :string
      add :old_value, :text
      add :new_value, :text
      add :status, :string, null: false, default: "pending"
      add :reviewed_at, :naive_datetime

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :reviewed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:suggestions, [:status, :inserted_at])
    create index(:suggestions, [:user_id, :inserted_at])
    create index(:suggestions, [:target_type, :target_id])
  end
end
```

- [ ] **Step 3: Write add_last_edited_to_steps migration**

```elixir
defmodule OGrupoDeEstudos.Repo.Migrations.AddLastEditedToSteps do
  use Ecto.Migration

  def change do
    alter table(:steps) do
      add :last_edited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :last_edited_at, :naive_datetime
    end
  end
end
```

- [ ] **Step 4: Create Suggestion schema**

Create `lib/o_grupo_de_estudos/suggestions/suggestion.ex`:

```elixir
defmodule OGrupoDeEstudos.Suggestions.Suggestion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_target_types ~w(step connection)
  @valid_actions ~w(edit_field create_connection remove_connection)
  @valid_statuses ~w(pending approved rejected)
  @valid_fields ~w(name note category_id)

  schema "suggestions" do
    field :target_type, :string
    field :target_id, :binary_id
    field :action, :string
    field :field, :string
    field :old_value, :string
    field :new_value, :string
    field :status, :string, default: "pending"
    field :reviewed_at, :naive_datetime

    belongs_to :user, OGrupoDeEstudos.Accounts.User
    belongs_to :reviewed_by, OGrupoDeEstudos.Accounts.User

    timestamps()
  end

  def changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [:target_type, :target_id, :action, :field, :old_value, :new_value, :user_id])
    |> validate_required([:target_type, :target_id, :action, :user_id])
    |> validate_inclusion(:target_type, @valid_target_types)
    |> validate_inclusion(:action, @valid_actions)
    |> validate_field_when_edit()
    |> foreign_key_constraint(:user_id)
  end

  def review_changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [:status, :reviewed_by_id, :reviewed_at])
    |> validate_required([:status, :reviewed_by_id, :reviewed_at])
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:reviewed_by_id)
  end

  defp validate_field_when_edit(changeset) do
    action = get_field(changeset, :action)

    if action == "edit_field" do
      changeset
      |> validate_required([:field, :new_value])
      |> validate_inclusion(:field, @valid_fields)
    else
      changeset
    end
  end
end
```

- [ ] **Step 5: Create SuggestionQuery**

Create `lib/o_grupo_de_estudos/suggestions/suggestion_query.ex`:

```elixir
defmodule OGrupoDeEstudos.Suggestions.SuggestionQuery do
  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Suggestions.Suggestion

  def list_by(opts \\ []) do
    Suggestion
    |> apply_filters(opts)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
    |> maybe_preload(Keyword.get(opts, :preload, []))
  end

  def count_by(opts \\ []) do
    Suggestion
    |> apply_filters(opts)
    |> Repo.aggregate(:count)
  end

  def get(id) do
    Repo.get(Suggestion, id)
    |> Repo.preload([:user, :reviewed_by])
  end

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, &apply_filter/2)
  end

  defp apply_filter({:status, status}, query),
    do: where(query, [s], s.status == ^status)

  defp apply_filter({:user_id, id}, query),
    do: where(query, [s], s.user_id == ^id)

  defp apply_filter({:target_type, type}, query),
    do: where(query, [s], s.target_type == ^type)

  defp apply_filter({:action, action}, query),
    do: where(query, [s], s.action == ^action)

  defp apply_filter({:limit, n}, query),
    do: limit(query, ^n)

  defp apply_filter(_other, query), do: query

  defp maybe_preload(results, []), do: results
  defp maybe_preload(results, preloads) when is_list(results), do: Repo.preload(results, preloads)
  defp maybe_preload(nil, _), do: nil
  defp maybe_preload(result, preloads), do: Repo.preload(result, preloads)
end
```

- [ ] **Step 6: Update Step schema**

In `lib/o_grupo_de_estudos/encyclopedia/step.ex`:
- Add to `@optional_fields`: `:last_edited_by_id`, `:last_edited_at`
- Add to schema: `field :last_edited_at, :naive_datetime` and `belongs_to :last_edited_by, OGrupoDeEstudos.Accounts.User`

- [ ] **Step 7: Add factory**

In `test/support/factory.ex`:

```elixir
alias OGrupoDeEstudos.Suggestions.Suggestion

def suggestion_factory do
  %Suggestion{
    target_type: "step",
    target_id: Ecto.UUID.generate(),
    action: "edit_field",
    field: "name",
    old_value: "Old Name",
    new_value: "New Name",
    status: "pending",
    user: build(:user)
  }
end
```

- [ ] **Step 8: Run migrations + tests**

```bash
mix ecto.migrate && mix test
```

- [ ] **Step 9: Commit**

```bash
git add priv/repo/migrations/*suggestions* priv/repo/migrations/*last_edited* lib/o_grupo_de_estudos/suggestions/ lib/o_grupo_de_estudos/encyclopedia/step.ex test/support/factory.ex && git commit -m "feat: create suggestions table + schema + last_edited_by on steps"
```

---

### Task 2: Suggestions context + TDD

**Files:**
- Create: `lib/o_grupo_de_estudos/suggestions.ex`
- Create: `test/o_grupo_de_estudos/suggestions_test.exs`

- [ ] **Step 1: Write failing tests**

Create `test/o_grupo_de_estudos/suggestions_test.exs`:

```elixir
defmodule OGrupoDeEstudos.SuggestionsTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Suggestions
  alias OGrupoDeEstudos.Suggestions.Suggestion

  setup do
    user = insert(:user)
    admin = insert(:admin)
    step = insert(:step)
    %{user: user, admin: admin, step: step}
  end

  describe "create/2" do
    test "creates a pending suggestion for edit_field", %{user: user, step: step} do
      {:ok, suggestion} = Suggestions.create(user, %{
        target_type: "step",
        target_id: step.id,
        action: "edit_field",
        field: "name",
        old_value: step.name,
        new_value: "Novo Nome"
      })

      assert suggestion.status == "pending"
      assert suggestion.user_id == user.id
      assert suggestion.new_value == "Novo Nome"
    end

    test "creates suggestion for create_connection", %{user: user, step: step} do
      other = insert(:step)
      {:ok, suggestion} = Suggestions.create(user, %{
        target_type: "connection",
        target_id: step.id,
        action: "create_connection",
        new_value: "#{step.code}→#{other.code}"
      })

      assert suggestion.action == "create_connection"
    end

    test "creates suggestion for remove_connection", %{user: user, step: step} do
      connection = insert(:connection, source_step: step)
      {:ok, suggestion} = Suggestions.create(user, %{
        target_type: "connection",
        target_id: connection.id,
        action: "remove_connection",
        old_value: "#{step.code}→#{connection.target_step.code}"
      })

      assert suggestion.action == "remove_connection"
    end

    test "rejects invalid action", %{user: user, step: step} do
      {:error, changeset} = Suggestions.create(user, %{
        target_type: "step",
        target_id: step.id,
        action: "hack_system"
      })

      assert errors_on(changeset).action
    end

    test "requires field for edit_field action", %{user: user, step: step} do
      {:error, changeset} = Suggestions.create(user, %{
        target_type: "step",
        target_id: step.id,
        action: "edit_field",
        new_value: "test"
      })

      assert errors_on(changeset).field
    end
  end

  describe "approve/2" do
    test "approves and applies edit_field suggestion", %{user: user, admin: admin, step: step} do
      {:ok, suggestion} = Suggestions.create(user, %{
        target_type: "step",
        target_id: step.id,
        action: "edit_field",
        field: "name",
        old_value: step.name,
        new_value: "Nome Atualizado"
      })

      {:ok, approved} = Suggestions.approve(suggestion, admin)

      assert approved.status == "approved"
      assert approved.reviewed_by_id == admin.id
      assert approved.reviewed_at != nil

      # Step should be updated
      updated_step = Repo.get!(OGrupoDeEstudos.Encyclopedia.Step, step.id)
      assert updated_step.name == "Nome Atualizado"
      assert updated_step.last_edited_by_id == user.id
      assert updated_step.last_edited_at != nil
    end

    test "approves and applies create_connection suggestion", %{user: user, admin: admin} do
      source = insert(:step)
      target = insert(:step)

      {:ok, suggestion} = Suggestions.create(user, %{
        target_type: "connection",
        target_id: source.id,
        action: "create_connection",
        new_value: "#{source.code}→#{target.code}"
      })

      {:ok, _approved} = Suggestions.approve(suggestion, admin)

      # Connection should exist
      conn = OGrupoDeEstudos.Encyclopedia.ConnectionQuery.get_by(
        source_step_id: source.id,
        target_step_id: target.id
      )
      assert conn != nil
    end

    test "approves and applies remove_connection suggestion", %{user: user, admin: admin} do
      connection = insert(:connection)

      {:ok, suggestion} = Suggestions.create(user, %{
        target_type: "connection",
        target_id: connection.id,
        action: "remove_connection",
        old_value: "#{connection.source_step.code}→#{connection.target_step.code}"
      })

      {:ok, _approved} = Suggestions.approve(suggestion, admin)

      # Connection should be soft-deleted
      deleted_conn = Repo.get(OGrupoDeEstudos.Encyclopedia.Connection, connection.id)
      assert deleted_conn.deleted_at != nil
    end
  end

  describe "reject/2" do
    test "rejects a suggestion", %{user: user, admin: admin, step: step} do
      {:ok, suggestion} = Suggestions.create(user, %{
        target_type: "step",
        target_id: step.id,
        action: "edit_field",
        field: "name",
        old_value: step.name,
        new_value: "Rejected Name"
      })

      {:ok, rejected} = Suggestions.reject(suggestion, admin)

      assert rejected.status == "rejected"
      assert rejected.reviewed_by_id == admin.id

      # Step should NOT be updated
      unchanged = Repo.get!(OGrupoDeEstudos.Encyclopedia.Step, step.id)
      assert unchanged.name == step.name
    end
  end

  describe "list_pending/1" do
    test "returns only pending suggestions", %{user: user, admin: admin, step: step} do
      {:ok, s1} = Suggestions.create(user, %{
        target_type: "step", target_id: step.id,
        action: "edit_field", field: "name",
        old_value: step.name, new_value: "A"
      })
      {:ok, s2} = Suggestions.create(user, %{
        target_type: "step", target_id: step.id,
        action: "edit_field", field: "note",
        old_value: step.note || "", new_value: "B"
      })

      Suggestions.approve(s1, admin)

      pending = Suggestions.list_pending()
      assert length(pending) == 1
      assert hd(pending).id == s2.id
    end
  end

  describe "list_by_user/2" do
    test "returns suggestions by user", %{user: user, step: step} do
      {:ok, _} = Suggestions.create(user, %{
        target_type: "step", target_id: step.id,
        action: "edit_field", field: "name",
        old_value: step.name, new_value: "Test"
      })

      other = insert(:user)
      {:ok, _} = Suggestions.create(other, %{
        target_type: "step", target_id: step.id,
        action: "edit_field", field: "name",
        old_value: step.name, new_value: "Other"
      })

      result = Suggestions.list_by_user(user.id)
      assert length(result) == 1
    end
  end

  describe "count_pending/0" do
    test "counts pending suggestions", %{user: user, step: step} do
      {:ok, _} = Suggestions.create(user, %{
        target_type: "step", target_id: step.id,
        action: "edit_field", field: "name",
        old_value: step.name, new_value: "X"
      })

      assert Suggestions.count_pending() == 1
    end
  end
end
```

- [ ] **Step 2: Run tests to see failures**

```bash
mix test test/o_grupo_de_estudos/suggestions_test.exs
```

- [ ] **Step 3: Implement Suggestions context**

Create `lib/o_grupo_de_estudos/suggestions.ex`:

```elixir
defmodule OGrupoDeEstudos.Suggestions do
  @moduledoc """
  Wikipedia-style suggestion system. Any user can suggest edits
  to steps (name, note, category) and connections (create, remove).
  Admin approves/rejects. Approved suggestions are applied atomically.
  """

  alias Ecto.Multi
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Admin
  alias OGrupoDeEstudos.Encyclopedia.{Step, StepQuery, ConnectionQuery}
  alias OGrupoDeEstudos.Suggestions.{Suggestion, SuggestionQuery}
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher

  def create(user, attrs) do
    %Suggestion{}
    |> Suggestion.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  def approve(suggestion, admin) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Multi.new()
    |> Multi.update(:suggestion, Suggestion.review_changeset(suggestion, %{
      status: "approved",
      reviewed_by_id: admin.id,
      reviewed_at: now
    }))
    |> Multi.run(:apply, fn _repo, %{suggestion: s} ->
      apply_suggestion(s)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{suggestion: s}} ->
        safe_notify(:suggestion_reviewed, s, admin)
        {:ok, s}

      {:error, :suggestion, changeset, _} ->
        {:error, changeset}

      {:error, :apply, reason, _} ->
        {:error, reason}
    end
  end

  def reject(suggestion, admin) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    suggestion
    |> Suggestion.review_changeset(%{
      status: "rejected",
      reviewed_by_id: admin.id,
      reviewed_at: now
    })
    |> Repo.update()
    |> case do
      {:ok, s} ->
        safe_notify(:suggestion_reviewed, s, admin)
        {:ok, s}

      error ->
        error
    end
  end

  def list_pending(opts \\ []) do
    SuggestionQuery.list_by([status: "pending", preload: [:user]] ++ opts)
  end

  def list_by_user(user_id, opts \\ []) do
    SuggestionQuery.list_by([user_id: user_id, preload: [:user, :reviewed_by]] ++ opts)
  end

  def count_pending do
    SuggestionQuery.count_by(status: "pending")
  end

  def get(id) do
    SuggestionQuery.get(id)
  end

  # --- Apply suggestion ---

  defp apply_suggestion(%{action: "edit_field"} = s) do
    step = Repo.get(Step, s.target_id)

    if step do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      field_atom = String.to_existing_atom(s.field)

      Admin.update_step(step, %{
        field_atom => s.new_value,
        :last_edited_by_id => s.user_id,
        :last_edited_at => now
      })
    else
      {:error, :step_not_found}
    end
  end

  defp apply_suggestion(%{action: "create_connection"} = s) do
    case String.split(s.new_value, "→") do
      [source_code, target_code] ->
        source = StepQuery.get_by(code: String.trim(source_code))
        target = StepQuery.get_by(code: String.trim(target_code))

        if source && target do
          Admin.create_connection(%{source_step_id: source.id, target_step_id: target.id})
        else
          {:error, :steps_not_found}
        end

      _ ->
        {:error, :invalid_connection_format}
    end
  end

  defp apply_suggestion(%{action: "remove_connection"} = s) do
    Admin.delete_connection(s.target_id)
  end

  defp safe_notify(action, suggestion, admin) do
    Dispatcher.notify_suggestion(action, suggestion, admin)
  rescue
    _ -> :ok
  end
end
```

- [ ] **Step 4: Run tests**

```bash
mix test test/o_grupo_de_estudos/suggestions_test.exs && mix test
```

- [ ] **Step 5: Commit**

```bash
git add lib/o_grupo_de_estudos/suggestions.ex test/o_grupo_de_estudos/suggestions_test.exs && git commit -m "feat: Suggestions context — create, approve (atomic apply), reject, list with TDD"
```

---

### Task 3: Dispatcher + Notification expansion

**Files:**
- Modify: `lib/o_grupo_de_estudos/engagement/notifications/dispatcher.ex`
- Modify: `lib/o_grupo_de_estudos/engagement/notifications/notification.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/notifications_live.ex`

- [ ] **Step 1: Add valid actions to Notification schema**

In `notification.ex`, expand `@valid_actions`:

```elixir
@valid_actions ~w(liked_comment replied_comment liked_step liked_sequence suggestion_approved suggestion_rejected)
```

Add to `@valid_target_types`:
```elixir
@valid_target_types ~w(step_comment sequence_comment profile_comment step sequence suggestion)
```

- [ ] **Step 2: Add notify_suggestion to Dispatcher**

In `dispatcher.ex`, add:

```elixir
def notify_suggestion(:suggestion_reviewed, suggestion, admin) do
  action = case suggestion.status do
    "approved" -> "suggestion_approved"
    "rejected" -> "suggestion_rejected"
  end

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
      parent_type: suggestion.target_type,
      parent_id: suggestion.target_id,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end)
end
```

- [ ] **Step 3: Add action_text to NotificationsLive**

In `notifications_live.ex`, add to `action_text/1`:

```elixir
defp action_text(%{action: "suggestion_approved"}), do: " aprovou sua sugestão ✓"
defp action_text(%{action: "suggestion_rejected"}), do: " rejeitou sua sugestão"
```

- [ ] **Step 4: Compile + test**

```bash
mix compile --warnings-as-errors && mix test
```

- [ ] **Step 5: Commit**

```bash
git add lib/o_grupo_de_estudos/engagement/notifications/ lib/o_grupo_de_estudos_web/live/notifications_live.ex && git commit -m "feat: suggestion_approved/rejected notification types + dispatcher"
```

---

### Task 4: AdminSuggestionsLive + route + nav

**Files:**
- Create: `lib/o_grupo_de_estudos_web/live/admin_suggestions_live.ex`
- Create: `lib/o_grupo_de_estudos_web/live/admin_suggestions_live.html.heex`
- Modify: `lib/o_grupo_de_estudos_web/router.ex`
- Modify: `lib/o_grupo_de_estudos_web/components/ui/top_nav.ex`

- [ ] **Step 1: Add route**

In `router.ex`, add in the authenticated scope:

```elixir
live "/admin/suggestions", AdminSuggestionsLive
```

- [ ] **Step 2: Add nav link for admin**

In `top_nav.ex`, in the admin links section (where `/admin/links` and `/admin/backups` are), add:

```heex
<.link navigate={~p"/admin/suggestions"} class="text-xs text-ink-400 hover:text-ink-100 tracking-[0.5px] no-underline">
  Sugestões
  <span :if={assigns[:pending_suggestions_count] && assigns[:pending_suggestions_count] > 0}
    class="ml-1 inline-flex items-center justify-center min-w-[18px] h-[18px] px-1 bg-accent-red text-white text-[10px] font-bold rounded-full">
    {assigns[:pending_suggestions_count]}
  </span>
</.link>
```

Add `attr :pending_suggestions_count, :integer, default: 0` to the top_nav component.

- [ ] **Step 3: Create AdminSuggestionsLive**

Create `lib/o_grupo_de_estudos_web/live/admin_suggestions_live.ex`:

```elixir
defmodule OGrupoDeEstudosWeb.AdminSuggestionsLive do
  use OGrupoDeEstudosWeb, :live_view
  use OGrupoDeEstudosWeb.NotificationHandlers

  alias OGrupoDeEstudos.{Accounts, Suggestions}

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    unless Accounts.admin?(user) do
      {:ok, socket |> put_flash(:error, "Acesso restrito") |> redirect(to: ~p"/collection")}
    else
      pending = Suggestions.list_pending()

      # Group by action type
      edit_fields = Enum.filter(pending, &(&1.action == "edit_field"))
      create_connections = Enum.filter(pending, &(&1.action == "create_connection"))
      remove_connections = Enum.filter(pending, &(&1.action == "remove_connection"))

      {:ok,
       assign(socket,
         page_title: "Sugestões",
         is_admin: true,
         nav_mode: :primary,
         filter: "pending",
         suggestions: pending,
         edit_fields: edit_fields,
         create_connections: create_connections,
         remove_connections: remove_connections,
         pending_count: length(pending)
       )}
    end
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    suggestion = Suggestions.get(id)
    admin = socket.assigns.current_user

    if suggestion && Accounts.admin?(admin) do
      case Suggestions.approve(suggestion, admin) do
        {:ok, _} ->
          {:noreply, socket |> reload_suggestions() |> put_flash(:info, "Sugestão aprovada ✓")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erro ao aprovar")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reject", %{"id" => id}, socket) do
    suggestion = Suggestions.get(id)
    admin = socket.assigns.current_user

    if suggestion && Accounts.admin?(admin) do
      case Suggestions.reject(suggestion, admin) do
        {:ok, _} ->
          {:noreply, socket |> reload_suggestions() |> put_flash(:info, "Sugestão rejeitada")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erro ao rejeitar")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    suggestions = case status do
      "pending" -> Suggestions.list_pending()
      "all" -> OGrupoDeEstudos.Suggestions.SuggestionQuery.list_by(preload: [:user, :reviewed_by])
    end

    edit_fields = Enum.filter(suggestions, &(&1.action == "edit_field"))
    create_connections = Enum.filter(suggestions, &(&1.action == "create_connection"))
    remove_connections = Enum.filter(suggestions, &(&1.action == "remove_connection"))

    {:noreply, assign(socket,
      filter: status,
      suggestions: suggestions,
      edit_fields: edit_fields,
      create_connections: create_connections,
      remove_connections: remove_connections
    )}
  end

  defp reload_suggestions(socket) do
    pending = Suggestions.list_pending()
    edit_fields = Enum.filter(pending, &(&1.action == "edit_field"))
    create_connections = Enum.filter(pending, &(&1.action == "create_connection"))
    remove_connections = Enum.filter(pending, &(&1.action == "remove_connection"))

    assign(socket,
      filter: "pending",
      suggestions: pending,
      edit_fields: edit_fields,
      create_connections: create_connections,
      remove_connections: remove_connections,
      pending_count: length(pending)
    )
  end
end
```

- [ ] **Step 4: Create template**

Create `lib/o_grupo_de_estudos_web/live/admin_suggestions_live.html.heex` with:
- Top nav + title "Sugestões"
- Filter tabs: Pendentes / Todas
- 3 sections grouped by type: Edições de campo, Novas conexões, Remoções de conexão
- Each suggestion card: @username link, field/value diff, link to step, Approve/Reject buttons
- Empty state per section

The template should follow the app's design tokens (ink-*, gold-*, accent-*).

- [ ] **Step 5: Compile + test**

```bash
mix compile --warnings-as-errors && mix test
```

- [ ] **Step 6: Commit**

```bash
git add lib/o_grupo_de_estudos_web/live/admin_suggestions_live* lib/o_grupo_de_estudos_web/router.ex lib/o_grupo_de_estudos_web/components/ui/top_nav.ex && git commit -m "feat: AdminSuggestionsLive — grouped list, approve/reject, nav badge"
```

---

### Task 5: StepLive — pencil icons + inline suggestion forms + "last edited by"

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/step_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/step_live.html.heex`

- [ ] **Step 1: Add suggestion assigns to mount**

In `step_live.ex` mount, add:

```elixir
alias OGrupoDeEstudos.Suggestions

suggesting_field: nil,    # which field is being edited ("name", "note", "category_id", nil)
suggestion_value: "",      # current value in the suggestion input
suggesting_connection: false,  # showing new connection form?
connection_suggest_search: "",
connection_suggest_results: []
```

Also preload `last_edited_by` on the step:
```elixir
step = StepQuery.get_by(code: code, preload: [:suggested_by, :category, :technical_concepts, :last_edited_by])
```

- [ ] **Step 2: Add suggestion event handlers**

```elixir
# Open inline suggestion form for a field
def handle_event("start_suggest", %{"field" => field}, socket) do
  step = socket.assigns.step
  current_value = Map.get(step, String.to_existing_atom(field)) || ""
  {:noreply, assign(socket, suggesting_field: field, suggestion_value: to_string(current_value))}
end

def handle_event("cancel_suggest", _, socket) do
  {:noreply, assign(socket, suggesting_field: nil, suggestion_value: "")}
end

def handle_event("submit_suggestion", %{"value" => new_value}, socket) do
  user = socket.assigns.current_user
  step = socket.assigns.step
  field = socket.assigns.suggesting_field
  old_value = Map.get(step, String.to_existing_atom(field)) || ""

  case Suggestions.create(user, %{
    target_type: "step",
    target_id: step.id,
    action: "edit_field",
    field: field,
    old_value: to_string(old_value),
    new_value: new_value
  }) do
    {:ok, _} ->
      {:noreply,
       socket
       |> assign(suggesting_field: nil, suggestion_value: "")
       |> put_flash(:info, "Sugestão enviada! Um admin vai revisar.")}
    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Erro ao enviar sugestão")}
  end
end

# Suggest new connection
def handle_event("start_suggest_connection", _, socket) do
  {:noreply, assign(socket, suggesting_connection: true)}
end

def handle_event("cancel_suggest_connection", _, socket) do
  {:noreply, assign(socket, suggesting_connection: false, connection_suggest_search: "", connection_suggest_results: [])}
end

def handle_event("search_suggest_connection", params, socket) do
  term = params["value"] || params["term"] || ""
  results = if String.length(term) >= 1 do
    StepQuery.list_by(status: "published", search: term, order_by: [asc: :name], limit: 8, preload: [:category])
  else
    []
  end
  {:noreply, assign(socket, connection_suggest_search: term, connection_suggest_results: results)}
end

def handle_event("submit_connection_suggestion", %{"target_code" => target_code}, socket) do
  user = socket.assigns.current_user
  step = socket.assigns.step

  case Suggestions.create(user, %{
    target_type: "connection",
    target_id: step.id,
    action: "create_connection",
    new_value: "#{step.code}→#{target_code}"
  }) do
    {:ok, _} ->
      {:noreply,
       socket
       |> assign(suggesting_connection: false, connection_suggest_search: "", connection_suggest_results: [])
       |> put_flash(:info, "Sugestão de conexão enviada!")}
    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Erro ao sugerir conexão")}
  end
end

# Suggest removing a connection
def handle_event("suggest_remove_connection", %{"id" => conn_id, "label" => label}, socket) do
  user = socket.assigns.current_user

  case Suggestions.create(user, %{
    target_type: "connection",
    target_id: conn_id,
    action: "remove_connection",
    old_value: label
  }) do
    {:ok, _} ->
      {:noreply, put_flash(socket, :info, "Sugestão de remoção enviada!")}
    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Erro ao sugerir remoção")}
  end
end
```

- [ ] **Step 3: Update template**

In `step_live.html.heex`:

**Pencil icon next to each editable field** (name, note, category):
```heex
<%!-- Next to step name --%>
<button :if={!@suggesting_field || @suggesting_field != "name"}
  phx-click="start_suggest" phx-value-field="name"
  class="inline-flex p-0.5 text-ink-300 hover:text-accent-orange transition-colors"
  title="Sugerir edição">
  <.icon name="hero-pencil-square" class="w-3.5 h-3.5" />
</button>
```

**Inline suggestion form** (shown when `@suggesting_field == "name"`):
```heex
<%= if @suggesting_field == "name" do %>
  <form phx-submit="submit_suggestion" class="flex items-center gap-2 mt-1">
    <input name="value" value={@suggestion_value} required
      class="flex-1 px-2 py-1.5 border border-accent-orange/40 rounded text-sm text-ink-800 bg-ink-50" />
    <button type="submit" class="text-xs bg-accent-orange text-white px-3 py-1.5 rounded font-medium">Enviar</button>
    <button type="button" phx-click="cancel_suggest" class="text-xs text-ink-400 px-2 py-1.5">Cancelar</button>
  </form>
<% end %>
```

**"Last edited by"** below the note:
```heex
<%= if @step.last_edited_by_id do %>
  <div class="flex items-center gap-1.5 mt-2 text-xs text-ink-400">
    <.icon name="hero-pencil" class="w-3 h-3" />
    <span>Editado por</span>
    <.link navigate={~p"/users/#{@step.last_edited_by.username}"}
      class="text-accent-orange font-medium no-underline hover:underline">
      @{@step.last_edited_by.username}
    </.link>
    <span>· {time_ago(@step.last_edited_at)}</span>
  </div>
<% end %>
```

**Connection suggestion** in the connections section:
- × button next to each connection for "suggest removal"
- "+ Sugerir conexão" button at bottom with autocomplete

- [ ] **Step 4: Compile + test**

```bash
mix compile --warnings-as-errors && mix test
```

- [ ] **Step 5: Commit**

```bash
git add lib/o_grupo_de_estudos_web/live/step_live* && git commit -m "feat: pencil icons + inline suggestion forms + last edited by on StepLive"
```

---

### Task 6: UserProfileLive — Contributions tab

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/user_profile_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/user_profile_live.html.heex`

- [ ] **Step 1: Add contributions data**

In `user_profile_live.ex`, add to mount assigns:
```elixir
contributions: []
```

Add handler for tab:
```elixir
def handle_event("switch_profile_tab", %{"tab" => "contributions"}, socket) do
  profile_user = socket.assigns.profile_user
  contributions = OGrupoDeEstudos.Suggestions.list_by_user(profile_user.id)
  {:noreply, assign(socket, profile_tab: "contributions", contributions: contributions)}
end
```

- [ ] **Step 2: Add Contributions tab to template**

Add "Contribuições" to the tab switcher. In the content area:

```heex
<%= if @profile_tab == "contributions" do %>
  <div class="px-4">
    <%= if @contributions == [] do %>
      <p class="text-sm text-ink-400 italic py-8 text-center">Nenhuma contribuição ainda.</p>
    <% else %>
      <div class="space-y-2">
        <%= for s <- @contributions do %>
          <div class={[
            "flex items-start gap-3 p-3 rounded-lg border",
            s.status == "pending" && "bg-gold-500/5 border-gold-500/20",
            s.status == "approved" && "bg-accent-green/5 border-accent-green/20",
            s.status == "rejected" && "bg-accent-red/5 border-accent-red/20"
          ]}>
            <span class="text-sm mt-0.5">
              <%= case s.status do %>
                <% "pending" -> %>🟡
                <% "approved" -> %>🟢
                <% "rejected" -> %>🔴
              <% end %>
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-sm text-ink-700">
                <%= case s.action do %>
                  <% "edit_field" -> %>
                    Edição de <span class="font-semibold">{s.field}</span>:
                    "<span class="text-ink-400 line-through">{s.old_value}</span>" →
                    "<span class="text-accent-orange font-medium">{s.new_value}</span>"
                  <% "create_connection" -> %>
                    Nova conexão: <span class="font-semibold text-accent-orange">{s.new_value}</span>
                  <% "remove_connection" -> %>
                    Remover conexão: <span class="font-semibold text-accent-red line-through">{s.old_value}</span>
                <% end %>
              </p>
              <p class="text-xs text-ink-400 mt-0.5">
                {time_ago(s.inserted_at)}
                <%= if s.reviewed_by do %>
                  · revisado por @{s.reviewed_by.username}
                <% end %>
              </p>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 3: Compile + test**

```bash
mix compile --warnings-as-errors && mix test
```

- [ ] **Step 4: Commit**

```bash
git add lib/o_grupo_de_estudos_web/live/user_profile_live* && git commit -m "feat: Contributions tab on profile showing suggestion history"
```

---

### Task 7: Gate — tests + manual validation

- [ ] **Step 1: Run full test suite**

```bash
mix test
```

- [ ] **Step 2: Manual validation**

```bash
mix phx.server
```

Check:
- [ ] Admin sees "Sugestões" link in top nav with pending count badge
- [ ] `/admin/suggestions` shows grouped pending suggestions
- [ ] Non-admin gets redirected from `/admin/suggestions`
- [ ] Step page shows pencil icons next to name, note, category
- [ ] Clicking pencil opens inline suggestion form
- [ ] Submitting suggestion shows flash + creates pending record
- [ ] Admin can approve → step is updated + user gets notification
- [ ] Admin can reject → step unchanged + user gets notification
- [ ] Step shows "Editado por @username" after approved edit
- [ ] User profile Contributions tab shows all suggestions with status
- [ ] Connection section has "suggest removal" and "suggest new" buttons

- [ ] **Step 3: Push + deploy**

```bash
git push origin main && fly deploy
```
