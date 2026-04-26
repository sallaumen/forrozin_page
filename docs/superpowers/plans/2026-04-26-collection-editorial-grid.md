# Collection Editorial Grid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar a `Collection` em um acervo visual explorável com cards editoriais, drill-down progressivo, destaques por likes e um fluxo de sugestão contextual, bonito no web e no app, sem perder busca, filtros, drawer e colaboração.

**Architecture:** A primeira entrega vai reaproveitar a hierarquia real atual (`sections -> subsections -> steps`) e introduzir um read model específico para navegação editorial dentro do contexto `Encyclopedia`. O LiveView continuará dono dos eventos e da busca, mas passará a renderizar uma grade visual com estado explícito de overview, seção ativa, filtros recolhíveis e sugestão contextual; a taxonomia do banco fica intacta neste PR, usando o backup de produção apenas para validação e testes locais.

**Tech Stack:** Phoenix LiveView, Ecto, Tailwind CSS v4, CSS utilitária em `assets/css/app.css`, ExUnit, Phoenix.LiveViewTest, mix task `mix o_grupo_de_estudos.restore_backup`

---

## Production Snapshot

Usar este retrato para validar a leitura da coleção antes de qualquer ajuste de layout:

- `categories`: `11`
- `sections`: `21`
- `subsections`: `10`
- `steps`: `137`
- `likes`: `22`

Seções com papel claro para a navegação nova:

- `Bases`
- `Sacadas`
- `Sacada sem peso`
- `Giros`
- `Giro Paulista`
- `Pião`
- `Travas`
- `Pescadas`
- `Caminhadas`
- `Footwork & Variações Únicas`
- `Convenções da Notação`

Consequência de escopo: **não escrever migration estrutural neste PR**. A repaginação inteira já pode rodar em cima dessa árvore real; se depois da validação visual ainda valer reagrupar seções, isso entra em uma segunda rodada, com migration própria e restore validado no backup.

## File Structure

- Create: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos/encyclopedia/collection_browser.ex`
  - Read model puro para cards de overview, drill-down e featured steps.
- Create: `/Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos/encyclopedia/collection_browser_test.exs`
  - Testes unitários do read model editorial.
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos/encyclopedia.ex`
  - Expor uma função pública simples para montar a visão editorial a partir de `list_sections_with_steps/1`.
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.ex`
  - Novo estado de navegação (`overview`, `section drill-down`, `filters open`, `suggest section`), integração com o read model e reload consistente.
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.html.heex`
  - Hero mais curto, grid editorial, card de sugestão, filtros recolhíveis, subseções e featured steps.
- Modify: `/Users/tavano/projects/personal/forrozin_page/assets/css/app.css`
  - Classes compartilhadas para grid, placeholders quadrados, transições e melhor uso de ultra-wide.
- Modify: `/Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs`
  - Regressões da coleção antiga + novos fluxos do editorial grid.

## Environment Preflight

Antes de executar os tasks abaixo, alinhar o banco local com o backup atual de produção:

```bash
cd /Users/tavano/projects/personal/forrozin_page
cp /Users/tavano/Downloads/backup_20260426_141709.json priv/backups/
mix o_grupo_de_estudos.restore_backup priv/backups/backup_20260426_141709.json --clear
mix run -e 'alias OGrupoDeEstudos.Repo; alias OGrupoDeEstudos.Encyclopedia.{Category, Section, Subsection, Step}; IO.inspect(%{categories: Repo.aggregate(Category, :count, :id), sections: Repo.aggregate(Section, :count, :id), subsections: Repo.aggregate(Subsection, :count, :id), steps: Repo.aggregate(Step, :count, :id)})'
```

Expected:

```elixir
%{categories: 11, sections: 21, subsections: 10, steps: 137}
```

### Task 1: Add the editorial browse read model

**Files:**
- Create: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos/encyclopedia/collection_browser.ex`
- Create: `/Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos/encyclopedia/collection_browser_test.exs`
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos/encyclopedia.ex`

- [ ] **Step 1: Write the failing unit tests for section cards and featured steps**

```elixir
defmodule OGrupoDeEstudos.Encyclopedia.CollectionBrowserTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Encyclopedia.CollectionBrowser

  test "build_sections/1 returns at most three featured steps sorted by likes" do
    category = insert(:category, name: "sacadas", label: "Sacadas", color: "#ef5b8d")
    section = insert(:section, title: "Sacadas", code: "SC", position: 1, category: category)

    insert(:step, section: section, code: "SC-LOW", name: "Baixa", like_count: 1)
    insert(:step, section: section, code: "SC-HIGH", name: "Alta", like_count: 5)
    insert(:step, section: section, code: "SC-MID", name: "Média", like_count: 3)
    insert(:step, section: section, code: "SC-EXTRA", name: "Extra", like_count: 2)

    [card] =
      Encyclopedia.list_sections_with_steps()
      |> CollectionBrowser.build_sections()

    assert card.title == "Sacadas"
    assert card.step_count == 4
    assert card.popularity_score == 11
    assert Enum.map(card.featured_steps, & &1.code) == ["SC-HIGH", "SC-MID", "SC-EXTRA"]
  end

  test "section_details/2 keeps real subsections and exposes direct featured steps" do
    category = insert(:category, name: "giros", label: "Giros", color: "#8b5cf6")
    section = insert(:section, title: "Giros", code: "G", position: 1, category: category)
    subsection = insert(:subsection, section: section, title: "Giros simples", position: 1)

    insert(:step, section: section, subsection: subsection, code: "GS-1", name: "Primeiro", like_count: 4)
    insert(:step, section: section, subsection: subsection, code: "GS-2", name: "Segundo", like_count: 1)
    insert(:step, section: section, code: "GF-1", name: "Fora da subseção", like_count: 2)

    sections = Encyclopedia.list_sections_with_steps()
    details = CollectionBrowser.section_details(sections, section.id)

    assert details.id == section.id
    assert Enum.map(details.subsections, & &1.title) == ["Giros simples"]
    assert Enum.map(details.featured_steps, & &1.code) == ["GS-1", "GF-1", "GS-2"]
  end
end
```

- [ ] **Step 2: Run the unit tests to verify they fail**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos/encyclopedia/collection_browser_test.exs
```

Expected: FAIL with `CollectionBrowser` undefined or missing functions.

- [ ] **Step 3: Implement the minimal read model and context wrapper**

```elixir
defmodule OGrupoDeEstudos.Encyclopedia.CollectionBrowser do
  @moduledoc false

  def build_sections(sections) do
    Enum.map(sections, &build_section_card/1)
  end

  def section_details(sections, section_id) do
    sections
    |> Enum.find(&(&1.id == section_id))
    |> case do
      nil -> nil
      section -> build_section_details(section)
    end
  end

  defp build_section_card(section) do
    visible_steps = flatten_visible_steps(section)

    %{
      id: section.id,
      title: section.title,
      code: section.code,
      description: section.description,
      category_label: section.category && section.category.label,
      category_color: section.category && section.category.color,
      step_count: length(visible_steps),
      popularity_score: Enum.sum(Enum.map(visible_steps, &(&1.like_count || 0))),
      featured_steps: featured_steps(visible_steps),
      subsection_count: length(section.subsections),
      image_path: section_image_path(section)
    }
  end

  defp build_section_details(section) do
    visible_steps = flatten_visible_steps(section)

    %{
      id: section.id,
      title: section.title,
      code: section.code,
      description: section.description,
      category_label: section.category && section.category.label,
      category_color: section.category && section.category.color,
      featured_steps: featured_steps(visible_steps),
      subsections: Enum.map(section.subsections, &build_subsection_card/1)
    }
  end

  defp build_subsection_card(subsection) do
    %{
      id: subsection.id,
      title: subsection.title,
      note: subsection.note,
      step_count: length(subsection.steps),
      featured_steps: featured_steps(subsection.steps)
    }
  end

  defp flatten_visible_steps(section) do
    section.steps ++ Enum.flat_map(section.subsections, & &1.steps)
  end

  defp featured_steps(steps) do
    steps
    |> Enum.sort_by(&{-(&1.like_count || 0), &1.name})
    |> Enum.take(3)
  end

  defp section_image_path(section) do
    Enum.find_value(flatten_visible_steps(section), & &1.image_path)
  end
end
```

```elixir
def list_collection_browser(opts \\ []) do
  opts
  |> list_sections_with_steps()
  |> OGrupoDeEstudos.Encyclopedia.CollectionBrowser.build_sections()
end
```

- [ ] **Step 4: Run the unit tests again**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos/encyclopedia/collection_browser_test.exs
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add /Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos/encyclopedia/collection_browser.ex /Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos/encyclopedia.ex /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos/encyclopedia/collection_browser_test.exs
git commit -m "feat(collection): add editorial browse read model"
```

### Task 2: Refactor CollectionLive state around overview and drill-down

**Files:**
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.ex`
- Modify: `/Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs`

- [ ] **Step 1: Write failing LiveView tests for overview state and section drill-down**

```elixir
describe "editorial navigation" do
  test "renders the overview grid with a filter toggle and suggest card", %{conn: conn} do
    insert(:section, title: "Bases", position: 1)

    {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")

    assert has_element?(lv, "#collection-overview-grid")
    assert has_element?(lv, "#collection-filter-toggle")
    assert has_element?(lv, "#collection-suggest-card")
  end

  test "enter_section reorganizes the page around the selected section", %{conn: conn} do
    section = insert(:section, title: "Bases", code: "B", position: 1)
    insert(:step, section: section, code: "BF", name: "Base frontal", like_count: 2)

    {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
    render_click(lv, "enter_section", %{"section_id" => section.id})

    assert has_element?(lv, "#collection-drilldown-shell")
    assert has_element?(lv, "#collection-breadcrumb")
    assert has_element?(lv, "#collection-featured-step-BF")
  end
end
```

- [ ] **Step 2: Run the LiveView tests to verify they fail**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs
```

Expected: FAIL because the new IDs and events do not exist yet.

- [ ] **Step 3: Add explicit browse state, refresh helpers, and navigation events**

```elixir
socket =
  assign(socket,
    collection_cards: Encyclopedia.list_collection_browser(admin: admin),
    active_section_id: nil,
    active_section_card: nil,
    filters_open?: false,
    suggest_section_id: nil
  )
```

```elixir
def handle_event("toggle_filters", _params, socket) do
  {:noreply, assign(socket, :filters_open?, !socket.assigns.filters_open?)}
end

def handle_event("enter_section", %{"section_id" => section_id}, socket) do
  details = CollectionBrowser.section_details(socket.assigns.sections, section_id)

  {:noreply,
   assign(socket,
     active_section_id: section_id,
     active_section_card: details,
     suggest_section_id: section_id
   )}
end

def handle_event("back_to_overview", _params, socket) do
  {:noreply,
   assign(socket,
     active_section_id: nil,
     active_section_card: nil
   )}
end

defp reload_sections(socket) do
  sections = Encyclopedia.list_sections_with_steps(admin: socket.assigns.is_admin)

  assign(socket,
    sections: sections,
    collection_cards: CollectionBrowser.build_sections(sections),
    active_section_card: CollectionBrowser.section_details(sections, socket.assigns.active_section_id)
  )
end
```

- [ ] **Step 4: Re-run the LiveView tests**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs
```

Expected: the new navigation tests pass, while layout tests added later still fail.

- [ ] **Step 5: Commit**

```bash
git add /Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.ex /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs
git commit -m "feat(collection): add overview and drilldown state"
```

### Task 3: Rebuild the first fold with editorial hero, search, filters, and suggest card

**Files:**
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.html.heex`
- Modify: `/Users/tavano/projects/personal/forrozin_page/assets/css/app.css`
- Modify: `/Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs`

- [ ] **Step 1: Add failing tests for the new shell IDs and filter drawer**

```elixir
test "renders a condensed hero and collapsed filter panel by default", %{conn: conn} do
  {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")

  assert has_element?(lv, "#collection-hero")
  assert has_element?(lv, "#collection-search-form")
  assert has_element?(lv, "#collection-filter-toggle")
  refute has_element?(lv, "#collection-filter-panel")
end

test "toggle_filters opens the filter panel without leaving the overview", %{conn: conn} do
  {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
  render_click(lv, "toggle_filters", %{})
  assert has_element?(lv, "#collection-filter-panel")
  assert has_element?(lv, "#collection-overview-grid")
end
```

- [ ] **Step 2: Run the targeted tests**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs
```

Expected: FAIL with missing IDs or filter panel markup.

- [ ] **Step 3: Replace the current controls/header markup with the new editorial shell**

```heex
<div id="collection-hero" class="border-b border-ink-300/50 bg-ink-200 px-6 pt-10 pb-8">
  <div class="mx-auto max-w-[1680px]">
    <div class="max-w-3xl">
      <h1 class="text-4xl font-bold tracking-tight text-ink-900 md:text-5xl">
        O grupo de estudos.
      </h1>
      <p class="mt-3 max-w-2xl text-sm leading-6 text-ink-700 md:text-base">
        Descubra caminhos, atalhos e variações sem cair numa listona infinita.
      </p>
    </div>
  </div>
</div>

<div id="collection-editorial-toolbar" class="sticky top-[48px] z-30 border-b border-ink-300/40 bg-ink-200/95 px-6 py-4 backdrop-blur-sm md:top-[66px]">
  <div class="mx-auto flex max-w-[1680px] flex-wrap items-center gap-3">
    <form id="collection-search-form" phx-change="search" class="min-w-[220px] flex-1">
      <input name="term" value={@search} placeholder="Buscar por sigla, nome..." phx-debounce="250" class="w-full rounded-2xl border border-ink-300 bg-ink-50 px-4 py-3 text-sm text-ink-900 outline-none focus-visible:ring-2 focus-visible:ring-ink-900" />
    </form>

    <button id="collection-filter-toggle" phx-click="toggle_filters" class="inline-flex min-h-[44px] items-center gap-2 rounded-2xl border border-ink-300 bg-ink-50 px-4 text-sm font-semibold text-ink-700 transition hover:border-ink-500">
      <.icon name="hero-adjustments-horizontal" class="h-4 w-4" />
      Ajustes
    </button>
  </div>

  <div :if={@filters_open?} id="collection-filter-panel" class="mx-auto mt-3 max-w-[1680px] rounded-3xl border border-ink-300/70 bg-ink-50 p-4">
    <div class="flex flex-wrap gap-2">
      <button phx-click="filter" phx-value-category="all" class="rounded-full border border-ink-300 px-3 py-1.5 text-xs font-semibold text-ink-700">
        Todos
      </button>
      <button
        :for={category <- @categories}
        phx-click="filter"
        phx-value-category={category.name}
        style={"border-color: #{category.color}30; color: #{category.color}; background: #{category.color}12;"}
        class="rounded-full border px-3 py-1.5 text-xs font-semibold"
      >
        {category.label}
      </button>
    </div>
  </div>
</div>
```

```css
.collection-editorial-grid {
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
}

.collection-media-placeholder {
  aspect-ratio: 1 / 1;
  border-radius: 18px;
  background:
    radial-gradient(circle at top left, rgba(255, 255, 255, 0.28), transparent 48%),
    linear-gradient(135deg, rgba(44, 30, 16, 0.08), rgba(44, 30, 16, 0.02));
}
```

- [ ] **Step 4: Run the targeted LiveView tests again**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs
```

Expected: PASS for hero/filter panel coverage.

- [ ] **Step 5: Commit**

```bash
git add /Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.html.heex /Users/tavano/projects/personal/forrozin_page/assets/css/app.css /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs
git commit -m "feat(collection): rebuild editorial first fold"
```

### Task 4: Render overview cards, drill-down subsections, and featured steps

**Files:**
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.html.heex`
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.ex`
- Modify: `/Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs`

- [ ] **Step 1: Add failing tests for section cards, popularity, and featured steps**

```elixir
test "overview cards show popularity derived from steps and stay clickable", %{conn: conn} do
  category = insert(:category, name: "bases", label: "Bases", color: "#2e9f6b")
  section = insert(:section, title: "Bases", code: "B", position: 1, category: category)
  insert(:step, section: section, code: "BF", name: "Base frontal", like_count: 2)

  {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")

  assert has_element?(lv, "#collection-section-card-#{section.id}")
  assert has_element?(lv, "#collection-section-card-#{section.id} [data-role='popularity']")
end

test "drill-down shows real subsections plus up to three featured steps", %{conn: conn} do
  category = insert(:category, name: "giros", label: "Giros", color: "#8b5cf6")
  section = insert(:section, title: "Giros", code: "G", position: 1, category: category)
  subsection = insert(:subsection, section: section, title: "Giros simples", position: 1)
  insert(:step, section: section, subsection: subsection, code: "GS-1", name: "Primeiro", like_count: 4)

  {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
  render_click(lv, "enter_section", %{"section_id" => section.id})

  assert has_element?(lv, "#collection-subsection-card-#{subsection.id}")
  assert has_element?(lv, "#collection-featured-step-GS-1")
end
```

- [ ] **Step 2: Run the specific tests and capture the failure**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs
```

Expected: FAIL with missing cards and featured step markup.

- [ ] **Step 3: Implement the overview grid and the active section shell**

```heex
<%= if is_nil(@active_section_card) do %>
  <div id="collection-overview-grid" class="collection-editorial-grid">
    <article
      :for={card <- @collection_cards}
      id={"collection-section-card-#{card.id}"}
      class="group overflow-hidden rounded-[24px] border border-ink-300/60 bg-ink-50 shadow-sm transition duration-200 hover:-translate-y-0.5 hover:shadow-lg"
    >
      <button phx-click="enter_section" phx-value-section_id={card.id} class="block w-full text-left">
        <div class="collection-media-placeholder" />
        <div class="space-y-3 p-5">
          <div class="flex items-start justify-between gap-3">
            <div>
              <p class="text-[11px] uppercase tracking-[0.24em] text-ink-500">{card.category_label}</p>
              <h2 class="mt-1 text-2xl font-bold text-ink-900">{card.title}</h2>
            </div>
            <span data-role="popularity" class="rounded-full bg-ink-900 px-3 py-1 text-xs font-semibold text-ink-100">
              {card.popularity_score} likes
            </span>
          </div>
          <p class="text-sm leading-6 text-ink-600">
            {card.description || "#{card.step_count} passos prontos para explorar."}
          </p>
        </div>
      </button>
    </article>

    <article id="collection-suggest-card" class="rounded-[24px] border border-fuchsia-400/40 bg-fuchsia-500/10 p-5">
      <div class="flex h-full flex-col justify-between gap-5">
        <div class="space-y-3">
          <p class="text-[11px] uppercase tracking-[0.24em] text-fuchsia-700">Colaboração</p>
          <h2 class="text-2xl font-bold text-ink-900">Sugerir um passo</h2>
          <p class="text-sm leading-6 text-ink-700">
            Sentiu falta de alguma variação? Manda para a comunidade sem sair do acervo.
          </p>
        </div>

        <button
          phx-click="toggle_suggest"
          class="inline-flex min-h-[44px] items-center justify-center rounded-2xl bg-fuchsia-600 px-4 text-sm font-semibold text-white transition hover:bg-fuchsia-700"
        >
          Abrir sugestão
        </button>
      </div>
    </article>
  </div>
<% else %>
  <div id="collection-drilldown-shell" class="space-y-6">
    <div id="collection-breadcrumb" class="flex items-center gap-2 text-sm text-ink-600">
      <button phx-click="back_to_overview" class="font-semibold text-ink-900">Acervo</button>
      <span>/</span>
      <span>{@active_section_card.title}</span>
    </div>

    <section id="collection-featured-steps" class="collection-editorial-grid">
      <button
        :for={step <- @active_section_card.featured_steps}
        id={"collection-featured-step-#{step.code}"}
        phx-click="open_step"
        phx-value-code={step.code}
        class="rounded-[24px] border border-ink-300/60 bg-ink-50 p-5 text-left"
      >
        <div class="flex items-center justify-between gap-3">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.22em] text-ink-500">{step.code}</p>
            <h3 class="mt-2 text-xl font-bold text-ink-900">{step.name}</h3>
          </div>
          <span class="rounded-full bg-gold-500/15 px-3 py-1 text-xs font-semibold text-gold-700">{step.like_count} likes</span>
        </div>
      </button>
    </section>

    <section class="collection-editorial-grid">
      <article
        :for={subsection <- @active_section_card.subsections}
        id={"collection-subsection-card-#{subsection.id}"}
        class="rounded-[24px] border border-ink-300/60 bg-ink-50 p-5"
      >
        <div class="flex items-start justify-between gap-3">
          <div>
            <p class="text-[11px] uppercase tracking-[0.24em] text-ink-500">Subseção</p>
            <h3 class="mt-1 text-xl font-bold text-ink-900">{subsection.title}</h3>
          </div>
          <span class="rounded-full bg-ink-900/8 px-3 py-1 text-xs font-semibold text-ink-700">
            {subsection.step_count} passos
          </span>
        </div>

        <p :if={subsection.note} class="mt-3 text-sm leading-6 text-ink-600">
          {subsection.note}
        </p>

        <div class="mt-4 space-y-2">
          <button
            :for={step <- subsection.featured_steps}
            phx-click="open_step"
            phx-value-code={step.code}
            class="flex w-full items-center justify-between rounded-2xl border border-ink-200 bg-ink-100/70 px-3 py-2 text-left transition hover:border-ink-400"
          >
            <span>
              <span class="block text-[11px] font-semibold uppercase tracking-[0.2em] text-ink-500">{step.code}</span>
              <span class="block text-sm font-semibold text-ink-900">{step.name}</span>
            </span>
            <span class="text-xs font-semibold text-gold-700">{step.like_count} likes</span>
          </button>
        </div>
      </article>
    </section>
  </div>
<% end %>
```

- [ ] **Step 4: Re-run the tests**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs
```

Expected: PASS for overview/drill-down coverage.

- [ ] **Step 5: Commit**

```bash
git add /Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.ex /Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.html.heex /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs
git commit -m "feat(collection): add editorial grid and drilldown"
```

### Task 5: Reuse the drawer preview and make suggestion flow context-aware

**Files:**
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.ex`
- Modify: `/Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.html.heex`
- Modify: `/Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs`

- [ ] **Step 1: Add failing tests for featured-step preview and section-aware suggestion defaults**

```elixir
test "clicking a featured step reuses the drawer preview", %{conn: conn} do
  section = insert(:section, title: "Bases", code: "B", position: 1)
  insert(:step, section: section, code: "BF", name: "Base frontal", note: "Nota", like_count: 2)

  {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
  render_click(lv, "enter_section", %{"section_id" => section.id})
  render_click(lv, "open_step", %{"code" => "BF"})

  assert has_element?(lv, "#collection-drawer-header")
  assert render(lv) =~ "Base frontal"
end

test "opening suggest inside a section preselects that section", %{conn: conn} do
  section = insert(:section, title: "Sacadas", code: "SC", position: 1)

  {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
  render_click(lv, "enter_section", %{"section_id" => section.id})
  render_click(lv, "toggle_suggest", %{"section_id" => section.id})

  assert has_element?(lv, "#collection-suggest-form")
  assert has_element?(lv, "#collection-suggest-section option[selected][value='#{section.id}']")
end
```

- [ ] **Step 2: Run the targeted tests**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs
```

Expected: FAIL until the new suggest-section binding exists.

- [ ] **Step 3: Bind the suggest form to the active section and keep the drawer event path intact**

```elixir
def handle_event("toggle_suggest", params, socket) do
  selected_section_id =
    Map.get(params, "section_id") ||
      socket.assigns.suggest_section_id ||
      socket.assigns.active_section_id

  {:noreply,
   assign(socket,
     suggest_mode: !socket.assigns.suggest_mode,
     suggest_section_id: selected_section_id
   )}
end
```

```heex
<form
  :if={@suggest_mode}
  id="collection-suggest-form"
  phx-submit="create_suggested_step"
  class="rounded-[24px] border border-fuchsia-400/25 bg-fuchsia-500/5 p-5"
>
  <select
    id="collection-suggest-section"
    name="step[section_id]"
    value={@suggest_section_id || ""}
    class="w-full rounded-2xl border border-ink-300 bg-ink-50 px-3 py-2 text-sm text-ink-900"
  >
    <option value="">Sem seção</option>
    <%= for section <- @sections do %>
      <option value={section.id} selected={section.id == @suggest_section_id}>
        {section.title}
      </option>
    <% end %>
  </select>
</form>
```

- [ ] **Step 4: Re-run the tests**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add /Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.ex /Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.html.heex /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs
git commit -m "feat(collection): add contextual suggestion flow"
```

### Task 6: Finish responsive polish, keep regressions green, and verify manually

**Files:**
- Modify: `/Users/tavano/projects/personal/forrozin_page/assets/css/app.css`
- Modify: `/Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs`

- [ ] **Step 1: Add regression tests for search, `Meus passos`, and admin edit visibility**

```elixir
test "search still bypasses the editorial grid and shows matching steps", %{conn: conn} do
  section = insert(:section, title: "Bases", position: 1)
  insert(:step, section: section, code: "BF", name: "Base frontal")

  {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
  render_change(lv, "search", %{"term" => "base"})

  assert has_element?(lv, "#collection-search-results")
  refute has_element?(lv, "#collection-overview-grid")
end

test "admin still sees the top-nav edit button", %{conn: conn} do
  {:ok, lv, _html} = live(admin_conn(conn), ~p"/collection")
  assert has_element?(lv, "#top-nav-edit-button")
end
```

- [ ] **Step 2: Run the full collection test file**

Run:

```bash
mix test /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs
```

Expected: FAIL only where layout changes still need DOM IDs or search-result wrappers.

- [ ] **Step 3: Finish responsive CSS and result wrappers**

```css
@media (min-width: 1400px) {
  .collection-editorial-grid[data-density="overview"] {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }
}

@media (max-width: 767px) {
  .collection-editorial-grid {
    grid-template-columns: minmax(0, 1fr);
  }
}
```

```heex
<%= if @search != "" do %>
  <div id="collection-search-results" class="space-y-3">
    <.step_item
      :for={step <- @search_results}
      step={step}
      current_user_id={@current_user.id}
      steps_with_links={@steps_with_links}
      step_likes={@step_likes}
      expanded_step={@expanded_step}
      expanded_comments={@expanded_comments}
      expanded_links={@expanded_links}
      expanded_comment_likes={@expanded_comment_likes}
      expanded_replies_map={@expanded_replies_map}
      expanded_replying_to={@expanded_replying_to}
      expanded_video={@expanded_video}
      is_admin={@is_admin}
      current_user={@current_user}
    />
  </div>
<% end %>
```

- [ ] **Step 4: Run format and all automated checks**

Run:

```bash
mix format
mix precommit
```

Expected: all tests pass and the alias finishes cleanly.

- [ ] **Step 5: Validate manually in desktop and mobile layouts**

Run:

```bash
PORT=4006 mix phx.server
```

Check manually:

- `/collection` overview on desktop
- `/collection` overview on a narrow mobile viewport
- filter open/close behavior
- click into one macro section, verify breadcrumb + featured steps
- click a featured step, verify the drawer still opens
- open `Sugerir passo` from inside a section and confirm the section is preselected
- run a search and confirm the list results still show

- [ ] **Step 6: Commit**

```bash
git add /Users/tavano/projects/personal/forrozin_page/assets/css/app.css /Users/tavano/projects/personal/forrozin_page/test/o_grupo_de_estudos_web/live/collection_live_test.exs /Users/tavano/projects/personal/forrozin_page/lib/o_grupo_de_estudos_web/live/collection_live.html.heex
git commit -m "feat(collection): polish editorial collection experience"
```

## Out of Scope for This PR

- Mover passos entre seções reais no banco
- Fundir `Sacada sem peso`, `Giro Paulista` ou `Pião` por migration
- Upload das imagens definitivas da coleção
- Alterar a semântica do drawer de passo além do necessário para reaproveitá-lo como preview

## Self-Review

- Cobertura do spec:
  - grid editorial: Tasks 3 and 4
  - drill-down progressivo: Tasks 2 and 4
  - featured steps por likes: Tasks 1 and 4
  - `Sugerir passo` contextual: Task 5
  - busca e filtros preservados: Tasks 3 and 6
  - validação com backup real: Environment Preflight
- Placeholders:
  - nenhum `TODO`, `TBD` ou “implementar depois”
- Consistência de nomes:
  - `CollectionBrowser.build_sections/1`
  - `CollectionBrowser.section_details/2`
  - `toggle_filters`
  - `enter_section`
  - `back_to_overview`
  - `suggest_section_id`

## Execution Handoff

Plan complete and saved to `/Users/tavano/projects/personal/forrozin_page/docs/superpowers/plans/2026-04-26-collection-editorial-grid.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
