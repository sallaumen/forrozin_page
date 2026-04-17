# Followers System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a unilateral follow system so users can find friends quickly via a Seguidores tab in Community, with follow buttons on profiles and author cards.

**Architecture:** New `follows` table with follower_id/followed_id. Engagement context handles toggle/query. Community LiveView gets a third tab with sub-tabs (Seguindo/Seguidores), search, and user cards showing badges + activity counters. Profile gets follow button + expanded stats grid.

**Tech Stack:** Phoenix 1.7, LiveView 1.0+, Ecto 3.10, PostgreSQL 17, Tailwind v4

**Spec:** `docs/superpowers/specs/2026-04-17-followers-design.md`

---

## File Structure

### Create

| File | Responsibility |
|------|---------------|
| `priv/repo/migrations/TIMESTAMP_create_follows.exs` | Follows table + indices |
| `lib/o_grupo_de_estudos/engagement/follow.ex` | Schema Follow |
| `test/o_grupo_de_estudos/engagement/follow_test.exs` | Tests for follow functions |

### Modify

| File | Change |
|------|--------|
| `lib/o_grupo_de_estudos/engagement.ex` | toggle_follow, following?, list_following/followers, count_following/followers |
| `lib/o_grupo_de_estudos_web/live/community_live.ex` + `.html.heex` | Seguidores tab, sub-tabs, search, user cards, mini follow button on author cards |
| `lib/o_grupo_de_estudos_web/live/user_profile_live.ex` + `.html.heex` | Follow button, stats grid expanded |
| `test/support/factory.ex` | Follow factory |
| `test/o_grupo_de_estudos/engagement_test.exs` | Follow tests |

---

### Task 1: Migration + Follow schema + Factory

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_follows.exs`
- Create: `lib/o_grupo_de_estudos/engagement/follow.ex`
- Modify: `test/support/factory.ex`

- [ ] **Step 1: Generate migration**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.gen.migration create_follows
```

- [ ] **Step 2: Write the migration**

```elixir
defmodule OGrupoDeEstudos.Repo.Migrations.CreateFollows do
  use Ecto.Migration

  def change do
    create table(:follows, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :follower_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :followed_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(updated_at: false)
    end

    create unique_index(:follows, [:follower_id, :followed_id])
    create index(:follows, [:followed_id])
  end
end
```

- [ ] **Step 3: Create Follow schema**

Create `lib/o_grupo_de_estudos/engagement/follow.ex`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Follow do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "follows" do
    belongs_to :follower, OGrupoDeEstudos.Accounts.User
    belongs_to :followed, OGrupoDeEstudos.Accounts.User
    timestamps(updated_at: false)
  end

  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:follower_id, :followed_id])
    |> validate_required([:follower_id, :followed_id])
    |> validate_not_self_follow()
    |> unique_constraint([:follower_id, :followed_id])
    |> foreign_key_constraint(:follower_id)
    |> foreign_key_constraint(:followed_id)
  end

  defp validate_not_self_follow(changeset) do
    follower = get_field(changeset, :follower_id)
    followed = get_field(changeset, :followed_id)

    if follower && followed && follower == followed do
      add_error(changeset, :followed_id, "não pode seguir a si mesmo")
    else
      changeset
    end
  end
end
```

- [ ] **Step 4: Add factory**

In `test/support/factory.ex`, add alias and factory:

```elixir
alias OGrupoDeEstudos.Engagement.Follow

def follow_factory do
  %Follow{
    follower: build(:user),
    followed: build(:user)
  }
end
```

- [ ] **Step 5: Run migration + tests**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix ecto.migrate && mix test
```

- [ ] **Step 6: Commit**

```bash
git add priv/repo/migrations/*follows* lib/o_grupo_de_estudos/engagement/follow.ex test/support/factory.ex && git commit -m "feat: create follows table + Follow schema + factory"
```

---

### Task 2: Engagement context — follow functions + TDD

**Files:**
- Modify: `lib/o_grupo_de_estudos/engagement.ex`
- Modify: `test/o_grupo_de_estudos/engagement_test.exs`

- [ ] **Step 1: Write failing tests**

Add to `test/o_grupo_de_estudos/engagement_test.exs`:

```elixir
describe "follows" do
  test "toggle_follow/2 creates a follow", %{user: user} do
    other = insert(:user)
    assert {:ok, :followed} = Engagement.toggle_follow(user.id, other.id)
    assert Engagement.following?(user.id, other.id)
  end

  test "toggle_follow/2 removes follow on second call", %{user: user} do
    other = insert(:user)
    {:ok, :followed} = Engagement.toggle_follow(user.id, other.id)
    {:ok, :unfollowed} = Engagement.toggle_follow(user.id, other.id)
    refute Engagement.following?(user.id, other.id)
  end

  test "toggle_follow/2 rejects self-follow", %{user: user} do
    assert {:error, _} = Engagement.toggle_follow(user.id, user.id)
  end

  test "following?/2 returns false when not following", %{user: user} do
    other = insert(:user)
    refute Engagement.following?(user.id, other.id)
  end

  test "list_following/2 returns followed users", %{user: user} do
    u1 = insert(:user)
    u2 = insert(:user)
    Engagement.toggle_follow(user.id, u1.id)
    Engagement.toggle_follow(user.id, u2.id)
    following = Engagement.list_following(user.id)
    assert length(following) == 2
    assert Enum.any?(following, &(&1.id == u1.id))
  end

  test "list_followers/2 returns followers", %{user: user} do
    u1 = insert(:user)
    u2 = insert(:user)
    Engagement.toggle_follow(u1.id, user.id)
    Engagement.toggle_follow(u2.id, user.id)
    followers = Engagement.list_followers(user.id)
    assert length(followers) == 2
  end

  test "list_following/2 supports search filter", %{user: user} do
    maria = insert(:user, username: "maria_danca", name: "Maria Silva")
    _joao = insert(:user, username: "joao_forro", name: "João Santos")
    Engagement.toggle_follow(user.id, maria.id)
    Engagement.toggle_follow(user.id, _joao.id)

    results = Engagement.list_following(user.id, search: "maria")
    assert length(results) == 1
    assert hd(results).id == maria.id
  end

  test "count_following/1 and count_followers/1", %{user: user} do
    u1 = insert(:user)
    u2 = insert(:user)
    Engagement.toggle_follow(user.id, u1.id)
    Engagement.toggle_follow(user.id, u2.id)
    Engagement.toggle_follow(u1.id, user.id)

    assert Engagement.count_following(user.id) == 2
    assert Engagement.count_followers(user.id) == 1
  end
end
```

- [ ] **Step 2: Run tests to see failures**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test test/o_grupo_de_estudos/engagement_test.exs
```

- [ ] **Step 3: Implement follow functions**

Read `lib/o_grupo_de_estudos/engagement.ex` first. Add `Follow` to the alias block:

```elixir
alias OGrupoDeEstudos.Engagement.Follow
```

Add these functions at the end (before the closing `end`):

```elixir
  # ══════════════════════════════════════════════════════════════════════
  # Follows
  # ══════════════════════════════════════════════════════════════════════

  def toggle_follow(follower_id, followed_id) do
    case Repo.get_by(Follow, follower_id: follower_id, followed_id: followed_id) do
      nil ->
        %Follow{}
        |> Follow.changeset(%{follower_id: follower_id, followed_id: followed_id})
        |> Repo.insert()
        |> case do
          {:ok, _} -> {:ok, :followed}
          {:error, changeset} -> {:error, changeset}
        end

      follow ->
        Repo.delete(follow)
        {:ok, :unfollowed}
    end
  end

  def following?(follower_id, followed_id) do
    Repo.exists?(
      from(f in Follow,
        where: f.follower_id == ^follower_id and f.followed_id == ^followed_id
      )
    )
  end

  def list_following(user_id, opts \\ []) do
    search = Keyword.get(opts, :search, "")

    from(u in OGrupoDeEstudos.Accounts.User,
      join: f in Follow, on: f.followed_id == u.id,
      where: f.follower_id == ^user_id,
      order_by: [desc: f.inserted_at]
    )
    |> maybe_search_users(search)
    |> Repo.all()
  end

  def list_followers(user_id, opts \\ []) do
    search = Keyword.get(opts, :search, "")

    from(u in OGrupoDeEstudos.Accounts.User,
      join: f in Follow, on: f.follower_id == u.id,
      where: f.followed_id == ^user_id,
      order_by: [desc: f.inserted_at]
    )
    |> maybe_search_users(search)
    |> Repo.all()
  end

  def count_following(user_id) do
    Repo.aggregate(
      from(f in Follow, where: f.follower_id == ^user_id),
      :count
    )
  end

  def count_followers(user_id) do
    Repo.aggregate(
      from(f in Follow, where: f.followed_id == ^user_id),
      :count
    )
  end

  defp maybe_search_users(query, ""), do: query
  defp maybe_search_users(query, search) do
    term = "%#{String.downcase(search)}%"
    where(query, [u], ilike(u.username, ^term) or ilike(u.name, ^term))
  end
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test test/o_grupo_de_estudos/engagement_test.exs && mix test
```

- [ ] **Step 5: Commit**

```bash
git add lib/o_grupo_de_estudos/engagement.ex test/o_grupo_de_estudos/engagement_test.exs && git commit -m "feat: follow functions (toggle, list, count, search) with TDD"
```

---

### Task 3: Community — Seguidores tab + sub-tabs + search + user cards

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/community_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/community_live.html.heex`

- [ ] **Step 1: Add follows data + handlers to community_live.ex**

Read the file first. Then add:

**New assigns in mount:**
```elixir
followers_sub_tab: "following",
followers_search: "",
followers_list: [],
following_count: 0,
followers_count: 0,
followers_following_map: MapSet.new()
```

**New handler for switching to followers tab:**
```elixir
def handle_event("switch_section", %{"section" => "followers"}, socket) do
  user = socket.assigns.current_user
  following = Engagement.list_following(user.id)
  following_count = Engagement.count_following(user.id)
  followers_count = Engagement.count_followers(user.id)

  # For each user in the list, check if current user follows them
  user_ids = Enum.map(following, & &1.id)
  following_map = following_ids_set(user.id, user_ids)

  {:noreply,
   assign(socket,
     active_section: "followers",
     followers_sub_tab: "following",
     followers_list: following,
     following_count: following_count,
     followers_count: followers_count,
     followers_following_map: following_map,
     followers_search: ""
   )}
end
```

**Handler for sub-tab switching:**
```elixir
def handle_event("switch_followers_tab", %{"tab" => "following"}, socket) do
  user = socket.assigns.current_user
  list = Engagement.list_following(user.id, search: socket.assigns.followers_search)
  user_ids = Enum.map(list, & &1.id)
  {:noreply, assign(socket,
    followers_sub_tab: "following",
    followers_list: list,
    followers_following_map: following_ids_set(user.id, user_ids)
  )}
end

def handle_event("switch_followers_tab", %{"tab" => "followers"}, socket) do
  user = socket.assigns.current_user
  list = Engagement.list_followers(user.id, search: socket.assigns.followers_search)
  user_ids = Enum.map(list, & &1.id)
  {:noreply, assign(socket,
    followers_sub_tab: "followers",
    followers_list: list,
    followers_following_map: following_ids_set(user.id, user_ids)
  )}
end
```

**Search handler:**
```elixir
def handle_event("search_followers", %{"term" => term}, socket) do
  user = socket.assigns.current_user
  list = case socket.assigns.followers_sub_tab do
    "following" -> Engagement.list_following(user.id, search: term)
    "followers" -> Engagement.list_followers(user.id, search: term)
  end
  user_ids = Enum.map(list, & &1.id)
  {:noreply, assign(socket,
    followers_search: term,
    followers_list: list,
    followers_following_map: following_ids_set(user.id, user_ids)
  )}
end
```

**Toggle follow handler:**
```elixir
def handle_event("toggle_follow", %{"user-id" => target_id}, socket) do
  user = socket.assigns.current_user
  Engagement.toggle_follow(user.id, target_id)
  # Reload current list
  list = case socket.assigns.followers_sub_tab do
    "following" -> Engagement.list_following(user.id, search: socket.assigns.followers_search)
    "followers" -> Engagement.list_followers(user.id, search: socket.assigns.followers_search)
  end
  user_ids = Enum.map(list, & &1.id)
  {:noreply, assign(socket,
    followers_list: list,
    following_count: Engagement.count_following(user.id),
    followers_count: Engagement.count_followers(user.id),
    followers_following_map: following_ids_set(user.id, user_ids)
  )}
end
```

**Helper function:**
```elixir
defp following_ids_set(user_id, target_ids) do
  import Ecto.Query
  from(f in OGrupoDeEstudos.Engagement.Follow,
    where: f.follower_id == ^user_id and f.followed_id in ^target_ids,
    select: f.followed_id
  )
  |> OGrupoDeEstudos.Repo.all()
  |> MapSet.new()
end
```

**Import Badges:**
```elixir
alias OGrupoDeEstudos.Engagement.Badges
```

- [ ] **Step 2: Update the segmented control to 3 tabs**

In the template, find the section tabs loop. Change from 2 tabs to 3:

```heex
<%= for {sec_key, sec_label} <- [{"steps", "Passos"}, {"sequences", "Sequências"}, {"followers", "Seguidores"}] do %>
```

- [ ] **Step 3: Add the Seguidores section to template**

After the sequences section `<% end %>`, add:

```heex
<%!-- ===== SEGUIDORES SECTION ===== --%>
<%= if @active_section == "followers" do %>
  <div class="max-w-4xl mx-auto px-4 pt-4 pb-20 w-full box-border">
    <%!-- Counters --%>
    <div class="flex items-center gap-4 mb-4 text-sm">
      <button phx-click="switch_followers_tab" phx-value-tab="following"
        class={["font-medium", @followers_sub_tab == "following" && "text-ink-900", @followers_sub_tab != "following" && "text-ink-500"]}>
        <span class="font-bold">{@following_count}</span> seguindo
      </button>
      <span class="text-ink-300">·</span>
      <button phx-click="switch_followers_tab" phx-value-tab="followers"
        class={["font-medium", @followers_sub_tab == "followers" && "text-ink-900", @followers_sub_tab != "followers" && "text-ink-500"]}>
        <span class="font-bold">{@followers_count}</span> seguidores
      </button>
    </div>

    <%!-- Sub-tabs --%>
    <div class="flex gap-2 mb-3">
      <%= for {tab, label} <- [{"following", "Seguindo"}, {"followers", "Seguidores"}] do %>
        <button phx-click="switch_followers_tab" phx-value-tab={tab}
          class={[
            "py-1.5 px-4 rounded-full text-xs font-medium border transition-colors cursor-pointer",
            @followers_sub_tab == tab && "bg-accent-orange/10 border-accent-orange/30 text-accent-orange",
            @followers_sub_tab != tab && "bg-ink-50 border-ink-200 text-ink-500"
          ]}>
          {label}
        </button>
      <% end %>
    </div>

    <%!-- Search --%>
    <div class="relative mb-4">
      <.icon name="hero-magnifying-glass" class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
      <input type="text" phx-keyup="search_followers" phx-debounce="300" name="term"
        value={@followers_search} placeholder="Buscar por nome ou username..."
        class="w-full pl-9 pr-3 py-2 bg-ink-50 border border-ink-200 rounded-lg text-sm text-ink-700 focus:outline-none focus:ring-2 focus:ring-accent-orange/30" />
    </div>

    <%!-- User cards --%>
    <%= if @followers_list == [] do %>
      <div class="text-center py-16 text-ink-400 italic text-sm">
        <%= if @followers_sub_tab == "following" do %>
          Você ainda não segue ninguém. Explore a comunidade!
        <% else %>
          Nenhum seguidor ainda.
        <% end %>
      </div>
    <% else %>
      <div class="flex flex-col gap-2.5">
        <%= for person <- @followers_list do %>
          <% badge = Badges.primary(person.id) %>
          <% steps_count = length(OGrupoDeEstudos.Encyclopedia.list_user_steps(person.id)) %>
          <% seqs_count = length(OGrupoDeEstudos.Sequences.list_public_user_sequences(person.id)) %>
          <% is_following = MapSet.member?(@followers_following_map, person.id) %>
          <div class="flex items-center gap-3 p-3 bg-ink-50 rounded-lg border border-ink-100">
            <%!-- Avatar --%>
            <.link navigate={~p"/users/#{person.username}"} class="no-underline">
              <div class="w-10 h-10 rounded-full bg-ink-800 flex items-center justify-center text-ink-200 text-sm font-bold flex-shrink-0">
                {String.first(person.name || person.username) |> String.upcase()}
              </div>
            </.link>
            <%!-- Info --%>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-1.5">
                <.link navigate={~p"/users/#{person.username}"}
                  class="text-sm font-semibold text-ink-800 no-underline hover:underline truncate">
                  @{person.username}
                </.link>
                <span :if={badge} class="text-xs" title={badge.name}>{badge.icon}</span>
              </div>
              <%= if person.city do %>
                <p class="text-xs text-ink-500 mt-0.5">
                  {person.city}<%= if person.state, do: ", #{person.state}" %>
                </p>
              <% end %>
              <p class="text-xs text-ink-400 mt-0.5">
                {steps_count} passos · {seqs_count} sequências
              </p>
            </div>
            <%!-- Follow button --%>
            <button phx-click="toggle_follow" phx-value-user-id={person.id}
              class={[
                "text-xs py-1.5 px-4 rounded-full font-medium border transition-colors cursor-pointer flex-shrink-0",
                is_following && "bg-transparent border-accent-orange text-accent-orange",
                !is_following && "bg-accent-orange border-accent-orange text-white"
              ]}>
              {if is_following, do: "Seguindo ✓", else: "Seguir"}
            </button>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 4: Add mini follow button on author cards (steps + sequences)**

In the step card author area, after the `@username` link, add:

```heex
<%= if step.suggested_by_id && step.suggested_by_id != @current_user.id do %>
  <button phx-click="toggle_follow" phx-value-user-id={step.suggested_by_id}
    class="text-[10px] py-0.5 px-2 rounded-full border border-ink-300 text-ink-500 hover:border-accent-orange hover:text-accent-orange transition-colors cursor-pointer">
    Seguir
  </button>
<% end %>
```

Same pattern for sequence cards author area, using `seq.user_id`.

NOTE: The mini follow button is "fire and forget" — it doesn't track state (too expensive per card). It always shows "Seguir". If user already follows, clicking unfollows. This is acceptable for a quick action.

- [ ] **Step 5: Compile + test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

- [ ] **Step 6: Commit**

```bash
git add lib/o_grupo_de_estudos_web/live/community_live.ex lib/o_grupo_de_estudos_web/live/community_live.html.heex && git commit -m "feat: Seguidores tab in community with sub-tabs, search, user cards + mini follow buttons"
```

---

### Task 4: UserProfileLive — follow button + expanded stats grid

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/user_profile_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/user_profile_live.html.heex`

- [ ] **Step 1: Add follow data to mount**

In `user_profile_live.ex` mount, add:

```elixir
following_count = Engagement.count_following(user.id)
followers_count = Engagement.count_followers(user.id)
is_following = if !is_own_profile, do: Engagement.following?(current_user.id, user.id), else: false
```

Add to assigns:
```elixir
following_count: following_count,
followers_count: followers_count,
is_following: is_following
```

- [ ] **Step 2: Add toggle_follow handler**

```elixir
def handle_event("toggle_follow", _params, socket) do
  current = socket.assigns.current_user
  profile = socket.assigns.profile_user

  case Engagement.toggle_follow(current.id, profile.id) do
    {:ok, _} ->
      {:noreply, assign(socket,
        is_following: Engagement.following?(current.id, profile.id),
        following_count: Engagement.count_following(profile.id),
        followers_count: Engagement.count_followers(profile.id)
      )}
    {:error, _} -> {:noreply, socket}
  end
end
```

- [ ] **Step 3: Add follow button to template**

In the profile header, after the username/name area, before "Editar perfil" link, add:

```heex
<%= if !@is_own_profile do %>
  <button phx-click="toggle_follow"
    class={[
      "text-sm py-1.5 px-5 rounded-full font-medium border transition-colors cursor-pointer",
      @is_following && "bg-transparent border-accent-orange text-accent-orange",
      !@is_following && "bg-accent-orange border-accent-orange text-white"
    ]}>
    {if @is_following, do: "Seguindo ✓", else: "Seguir"}
  </button>
<% end %>
```

- [ ] **Step 4: Expand stats grid to 5 boxes**

In the stats grid section, add two more boxes:

```heex
<div class="flex-1 text-center p-3 rounded-lg bg-ink-50">
  <p class="text-2xl font-bold text-ink-800">{@following_count}</p>
  <p class="text-xs text-ink-500">seguindo</p>
</div>
<div class="flex-1 text-center p-3 rounded-lg bg-ink-50">
  <p class="text-2xl font-bold text-ink-800">{@followers_count}</p>
  <p class="text-xs text-ink-500">seguidores</p>
</div>
```

For mobile (5 boxes may be tight), consider wrapping with `flex-wrap`:

Change the grid container from `flex justify-center gap-2` to `flex flex-wrap justify-center gap-2`.

- [ ] **Step 5: Compile + test**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors && mix test
```

- [ ] **Step 6: Commit**

```bash
git add lib/o_grupo_de_estudos_web/live/user_profile_live.ex lib/o_grupo_de_estudos_web/live/user_profile_live.html.heex && git commit -m "feat: follow button on profile + expanded stats grid (seguindo + seguidores)"
```

---

### Task 5: Gate — full test suite + manual validation

- [ ] **Step 1: Run full test suite**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix test
```

- [ ] **Step 2: Compile clean**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix compile --warnings-as-errors
```

- [ ] **Step 3: Manual validation**

```bash
cd /Users/tavano/projects/personal/forrozin_page && mix phx.server
```

Check:
- [ ] `/community` shows 3 tabs: Passos, Sequências, Seguidores
- [ ] Seguidores tab shows counters (X seguindo · Y seguidores)
- [ ] Sub-tabs (Seguindo/Seguidores) switch lists
- [ ] Search filters by name/username
- [ ] User cards show avatar, username, badge, location, activity counters
- [ ] Follow/unfollow button toggles on user cards
- [ ] Mini "Seguir" button on step/sequence author cards
- [ ] `/users/:username` shows follow button (not on own profile)
- [ ] Stats grid shows 5 boxes including seguindo/seguidores
- [ ] Following/unfollowing updates counts immediately

- [ ] **Step 4: Push + deploy (user decision)**

```bash
git push origin main && fly deploy
```
