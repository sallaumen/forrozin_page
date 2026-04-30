# Sequences Community Editorial Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `/community` into a warmer, more discoverable sequences catalog while preserving the current social and map flows.

**Architecture:** Keep `OGrupoDeEstudosWeb.CommunityLive` as the single LiveView entrypoint, but split presentation concerns into clearer assigns and helper functions so the template can support an editorial hero, discovery rail, and upgraded cards without backend churn. Reuse the existing like, favorite, follow, comment, and map navigation behavior; only the view model and template structure should change in the first pass.

**Tech Stack:** Phoenix LiveView, HEEx, Tailwind CSS v4 utilities, existing `Sequences` and `Engagement` contexts, `Phoenix.LiveViewTest`

---

## File Structure

### Existing files to modify

- `lib/o_grupo_de_estudos_web/live/community_live.ex`
  - Keep the route and event entrypoint
  - Add lightweight helpers for tab state, editorial discovery sections, and normalized card presentation
- `lib/o_grupo_de_estudos_web/live/community_live.html.heex`
  - Replace the current “search + stacked list” composition with the new hero, discovery rail, and upgraded cards
- `test/o_grupo_de_estudos_web/live/community_live_test.exs`
  - Expand coverage from smoke tests to stable DOM assertions for the new hierarchy and retained interactions

### Optional file to modify only if needed

- `assets/css/app.css`
  - Only touch this if a small custom utility is genuinely needed for a visual treatment that Tailwind utilities alone cannot express cleanly

### Files intentionally out of scope

- `lib/o_grupo_de_estudos_web/live/graph_visual_live.ex`
- `lib/o_grupo_de_estudos_web/live/graph_visual_live.html.heex`
- sequence generator files
- router/auth files

---

### Task 1: Reshape the CommunityLive view model for editorial sections

**Files:**
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/community_live.ex`
- Test: `/Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/community_live_test.exs`

- [ ] **Step 1: Write the failing test for the new hero and discovery shell**

Add a focused describe block with stable DOM IDs that the redesign will introduce:

```elixir
describe "editorial shell" do
  test "renders hero, discovery rail, and sequence stream", %{conn: conn} do
    conn = logged_in_conn(conn)
    {:ok, view, _html} = live(conn, ~p"/community")

    assert has_element?(view, "#community-sequences-hero")
    assert has_element?(view, "#community-sequences-search")
    assert has_element?(view, "#community-sequences-create")
    assert has_element?(view, "#community-sequences-discovery")
    assert has_element?(view, "#community-sequences-stream")
  end
end
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/community_live_test.exs:1 -v
```

Expected:

- FAIL because the new IDs do not exist yet

- [ ] **Step 3: Add a small view-model layer in `CommunityLive`**

Refactor `mount/3`, search, sort, and tab switching so the template can consume clearer assigns. Keep the backend calls the same, but add helper functions such as:

```elixir
def mount(_params, _session, socket) do
  admin = Accounts.admin?(socket.assigns.current_user)
  current_user = socket.assigns.current_user

  community_sequences = load_public_sequences(current_user)

  {:ok,
   socket
   |> assign(:page_title, "Sequências")
   |> assign(:is_admin, admin)
   |> assign(:active_seq_tab, "community")
   |> assign(:seq_search, "")
   |> assign(:seq_sort, "popular")
   |> assign(:community_sequences_all, community_sequences)
   |> assign(:community_sequences, community_sequences)
   |> assign(:my_sequences, [])
   |> assign(:discovery_sections, build_discovery_sections(community_sequences, current_user.id))
   |> assign_social_state(current_user)}
end

defp load_public_sequences(current_user) do
  sequences = Sequences.list_all_public_sequences()
  ids = Enum.map(sequences, & &1.id)

  %{
    items: sort_sequences(sequences, "popular"),
    likes: Engagement.likes_map(current_user.id, "sequence", ids),
    favorites: Engagement.favorites_map(current_user.id, "sequence", ids),
    comment_counts: Engagement.comment_counts_for("sequence", ids)
  }
end

defp build_discovery_sections(%{items: sequences}, current_user_id) do
  [
    %{id: "trending", label: "Em alta", sequence_ids: Enum.map(Enum.take(sequences, 3), & &1.id)},
    %{id: "saved", label: "Salvas", sequence_ids: favorite_sequence_ids(current_user_id, sequences)},
    %{id: "following", label: "De quem você segue", sequence_ids: []}
  ]
end
```

The exact helper names can vary, but the structure should do two things:

- separate `community_sequences` from raw social metadata
- give the template a ready-to-render `discovery_sections` assign

- [ ] **Step 4: Keep existing behavior intact while rewiring events**

Update event handlers to operate on the new assigns rather than the current single `sequences/sequences_all` pair. For example:

```elixir
def handle_event("search_sequences", params, socket) do
  term = params["value"] || params["term"] || ""

  filtered =
    socket.assigns.community_sequences_all.items
    |> filter_sequences(term)
    |> sort_sequences(socket.assigns.seq_sort)

  {:noreply,
   socket
   |> assign(:seq_search, term)
   |> assign(:community_sequences, filtered)}
end

def handle_event("sort_sequences", %{"sort" => sort}, socket) do
  sorted =
    socket.assigns.community_sequences_all.items
    |> filter_sequences(socket.assigns.seq_search)
    |> sort_sequences(sort)

  {:noreply,
   socket
   |> assign(:seq_sort, sort)
   |> assign(:community_sequences, sorted)}
end
```

This keeps the behavior stable while making the template rewrite much easier.

- [ ] **Step 5: Run the focused test file again**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/community_live_test.exs -v
```

Expected:

- some tests may still fail because the template has not been updated yet
- no new compile errors from `CommunityLive`

- [ ] **Step 6: Commit the view-model refactor**

```bash
git add /Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/community_live.ex \
        /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/community_live_test.exs
git commit -m "refactor(sequences): reshape community live view model"
```

---

### Task 2: Rebuild the template as an editorial discovery page

**Files:**
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/community_live.html.heex`
- Test: `/Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/community_live_test.exs`

- [ ] **Step 1: Write failing DOM tests for the new sections and primary actions**

Extend the LiveView test file with assertions that capture the redesign without tying tests to fragile text:

```elixir
test "community cards keep profile and map navigation visible", %{conn: conn, sequence: seq, author: author} do
  {:ok, view, _html} = live(logged_in_conn(conn), ~p"/community")

  assert has_element?(view, "#sequence-card-#{seq.id}")
  assert has_element?(view, "#sequence-author-#{seq.id}[href='/users/#{author.username}']")
  assert has_element?(view, "#sequence-map-link-#{seq.id}[href='/graph/visual?seq=#{seq.id}']")
  assert has_element?(view, "#sequence-details-toggle-#{seq.id}")
end

test "mine tab keeps personal shelf shell", %{conn: conn} do
  conn = logged_in_conn(conn)
  {:ok, view, _html} = live(conn, ~p"/community")

  render_click(view, "switch_seq_tab", %{"tab" => "mine"})

  assert has_element?(view, "#community-sequences-hero")
  assert has_element?(view, "#my-sequences-stream")
end
```

- [ ] **Step 2: Run the test file to verify the new assertions fail**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/community_live_test.exs -v
```

Expected:

- FAIL because the template does not yet expose the new IDs and structure

- [ ] **Step 3: Rebuild the hero and discovery rail in HEEx**

Replace the current top section with a more intentional structure:

```heex
<Layouts.app flash={@flash} current_scope={@current_scope}>
  <div class="min-h-screen bg-ink-100 font-serif flex flex-col">
    <.top_nav ... />
    <.activity_toast toast={assigns[:activity_toast]} />

    <section
      id="community-sequences-hero"
      class="mx-auto mt-4 w-full max-w-6xl px-4 md:px-6"
    >
      <div class="rounded-2xl border border-ink-900/8 bg-ink-50 px-5 py-5 shadow-[0_16px_50px_rgba(60,40,20,0.07)]">
        <div class="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div class="max-w-2xl">
            <p class="text-[11px] font-bold uppercase tracking-[0.22em] text-accent-orange">
              Sequências
            </p>
            <h1 class="mt-2 text-3xl font-bold text-ink-900 md:text-4xl">
              Explore combinações que já nasceram dançando.
            </h1>
            <p class="mt-2 text-sm leading-6 text-ink-600">
              Descubra caminhos bons de abrir no mapa, salve o que fizer sentido e veja o que a comunidade está praticando.
            </p>
          </div>

          <.link
            id="community-sequences-create"
            navigate={~p"/graph/visual?mode=generator"}
            class="inline-flex min-h-11 items-center justify-center rounded-full bg-accent-green px-5 text-sm font-bold text-white no-underline transition hover:bg-accent-green/90"
          >
            + Criar sequência
          </.link>
        </div>
      </div>
    </section>

    <section id="community-sequences-discovery" class="mx-auto mt-4 w-full max-w-6xl px-4 md:px-6">
      ...
    </section>
```

Important:

- keep `<Layouts.app ...>` at the top if this LiveView is not already wrapped elsewhere
- add stable IDs
- keep search and sort inside the hero region, but subordinate to the title block

- [ ] **Step 4: Rebuild the card stream around a stronger action hierarchy**

Refactor the card markup so the primary CTA is visually obvious and the social layer is calmer:

```heex
<div id="community-sequences-stream" class="mt-6 grid gap-4 lg:grid-cols-2">
  <article
    :for={seq <- @community_sequences}
    id={"sequence-card-#{seq.id}"}
    class="group rounded-2xl border border-ink-900/8 bg-ink-50 p-4 shadow-[0_14px_40px_rgba(60,40,20,0.06)] transition hover:-translate-y-0.5 hover:shadow-[0_20px_50px_rgba(60,40,20,0.10)]"
  >
    <div class="flex items-start justify-between gap-3">
      <div class="min-w-0">
        <h2 class="text-lg font-bold leading-snug text-ink-900">{seq.name}</h2>
        <p class="mt-1 text-xs text-ink-500">{length(seq.sequence_steps)} passos</p>
      </div>

      <div class="flex items-center gap-2 text-xs text-ink-500">
        ...
      </div>
    </div>

    <div class="mt-3 flex flex-wrap gap-1.5">
      <%= for ss <- seq.sequence_steps do %>
        <code class="rounded-full border border-gold-500/15 bg-gold-500/10 px-2 py-1 text-[10px] font-bold text-ink-700">
          {ss.step.code}
        </code>
      <% end %>
    </div>

    <div class="mt-4 flex items-center gap-3">
      <.link id={"sequence-author-#{seq.id}"} navigate={~p"/users/#{author_username}"} class="inline-flex items-center gap-2 no-underline">
        ...
      </.link>

      <.link
        id={"sequence-map-link-#{seq.id}"}
        navigate={~p"/graph/visual?seq=#{seq.id}"}
        class="inline-flex min-h-10 items-center gap-2 rounded-full bg-accent-orange px-4 text-xs font-bold text-white no-underline transition hover:bg-accent-orange/90"
      >
        <.icon name="hero-map" class="size-4" /> Ver no mapa
      </.link>

      <button
        id={"sequence-details-toggle-#{seq.id}"}
        phx-click="toggle_seq_expand"
        phx-value-seq-id={seq.id}
        class="ml-auto inline-flex min-h-10 items-center gap-2 rounded-full border border-ink-900/10 px-3 text-xs font-medium text-ink-600 transition hover:border-ink-900/20 hover:text-ink-900"
      >
        Abrir detalhes
      </button>
    </div>
  </article>
</div>
```

Preserve:

- profile navigation
- map navigation
- like/favorite/follow events
- comment expansion
- video embed rendering

- [ ] **Step 5: Run the test file again**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/community_live_test.exs -v
```

Expected:

- the new DOM-structure tests pass
- some older tests may need selector updates if they were relying on loose HTML text

- [ ] **Step 6: Commit the template redesign**

```bash
git add /Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/community_live.html.heex \
        /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/community_live_test.exs
git commit -m "feat(sequences): redesign community page layout"
```

---

### Task 3: Distinguish `Minhas`, preserve interactions, and tighten regression coverage

**Files:**
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/community_live.ex`
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/community_live.html.heex`
- Test: `/Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/community_live_test.exs`

- [ ] **Step 1: Add failing tests for mine-mode structure and expansion regressions**

Add tests that prove the redesign did not break the behavior we care about most:

```elixir
test "expanded details still reveal comments region", %{conn: conn, sequence: seq} do
  {:ok, view, _html} = live(logged_in_conn(conn), ~p"/community")

  render_click(view, "toggle_seq_expand", %{"seq-id" => seq.id})

  assert has_element?(view, "#sequence-expanded-#{seq.id}")
  assert has_element?(view, "#sequence-comments-#{seq.id}")
end

test "mine tab uses a personal stream container", %{conn: conn} do
  user = insert(:user)
  section = insert(:section)
  step = insert(:step, section: section, code: "AA", name: "Autoral")
  sequence = insert(:sequence, user: user, public: true, name: "Minha sequência")
  insert(:sequence_step, sequence: sequence, step: step, position: 1)

  conn = log_in_user(conn, user)
  {:ok, view, _html} = live(conn, ~p"/community")

  render_click(view, "switch_seq_tab", %{"tab" => "mine"})

  assert has_element?(view, "#my-sequences-stream")
  assert has_element?(view, "#sequence-card-#{sequence.id}")
end
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/community_live_test.exs -v
```

Expected:

- FAIL until the expanded region and mine stream get the new IDs and structure

- [ ] **Step 3: Give `Minhas` a distinct shelf tone without forking the whole page**

Update the HEEx to keep a common hero shell while changing emphasis:

```heex
<%= if @active_seq_tab == "community" do %>
  <div id="community-sequences-stream" class="mt-6 grid gap-4 lg:grid-cols-2">
    ...
  </div>
<% else %>
  <section class="mx-auto mt-4 w-full max-w-6xl px-4 md:px-6">
    <div class="rounded-2xl border border-ink-900/8 bg-[#fffdf7] px-5 py-4">
      <p class="text-sm text-ink-600">
        Suas sequências salvas e publicadas, prontas para voltar ao mapa.
      </p>
    </div>
  </section>

  <div id="my-sequences-stream" class="mx-auto mt-6 grid w-full max-w-6xl gap-4 px-4 md:px-6 lg:grid-cols-2">
    ...
  </div>
<% end %>
```

This should make `Minhas` feel more personal without requiring a second full page design.

- [ ] **Step 4: Re-introduce expansion, comments, and embeds with stable wrappers**

Wrap the detail area in stable IDs so tests and future refactors stay solid:

```heex
<%= if is_expanded do %>
  <section
    id={"sequence-expanded-#{seq.id}"}
    class="mt-4 rounded-2xl border border-ink-900/8 bg-white/70 p-4"
  >
    <%= if seq.video_url do %>
      <div id={"sequence-video-#{seq.id}"} class="mb-4">
        ...
      </div>
    <% end %>

    <div id={"sequence-comments-#{seq.id}"}>
      <.comment_thread ... />
    </div>
  </section>
<% end %>
```

- [ ] **Step 5: Run the focused LiveView tests and then the precommit gate**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/community_live_test.exs -v
mix precommit
```

Expected:

- community live tests: PASS
- `mix precommit`: PASS

- [ ] **Step 6: Commit the interaction-safe polish**

```bash
git add /Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/community_live.ex \
        /Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/community_live.html.heex \
        /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/community_live_test.exs
git commit -m "feat(sequences): polish community interactions and mine mode"
```

---

## Self-Review

### Spec coverage

- hero/top section: covered in Task 2
- discovery rail: covered in Task 1 and Task 2
- stronger card hierarchy: covered in Task 2
- calmer social layer: covered in Task 2
- refined expansion area: covered in Task 3
- clearer `Minhas` tone: covered in Task 3
- profile/map navigation retention: covered in Task 2 and Task 3 tests

No uncovered spec sections remain for the first implementation slice.

### Placeholder scan

- no `TBD`
- no “add tests later”
- all code-touching tasks include concrete file paths and example code shapes

### Type consistency

- `community_sequences`, `community_sequences_all`, `discovery_sections`, `my_sequences`, and `active_seq_tab` are used consistently through the plan
- DOM IDs introduced in tests match the IDs specified in the HEEx steps

