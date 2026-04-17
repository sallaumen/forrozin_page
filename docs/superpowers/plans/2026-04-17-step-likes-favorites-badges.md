# Step Likes + Favoritos + Badges — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add like buttons to steps everywhere, favorites (star) as curated lists with auto-like, public favorites tab on profile with stats grid, and 6 gamification badges computed on-demand.

**Architecture:** Reuse existing polymorphic `likes` table for step likes. New `favorites` table for curated favorites (steps + sequences). `Engagement.Badges` pure module computes badges from COUNT queries. Cytoscape node styling via push_event for liked steps in graph.

**Tech Stack:** Phoenix 1.7, LiveView 1.0+, Ecto 3.10, PostgreSQL 17, Tailwind v4, Cytoscape.js

**Spec:** `docs/superpowers/specs/2026-04-17-step-likes-favorites-badges-design.md`

---

## File Structure

### Create

| File | Responsibility |
|------|---------------|
| `priv/repo/migrations/TIMESTAMP_create_favorites.exs` | Favorites table + unique index |
| `lib/o_grupo_de_estudos/engagement/favorite.ex` | Schema: Favorite (user_id, favoritable_type, favoritable_id) |
| `lib/o_grupo_de_estudos/engagement/badges.ex` | Pure module: compute/1, primary/1, fetch_metrics/1 |
| `test/o_grupo_de_estudos/engagement/badges_test.exs` | TDD tests for badge computation |

### Modify

| File | Change |
|------|--------|
| `lib/o_grupo_de_estudos/engagement.ex` | Add: toggle_favorite, favorited?, list_user_favorites, favorites_map, liked_step_ids, total_likes_received, count_comments_authored, count_likes_given |
| `lib/o_grupo_de_estudos_web/live/collection_live.ex` | Load step_likes in mount, like button in step_item |
| `lib/o_grupo_de_estudos_web/live/step_live.ex` + `.html.heex` | Like + favorite buttons below title |
| `lib/o_grupo_de_estudos_web/live/community_live.ex` + `.html.heex` | Like button on step cards |
| `lib/o_grupo_de_estudos_web/live/graph_visual_live.ex` | liked_step_ids assign + push_event |
| `assets/js/app.js` | Cytoscape node border styling for liked steps |
| `lib/o_grupo_de_estudos_web/live/user_profile_live.ex` + `.html.heex` | Stats grid, Favoritos tab, Conquistas section |
| `lib/o_grupo_de_estudos_web/components/ui/comment_thread.ex` | Micro-badge next to username |
| `test/support/factory.ex` | Add favorite_factory |
| `test/o_grupo_de_estudos/engagement_test.exs` | Add favorites + metrics tests |

---

### Task 1: Migration + Favorite schema + Factory

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_favorites.exs`
- Create: `lib/o_grupo_de_estudos/engagement/favorite.ex`
- Modify: `test/support/factory.ex`

- [ ] **Step 1: Generate migration**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.gen.migration create_favorites
```

- [ ] **Step 2: Write the migration**

```elixir
defmodule OGrupoDeEstudos.Repo.Migrations.CreateFavorites do
  use Ecto.Migration

  def change do
    create table(:favorites, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :favoritable_type, :string, null: false
      add :favoritable_id, :binary_id, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(updated_at: false)
    end

    create unique_index(:favorites, [:user_id, :favoritable_type, :favoritable_id])
    create index(:favorites, [:user_id, :favoritable_type, :inserted_at])
  end
end
```

- [ ] **Step 3: Create Favorite schema**

Create `lib/o_grupo_de_estudos/engagement/favorite.ex`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Favorite do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_types ~w(step sequence)

  schema "favorites" do
    field :favoritable_type, :string
    field :favoritable_id, :binary_id
    belongs_to :user, OGrupoDeEstudos.Accounts.User
    timestamps(updated_at: false)
  end

  def changeset(favorite, attrs) do
    favorite
    |> cast(attrs, [:user_id, :favoritable_type, :favoritable_id])
    |> validate_required([:user_id, :favoritable_type, :favoritable_id])
    |> validate_inclusion(:favoritable_type, @valid_types)
    |> unique_constraint([:user_id, :favoritable_type, :favoritable_id])
  end
end
```

- [ ] **Step 4: Add factory**

In `test/support/factory.ex`, add alias and factory:

```elixir
# Add to alias block:
alias OGrupoDeEstudos.Engagement.Favorite

# Add factory:
def favorite_factory do
  %Favorite{
    favoritable_type: "step",
    favoritable_id: Ecto.UUID.generate(),
    user: build(:user)
  }
end
```

- [ ] **Step 5: Run migration + tests**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.migrate && mix test
```

- [ ] **Step 6: Commit**

```bash
git add priv/repo/migrations/*favorites* lib/o_grupo_de_estudos/engagement/favorite.ex test/support/factory.ex && git commit -m "feat: create favorites table + Favorite schema"
```

---

### Task 2: Engagement context — favorites + metrics functions

**Files:**
- Modify: `lib/o_grupo_de_estudos/engagement.ex`
- Modify: `test/o_grupo_de_estudos/engagement_test.exs`

- [ ] **Step 1: Write failing tests**

Add to `test/o_grupo_de_estudos/engagement_test.exs`:

```elixir
alias OGrupoDeEstudos.Engagement.Favorite

describe "favorites" do
  test "toggle_favorite/3 creates favorite + auto-likes", %{user: user, step: step} do
    assert {:ok, :favorited} = Engagement.toggle_favorite(user.id, "step", step.id)
    assert Engagement.favorited?(user.id, "step", step.id)
    # Auto-like should have been created
    assert Engagement.liked?(user.id, "step", step.id)
  end

  test "toggle_favorite/3 removes favorite but keeps like", %{user: user, step: step} do
    {:ok, :favorited} = Engagement.toggle_favorite(user.id, "step", step.id)
    {:ok, :unfavorited} = Engagement.toggle_favorite(user.id, "step", step.id)
    refute Engagement.favorited?(user.id, "step", step.id)
    # Like should still exist
    assert Engagement.liked?(user.id, "step", step.id)
  end

  test "toggle_favorite/3 does not double-like if already liked", %{user: user, step: step} do
    Engagement.toggle_like(user.id, "step", step.id)
    {:ok, :favorited} = Engagement.toggle_favorite(user.id, "step", step.id)
    # Should still be liked (not toggled off)
    assert Engagement.liked?(user.id, "step", step.id)
  end

  test "favorites_map/3 returns favorited_ids MapSet", %{user: user, step: step} do
    other_step = insert(:step)
    Engagement.toggle_favorite(user.id, "step", step.id)

    result = Engagement.favorites_map(user.id, "step", [step.id, other_step.id])
    assert MapSet.member?(result, step.id)
    refute MapSet.member?(result, other_step.id)
  end

  test "list_user_favorites/2 returns favorited steps", %{user: user, step: step} do
    Engagement.toggle_favorite(user.id, "step", step.id)
    favorites = Engagement.list_user_favorites(user.id, "step")
    assert length(favorites) == 1
    assert hd(favorites).id == step.id
  end
end

describe "metrics" do
  test "liked_step_ids/1 returns MapSet of liked step ids", %{user: user, step: step} do
    Engagement.toggle_like(user.id, "step", step.id)
    ids = Engagement.liked_step_ids(user.id)
    assert MapSet.member?(ids, step.id)
  end

  test "count_likes_given/2 counts likes by type", %{user: user, step: step} do
    Engagement.toggle_like(user.id, "step", step.id)
    assert Engagement.count_likes_given(user.id, "step") == 1
  end

  test "count_comments_authored/1 counts all comment types", %{user: user, step: step} do
    Engagement.create_step_comment(user, step.id, %{body: "Test 1"})
    Engagement.create_step_comment(user, step.id, %{body: "Test 2"})
    assert Engagement.count_comments_authored(user.id) >= 2
  end

  test "count_user_favorites/1 counts all favorites", %{user: user, step: step} do
    Engagement.toggle_favorite(user.id, "step", step.id)
    assert Engagement.count_user_favorites(user.id) == 1
  end
end
```

- [ ] **Step 2: Run tests to see failures**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test test/o_grupo_de_estudos/engagement_test.exs
```

- [ ] **Step 3: Implement the functions**

Add to `lib/o_grupo_de_estudos/engagement.ex`. Read the file first, then add these functions. Add `Favorite` to the alias block:

```elixir
alias OGrupoDeEstudos.Engagement.Favorite
```

Add these public functions (after the existing likes section):

```elixir
  # ── Favorites ──────────────────────────────────────────

  def toggle_favorite(user_id, type, id) do
    case Repo.get_by(Favorite, user_id: user_id, favoritable_type: type, favoritable_id: id) do
      nil ->
        %Favorite{}
        |> Favorite.changeset(%{user_id: user_id, favoritable_type: type, favoritable_id: id})
        |> Repo.insert()
        |> case do
          {:ok, _} ->
            # Auto-like if not already liked
            unless liked?(user_id, type, id), do: toggle_like(user_id, type, id)
            {:ok, :favorited}
          error -> error
        end

      fav ->
        # Unfavorite but keep like
        Repo.delete(fav)
        {:ok, :unfavorited}
    end
  end

  def favorited?(user_id, type, id) do
    Repo.exists?(
      from(f in Favorite,
        where: f.user_id == ^user_id and f.favoritable_type == ^type and f.favoritable_id == ^id
      )
    )
  end

  def favorites_map(user_id, type, ids) do
    from(f in Favorite,
      where: f.user_id == ^user_id and f.favoritable_type == ^type and f.favoritable_id in ^ids,
      select: f.favoritable_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  def list_user_favorites(user_id, "step") do
    from(f in Favorite,
      where: f.user_id == ^user_id and f.favoritable_type == "step",
      join: s in OGrupoDeEstudos.Encyclopedia.Step, on: s.id == f.favoritable_id,
      where: is_nil(s.deleted_at) and s.status == "published",
      order_by: [desc: f.inserted_at],
      select: s,
      preload: [:category]
    )
    |> Repo.all()
  end

  def list_user_favorites(user_id, "sequence") do
    from(f in Favorite,
      where: f.user_id == ^user_id and f.favoritable_type == "sequence",
      join: s in OGrupoDeEstudos.Sequences.Sequence, on: s.id == f.favoritable_id,
      where: is_nil(s.deleted_at),
      order_by: [desc: f.inserted_at],
      select: s,
      preload: [sequence_steps: :step]
    )
    |> Repo.all()
  end

  def count_user_favorites(user_id) do
    from(f in Favorite, where: f.user_id == ^user_id, select: count(f.id))
    |> Repo.one()
  end

  # ── Metrics ────────────────────────────────────────────

  def liked_step_ids(user_id) do
    from(l in Like,
      where: l.user_id == ^user_id and l.likeable_type == "step",
      select: l.likeable_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  def count_likes_given(user_id, type) do
    from(l in Like,
      where: l.user_id == ^user_id and l.likeable_type == ^type,
      select: count(l.id)
    )
    |> Repo.one()
  end

  def count_comments_authored(user_id) do
    alias OGrupoDeEstudos.Engagement.Comments.{StepComment, SequenceComment}

    sc = Repo.one(from c in StepComment, where: c.user_id == ^user_id and is_nil(c.deleted_at), select: count(c.id))
    qc = Repo.one(from c in SequenceComment, where: c.user_id == ^user_id and is_nil(c.deleted_at), select: count(c.id))
    pc = Repo.one(from c in ProfileComment, where: c.author_id == ^user_id and is_nil(c.deleted_at), select: count(c.id))

    (sc || 0) + (qc || 0) + (pc || 0)
  end

  def total_likes_received(user_id) do
    alias OGrupoDeEstudos.Engagement.Comments.{StepComment, SequenceComment}

    sc = Repo.one(from l in Like,
      join: c in StepComment, on: c.id == l.likeable_id and l.likeable_type == "step_comment",
      where: c.user_id == ^user_id, select: count(l.id))

    qc = Repo.one(from l in Like,
      join: c in SequenceComment, on: c.id == l.likeable_id and l.likeable_type == "sequence_comment",
      where: c.user_id == ^user_id, select: count(l.id))

    pc = Repo.one(from l in Like,
      join: c in ProfileComment, on: c.id == l.likeable_id and l.likeable_type == "profile_comment",
      where: c.author_id == ^user_id, select: count(l.id))

    (sc || 0) + (qc || 0) + (pc || 0)
  end
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test test/o_grupo_de_estudos/engagement_test.exs
```

Expected: All pass.

- [ ] **Step 5: Run full suite**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test
```

- [ ] **Step 6: Commit**

```bash
git add lib/o_grupo_de_estudos/engagement.ex test/o_grupo_de_estudos/engagement_test.exs && git commit -m "feat: favorites toggle + metrics (liked_step_ids, counts, total_likes_received)"
```

---

### Task 3: Badges module + TDD

**Files:**
- Create: `lib/o_grupo_de_estudos/engagement/badges.ex`
- Create: `test/o_grupo_de_estudos/engagement/badges_test.exs`

- [ ] **Step 1: Write failing tests**

Create `test/o_grupo_de_estudos/engagement/badges_test.exs`:

```elixir
defmodule OGrupoDeEstudos.Engagement.BadgesTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Engagement.Badges

  describe "compute/1" do
    test "returns all badges with earned: false for new user" do
      user = insert(:user)
      badges = Badges.compute(user.id)
      assert length(badges) == 6
      assert Enum.all?(badges, fn b -> b.earned == false end)
    end

    test "marks Explorador as earned when user liked 5+ steps" do
      user = insert(:user)
      for _ <- 1..5 do
        step = insert(:step)
        Engagement.toggle_like(user.id, "step", step.id)
      end

      badges = Badges.compute(user.id)
      explorador = Enum.find(badges, &(&1.key == :explorador))
      assert explorador.earned
      assert explorador.current == 5
      assert explorador.progress == 1.0
    end

    test "marks Comentarista as earned when user made 5+ comments" do
      user = insert(:user)
      step = insert(:step)
      for i <- 1..5 do
        Engagement.create_step_comment(user, step.id, %{body: "Comment #{i}"})
      end

      badges = Badges.compute(user.id)
      comentarista = Enum.find(badges, &(&1.key == :comentarista))
      assert comentarista.earned
    end

    test "computes progress correctly for partial achievement" do
      user = insert(:user)
      for _ <- 1..3 do
        step = insert(:step)
        Engagement.toggle_like(user.id, "step", step.id)
      end

      badges = Badges.compute(user.id)
      explorador = Enum.find(badges, &(&1.key == :explorador))
      refute explorador.earned
      assert explorador.current == 3
      assert_in_delta explorador.progress, 0.6, 0.01
    end
  end

  describe "primary/1" do
    test "returns nil for new user" do
      user = insert(:user)
      assert is_nil(Badges.primary(user.id))
    end

    test "returns highest-rank earned badge" do
      user = insert(:user)
      for _ <- 1..15 do
        step = insert(:step)
        Engagement.toggle_like(user.id, "step", step.id)
      end

      badge = Badges.primary(user.id)
      assert badge.key == :curador
    end
  end
end
```

- [ ] **Step 2: Run tests to see failures**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test test/o_grupo_de_estudos/engagement/badges_test.exs
```

- [ ] **Step 3: Implement Badges module**

Create `lib/o_grupo_de_estudos/engagement/badges.ex`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Badges do
  @moduledoc """
  Computes gamification badges from engagement metrics.
  No persistence — calculated on-demand from COUNT queries.
  Ordered by rank (highest first).
  """

  alias OGrupoDeEstudos.Engagement

  @badges [
    %{key: :estrela, icon: "🌟", name: "Estrela", threshold: 25, metric: :likes_received},
    %{key: :popular, icon: "❤️", name: "Popular", threshold: 10, metric: :likes_received},
    %{key: :voz_ativa, icon: "🎤", name: "Voz Ativa", threshold: 15, metric: :comments_count},
    %{key: :comentarista, icon: "💬", name: "Comentarista", threshold: 5, metric: :comments_count},
    %{key: :curador, icon: "⭐", name: "Curador", threshold: 15, metric: :likes_given},
    %{key: :explorador, icon: "🧭", name: "Explorador", threshold: 5, metric: :likes_given}
  ]

  def all_badges, do: @badges

  @doc "Returns all badges with earned/progress for a user."
  def compute(user_id) do
    metrics = fetch_metrics(user_id)

    Enum.map(@badges, fn badge ->
      current = Map.get(metrics, badge.metric, 0)

      Map.merge(badge, %{
        earned: current >= badge.threshold,
        current: current,
        progress: min(current / badge.threshold, 1.0)
      })
    end)
  end

  @doc "Returns the highest-rank earned badge, or nil."
  def primary(user_id) do
    user_id |> compute() |> Enum.find(& &1.earned)
  end

  defp fetch_metrics(user_id) do
    %{
      likes_given: Engagement.count_likes_given(user_id, "step"),
      comments_count: Engagement.count_comments_authored(user_id),
      likes_received: Engagement.total_likes_received(user_id)
    }
  end
end
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test test/o_grupo_de_estudos/engagement/badges_test.exs
```

Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add lib/o_grupo_de_estudos/engagement/badges.ex test/o_grupo_de_estudos/engagement/badges_test.exs && git commit -m "feat: Badges module — compute 6 engagement badges on-demand with TDD"
```

---

### Task 4: Collection — step like button

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/collection_live.ex`

- [ ] **Step 1: Add step_likes loading in mount**

In `collection_live.ex` mount, after `steps_with_links` is computed, collect all step IDs across all sections and load likes:

```elixir
# After sections are loaded, collect all step IDs
all_step_ids =
  sections
  |> Enum.flat_map(fn s ->
    step_ids = Enum.map(s.steps, & &1.id)
    sub_ids = Enum.flat_map(s.subsections, fn sub -> Enum.map(sub.steps, & &1.id) end)
    step_ids ++ sub_ids
  end)

step_likes = Engagement.likes_map(socket.assigns.current_user.id, "step", all_step_ids)
```

Add `step_likes: step_likes` to the assigns.

- [ ] **Step 2: Pass step_likes to step_item component**

Add `attr :step_likes, :map, default: %{liked_ids: %MapSet{}, counts: %{}}` to both `section_card` and `step_item`.

In section_card, pass it through to step_item: `step_likes={@step_likes}`

In the template where section_card is called, add: `step_likes={@step_likes}`

- [ ] **Step 3: Add like button to step_item right column**

In the step_item component, in the right-side icons column (where 👤 and 🎬 are), add:

```heex
<%!-- Step like button --%>
<button
  phx-click="toggle_step_like"
  phx-value-id={@step.id}
  class="p-0.5"
  title={if MapSet.member?(@step_likes.liked_ids, @step.id), do: "Remover curtida", else: "Curtir passo"}
>
  <.icon
    name={if MapSet.member?(@step_likes.liked_ids, @step.id), do: "hero-heart-solid", else: "hero-heart"}
    class={[
      "w-4 h-4",
      MapSet.member?(@step_likes.liked_ids, @step.id) && "text-accent-red",
      !MapSet.member?(@step_likes.liked_ids, @step.id) && "text-ink-400"
    ]}
  />
</button>
<span :if={Map.get(@step_likes.counts, @step.id, 0) > 0}
  class="text-[10px] tabular-nums text-ink-400">
  {Map.get(@step_likes.counts, @step.id, 0)}
</span>
```

- [ ] **Step 4: Add toggle_step_like event handler**

```elixir
def handle_event("toggle_step_like", %{"id" => step_id}, socket) do
  user = socket.assigns.current_user
  case Engagement.toggle_like(user.id, "step", step_id) do
    {:ok, _} ->
      {:noreply, reload_step_likes(socket)}
    {:error, _} ->
      {:noreply, socket}
  end
end

defp reload_step_likes(socket) do
  sections = socket.assigns.sections
  all_step_ids =
    sections
    |> Enum.flat_map(fn s ->
      step_ids = Enum.map(s.steps, & &1.id)
      sub_ids = Enum.flat_map(s.subsections, fn sub -> Enum.map(sub.steps, & &1.id) end)
      step_ids ++ sub_ids
    end)

  step_likes = Engagement.likes_map(socket.assigns.current_user.id, "step", all_step_ids)
  assign(socket, :step_likes, step_likes)
end
```

- [ ] **Step 5: Compile + test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

- [ ] **Step 6: Commit**

```bash
git add lib/o_grupo_de_estudos_web/live/collection_live.ex lib/o_grupo_de_estudos_web/live/collection_live.html.heex && git commit -m "feat: step like button in /collection step_item"
```

---

### Task 5: StepLive — like + favorite buttons

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/step_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/step_live.html.heex`

- [ ] **Step 1: Add step like/favorite data to mount**

In step_live.ex mount, add after existing code:

```elixir
step_liked = Engagement.liked?(user_id, "step", step.id)
step_like_count = step.like_count
step_favorited = Engagement.favorited?(user_id, "step", step.id)
```

Add to assigns:
```elixir
step_liked: step_liked,
step_like_count: step_like_count,
step_favorited: step_favorited
```

- [ ] **Step 2: Add event handlers**

```elixir
def handle_event("toggle_step_like", %{"id" => step_id}, socket) do
  user = socket.assigns.current_user
  case Engagement.toggle_like(user.id, "step", step_id) do
    {:ok, _} ->
      step = OGrupoDeEstudos.Repo.get!(OGrupoDeEstudos.Encyclopedia.Step, step_id)
      {:noreply, assign(socket,
        step_liked: Engagement.liked?(user.id, "step", step_id),
        step_like_count: step.like_count
      )}
    {:error, _} -> {:noreply, socket}
  end
end

def handle_event("toggle_step_favorite", %{"id" => step_id}, socket) do
  user = socket.assigns.current_user
  case Engagement.toggle_favorite(user.id, "step", step_id) do
    {:ok, _} ->
      step = OGrupoDeEstudos.Repo.get!(OGrupoDeEstudos.Encyclopedia.Step, step_id)
      {:noreply, assign(socket,
        step_liked: Engagement.liked?(user.id, "step", step_id),
        step_like_count: step.like_count,
        step_favorited: Engagement.favorited?(user.id, "step", step_id)
      )}
    {:error, _} -> {:noreply, socket}
  end
end
```

- [ ] **Step 3: Add like + favorite buttons to template**

In step_live.html.heex, below the step title/code area and above the note, add:

```heex
<%!-- Like + Favorite buttons --%>
<div class="flex items-center gap-4 mt-3 mb-4">
  <button phx-click="toggle_step_like" phx-value-id={@step.id}
    class="flex items-center gap-1.5 group">
    <.icon
      name={if @step_liked, do: "hero-heart-solid", else: "hero-heart"}
      class={[
        "w-5 h-5 transition-all duration-200",
        @step_liked && "text-accent-red",
        !@step_liked && "text-ink-400 group-hover:text-accent-red/60"
      ]}
    />
    <span class={[
      "text-sm tabular-nums",
      @step_liked && "text-accent-red font-medium",
      !@step_liked && "text-ink-500"
    ]}>
      {if @step_like_count > 0, do: @step_like_count, else: "Curtir"}
    </span>
  </button>

  <button phx-click="toggle_step_favorite" phx-value-id={@step.id}
    class="flex items-center gap-1.5 group">
    <.icon
      name={if @step_favorited, do: "hero-star-solid", else: "hero-star"}
      class={[
        "w-5 h-5 transition-all duration-200",
        @step_favorited && "text-gold-500",
        !@step_favorited && "text-ink-400 group-hover:text-gold-500/60"
      ]}
    />
    <span class={[
      "text-sm",
      @step_favorited && "text-gold-500 font-medium",
      !@step_favorited && "text-ink-500"
    ]}>
      {if @step_favorited, do: "Favoritado", else: "Favoritar"}
    </span>
  </button>
</div>
```

- [ ] **Step 4: Compile + test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

- [ ] **Step 5: Commit**

```bash
git add lib/o_grupo_de_estudos_web/live/step_live.ex lib/o_grupo_de_estudos_web/live/step_live.html.heex && git commit -m "feat: like + favorite buttons on step detail page"
```

---

### Task 6: Community — step like button

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/community_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/community_live.html.heex`

- [ ] **Step 1: Load step_likes when steps section is active**

In community_live.ex, in the mount where `steps` are loaded, add:

```elixir
step_ids = Enum.map(steps, & &1.id)
step_likes = Engagement.likes_map(socket.assigns.current_user.id, "step", step_ids)
```

Add `step_likes: step_likes` to mount assigns.

Also update `switch_tab` handler to reload step_likes when steps change:

```elixir
def handle_event("switch_tab", %{"tab" => tab}, socket) do
  steps = Encyclopedia.list_suggested_steps_filtered(filter: tab)
  step_ids = Enum.map(steps, & &1.id)
  step_likes = Engagement.likes_map(socket.assigns.current_user.id, "step", step_ids)
  {:noreply, assign(socket, active_tab: tab, steps: steps, step_likes: step_likes)}
end
```

- [ ] **Step 2: Add toggle_step_like handler**

```elixir
def handle_event("toggle_step_like", %{"id" => step_id}, socket) do
  user = socket.assigns.current_user
  case Engagement.toggle_like(user.id, "step", step_id) do
    {:ok, _} ->
      step_ids = Enum.map(socket.assigns.steps, & &1.id)
      step_likes = Engagement.likes_map(user.id, "step", step_ids)
      {:noreply, assign(socket, step_likes: step_likes)}
    {:error, _} -> {:noreply, socket}
  end
end
```

- [ ] **Step 3: Add like button to step cards in template**

In the step cards section of community_live.html.heex, add a like button. Find where each step card footer is rendered and add:

```heex
<button phx-click="toggle_step_like" phx-value-id={step.id}
  class="flex items-center gap-1 text-sm">
  <.icon
    name={if MapSet.member?(@step_likes.liked_ids, step.id), do: "hero-heart-solid", else: "hero-heart"}
    class={[
      "w-4 h-4",
      MapSet.member?(@step_likes.liked_ids, step.id) && "text-accent-red",
      !MapSet.member?(@step_likes.liked_ids, step.id) && "text-ink-400"
    ]}
  />
  <span :if={Map.get(@step_likes.counts, step.id, 0) > 0}
    class="text-xs tabular-nums text-ink-500">
    {Map.get(@step_likes.counts, step.id, 0)}
  </span>
</button>
```

- [ ] **Step 4: Compile + test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

- [ ] **Step 5: Commit**

```bash
git add lib/o_grupo_de_estudos_web/live/community_live.ex lib/o_grupo_de_estudos_web/live/community_live.html.heex && git commit -m "feat: step like button in community page"
```

---

### Task 7: Graph — liked steps visual indicator

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/graph_visual_live.ex`
- Modify: `assets/js/app.js`

- [ ] **Step 1: Add liked_step_ids to graph mount**

In graph_visual_live.ex mount, add:

```elixir
liked_step_ids = Engagement.liked_step_ids(socket.assigns.current_user.id)
```

Add to assigns: `liked_step_ids: liked_step_ids`

When sending graph data to Cytoscape, include liked_step_codes:

```elixir
liked_codes =
  liked_step_ids
  |> MapSet.to_list()
  |> Enum.map(fn id -> Repo.get(Step, id) end)
  |> Enum.reject(&is_nil/1)
  |> Enum.map(& &1.code)
```

Push event after graph initialization:
```elixir
push_event(socket, "set_liked_steps", %{codes: liked_codes})
```

- [ ] **Step 2: Handle JS event for liked steps styling**

In `assets/js/app.js`, in the GraphVisual hook, add handler:

```javascript
this.handleEvent("set_liked_steps", ({codes}) => {
  window._likedStepCodes = new Set(codes);
  applyLikedStepStyling();
});

function applyLikedStepStyling() {
  if (!window._cytoscape || !window._likedStepCodes) return;
  const cy = window._cytoscape;

  cy.nodes().forEach(node => {
    if (window._likedStepCodes.has(node.id())) {
      node.style('border-width', '2px');
      node.style('border-color', '#c0392b');
    } else {
      node.style('border-width', '0px');
      node.style('border-color', 'transparent');
    }
  });
}
```

Also call `applyLikedStepStyling()` after graph initialization completes (after `runHybridLayout`).

- [ ] **Step 3: Update liked steps when like toggled elsewhere**

If the graph is open and user likes a step from the drawer, update Cytoscape:

In graph_visual_live.ex, when handling any step-like toggle, push updated codes:

```elixir
# After toggle_like for a step, update the graph
liked_step_ids = Engagement.liked_step_ids(socket.assigns.current_user.id)
# ... push_event("set_liked_steps", %{codes: liked_codes})
```

- [ ] **Step 4: Compile + test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

- [ ] **Step 5: Commit**

```bash
git add lib/o_grupo_de_estudos_web/live/graph_visual_live.ex assets/js/app.js && git commit -m "feat: liked steps highlighted with red border in graph"
```

---

### Task 8: UserProfileLive — stats grid + Favoritos tab + Conquistas

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/user_profile_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/user_profile_live.html.heex`

- [ ] **Step 1: Add stats + badges + favorites data to mount**

In user_profile_live.ex mount, add:

```elixir
alias OGrupoDeEstudos.Engagement.Badges

# Stats
total_likes = Engagement.total_likes_received(user.id)
total_favorites = Engagement.count_user_favorites(user.id)
total_sequences = length(sequences)

# Badges
badges = Badges.compute(user.id)
primary_badge = Enum.find(badges, & &1.earned)
```

Add to assigns:
```elixir
total_likes: total_likes,
total_favorites: total_favorites,
total_sequences: total_sequences,
badges: badges,
primary_badge: primary_badge,
profile_tab: "steps",
favorite_steps: [],
favorite_sequences: [],
favorite_sub_tab: "steps"
```

- [ ] **Step 2: Add tab switching + favorites loading**

```elixir
def handle_event("switch_profile_tab", %{"tab" => "favorites"}, socket) do
  profile_user = socket.assigns.profile_user
  fav_steps = Engagement.list_user_favorites(profile_user.id, "step")
  fav_sequences = Engagement.list_user_favorites(profile_user.id, "sequence")

  {:noreply, assign(socket,
    profile_tab: "favorites",
    favorite_steps: fav_steps,
    favorite_sequences: fav_sequences
  )}
end

def handle_event("switch_profile_tab", %{"tab" => tab}, socket) do
  {:noreply, assign(socket, profile_tab: tab)}
end

def handle_event("switch_favorite_sub_tab", %{"tab" => tab}, socket) do
  {:noreply, assign(socket, favorite_sub_tab: tab)}
end
```

- [ ] **Step 3: Add stats grid to template**

In user_profile_live.html.heex, below the bio section and above content tabs, add:

```heex
<%!-- Stats grid --%>
<div class="flex justify-center gap-2 my-4 px-4">
  <div class="flex-1 text-center p-3 rounded-lg bg-ink-50">
    <p class="text-2xl font-bold text-ink-800">{@total_likes}</p>
    <p class="text-xs text-ink-500">curtidas</p>
  </div>
  <button phx-click="switch_profile_tab" phx-value-tab="favorites"
    class="flex-1 text-center p-3 rounded-lg bg-ink-50 hover:bg-ink-100 transition-colors cursor-pointer border-0">
    <p class="text-2xl font-bold text-ink-800">{@total_favorites}</p>
    <p class="text-xs text-ink-500">favoritos</p>
  </button>
  <button phx-click="switch_profile_tab" phx-value-tab="sequences"
    class="flex-1 text-center p-3 rounded-lg bg-ink-50 hover:bg-ink-100 transition-colors cursor-pointer border-0">
    <p class="text-2xl font-bold text-ink-800">{@total_sequences}</p>
    <p class="text-xs text-ink-500">sequências</p>
  </button>
</div>
```

- [ ] **Step 4: Add Conquistas section**

Below the stats grid:

```heex
<%!-- Conquistas --%>
<div class="px-4 mb-4">
  <h3 class="text-xs font-bold text-ink-500 uppercase tracking-wider mb-2">Conquistas</h3>
  <div class="flex flex-wrap gap-2">
    <%= for badge <- @badges do %>
      <div class={[
        "flex items-center gap-1 py-1 px-2.5 rounded-full text-xs border",
        badge.earned && "bg-ink-50 border-ink-200 text-ink-700",
        !badge.earned && "bg-ink-50/50 border-ink-100 text-ink-400 opacity-40"
      ]}
        title={if badge.earned, do: badge.name, else: "#{badge.name} — #{badge.current}/#{badge.threshold}"}
      >
        <span>{badge.icon}</span>
        <span class="font-medium">{badge.name}</span>
      </div>
    <% end %>
  </div>

  <%!-- Progress bars (own profile only) --%>
  <%= if @is_own_profile do %>
    <div class="mt-3 space-y-1.5">
      <%= for badge <- @badges, !badge.earned do %>
        <div class="flex items-center gap-2">
          <span class="text-xs w-24 text-ink-400 truncate">{badge.icon} {badge.name}</span>
          <div class="flex-1 bg-ink-200 rounded-full h-1.5 overflow-hidden">
            <div class="h-full bg-accent-orange rounded-full transition-all"
              style={"width: #{round(badge.progress * 100)}%"} />
          </div>
          <span class="text-[10px] text-ink-400 tabular-nums w-10 text-right">
            {badge.current}/{badge.threshold}
          </span>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Add tabs (Passos / Sequências / Favoritos)**

Replace existing content sections with tabbed view:

```heex
<%!-- Tab switcher --%>
<div class="flex w-full p-0.5 bg-ink-100 rounded-md mx-4 mb-4" style="max-width: calc(100% - 2rem);">
  <%= for {tab, label} <- [{"steps", "Passos"}, {"sequences", "Sequências"}, {"favorites", "Favoritos ★"}] do %>
    <button phx-click="switch_profile_tab" phx-value-tab={tab}
      class={[
        "flex-1 py-2 text-sm font-medium rounded-md transition-all text-center",
        @profile_tab == tab && "bg-white shadow-sm text-accent-orange",
        @profile_tab != tab && "text-ink-500 hover:text-ink-700"
      ]}>
      {label}
    </button>
  <% end %>
</div>
```

Then conditionally render content based on `@profile_tab`:
- `"steps"` → existing steps list
- `"sequences"` → existing sequences list
- `"favorites"` → favorites sub-tabs (steps / sequences) with items

- [ ] **Step 6: Add Favoritos tab content**

```heex
<%= if @profile_tab == "favorites" do %>
  <div class="px-4">
    <%!-- Sub-tabs --%>
    <div class="flex gap-2 mb-3">
      <%= for {tab, label} <- [{"steps", "Passos"}, {"sequences", "Sequências"}] do %>
        <button phx-click="switch_favorite_sub_tab" phx-value-tab={tab}
          class={[
            "py-1.5 px-4 rounded-full text-xs font-medium border transition-colors",
            @favorite_sub_tab == tab && "bg-gold-500/10 border-gold-500/30 text-gold-500",
            @favorite_sub_tab != tab && "bg-ink-50 border-ink-200 text-ink-500"
          ]}>
          {label}
        </button>
      <% end %>
    </div>

    <%= if @favorite_sub_tab == "steps" do %>
      <%= if @favorite_steps == [] do %>
        <p class="text-sm text-ink-400 italic py-8 text-center">Nenhum passo favoritado ainda.</p>
      <% else %>
        <div class="space-y-2">
          <%= for step <- @favorite_steps do %>
            <.link navigate={~p"/steps/#{step.code}"} class="no-underline">
              <div class="flex items-center gap-3 p-3 bg-ink-50 rounded-lg border border-ink-100 hover:border-ink-200">
                <code class="text-xs font-bold text-ink-700 bg-gold-500/10 py-0.5 px-1.5 rounded-sm border border-gold-500/20">
                  {step.code}
                </code>
                <span class="text-sm text-ink-800 font-serif flex-1">{step.name}</span>
                <.icon name="hero-star-solid" class="w-4 h-4 text-gold-500" />
              </div>
            </.link>
          <% end %>
        </div>
      <% end %>
    <% else %>
      <%= if @favorite_sequences == [] do %>
        <p class="text-sm text-ink-400 italic py-8 text-center">Nenhuma sequência favoritada ainda.</p>
      <% else %>
        <div class="space-y-2">
          <%= for seq <- @favorite_sequences do %>
            <div class="p-3 bg-ink-50 rounded-lg border border-ink-100">
              <span class="text-sm font-bold text-ink-800 font-serif">{seq.name}</span>
              <div class="flex flex-wrap gap-1 mt-1.5">
                <%= for ss <- seq.sequence_steps do %>
                  <code class="text-[10px] font-bold text-ink-600 bg-gold-500/10 py-px px-1 rounded-sm border border-gold-500/15">
                    {ss.step.code}
                  </code>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 7: Compile + test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

- [ ] **Step 8: Commit**

```bash
git add lib/o_grupo_de_estudos_web/live/user_profile_live.ex lib/o_grupo_de_estudos_web/live/user_profile_live.html.heex && git commit -m "feat: profile stats grid, Favoritos tab, Conquistas badges section"
```

---

### Task 9: CommentThread — micro-badge next to username

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/components/ui/comment_thread.ex`

- [ ] **Step 1: Add badge computation to comment_row**

In comment_thread.ex, in the `comment_row` function (the non-deleted clause), after computing `user`, add:

```elixir
badge = if user, do: OGrupoDeEstudos.Engagement.Badges.primary(get_user_id(assigns.comment)), else: nil
assigns = assign(assigns, :badge, badge)
```

- [ ] **Step 2: Render micro-badge next to username**

In the username link area, after the username text, add:

```heex
<span :if={@badge} class="text-xs" title={@badge.name}>{@badge.icon}</span>
```

So it looks like: `@username 🧭` or `@username ⭐`

- [ ] **Step 3: Compile + test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

IMPORTANT: The `Badges.primary/1` call adds a DB query per comment render. For pages with many comments this could be slow. Consider preloading badges for all comment authors in the parent LiveView and passing as a map. For now, the simple approach is acceptable since comments are paginated (max 10 roots).

- [ ] **Step 4: Commit**

```bash
git add lib/o_grupo_de_estudos_web/components/ui/comment_thread.ex && git commit -m "feat: micro-badge next to username in comment threads"
```

---

### Task 10: Gate — full test suite + manual validation

- [ ] **Step 1: Run full test suite**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test
```

Expected: All tests pass.

- [ ] **Step 2: Compile clean**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors
```

- [ ] **Step 3: Manual validation checklist**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix phx.server
```

Check:
- [ ] `/collection`: step items show heart icon with like count in right column
- [ ] `/collection`: clicking heart toggles like (red/gray)
- [ ] `/steps/:code`: like button (heart) + favorite button (star) below title
- [ ] `/steps/:code`: favoriting auto-likes; unfavoriting keeps like
- [ ] `/community`: step cards have like button
- [ ] `/graph/visual`: liked steps have red border on nodes
- [ ] `/users/:username`: stats grid shows curtidas/favoritos/sequências
- [ ] `/users/:username`: Favoritos tab shows favorited steps + sequences
- [ ] `/users/:username`: Conquistas section shows earned/unearned badges
- [ ] `/users/:username`: progress bars on own profile for unearned badges
- [ ] Comment threads: badge emoji next to username of authors with badges

- [ ] **Step 4: Push (user decision)**

```bash
git push origin main && fly deploy
```
