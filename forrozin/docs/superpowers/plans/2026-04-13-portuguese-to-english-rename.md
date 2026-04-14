# Portuguese → English Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename all internal Elixir identifiers (modules, functions, schema fields, file names, routes) from Portuguese to English while preserving all DB data and all user-facing Portuguese text.

**Architecture:** Big Bang — all changes in one session, executed sequentially by layer. The codebase will not compile cleanly between Tasks 2 and 8; `mix compile` is used after each task to catch syntax errors, full `mix test` only at Task 12.

**Tech Stack:** Elixir/Phoenix 1.7, Ecto, PostgreSQL, Phoenix LiveView, ExMachina, Oban

---

## ⚠️ Data Safety

Backups at `priv/backups/`:
- `backup_20260413_211128.json` — current DB state, Portuguese field names (restore with current code)
- `backup_20260413_211128_en.json` — same data, English field names (restore after this refactor)

`ALTER TABLE ... RENAME COLUMN` is PostgreSQL transactional DDL — zero data movement, rolls back on failure.

---

## File Map

### Files to CREATE (new paths)

| New path | Old path |
|---|---|
| `lib/forrozin/encyclopedia.ex` | `lib/forrozin/enciclopedia.ex` |
| `lib/forrozin/encyclopedia/step.ex` | `lib/forrozin/enciclopedia/passo.ex` |
| `lib/forrozin/encyclopedia/category.ex` | `lib/forrozin/enciclopedia/categoria.ex` |
| `lib/forrozin/encyclopedia/section.ex` | `lib/forrozin/enciclopedia/secao.ex` |
| `lib/forrozin/encyclopedia/subsection.ex` | `lib/forrozin/enciclopedia/subsecao.ex` |
| `lib/forrozin/encyclopedia/connection.ex` | `lib/forrozin/enciclopedia/conexao.ex` |
| `lib/forrozin/encyclopedia/technical_concept.ex` | `lib/forrozin/enciclopedia/conceito_tecnico.ex` |
| `lib/forrozin/encyclopedia/seeder.ex` | `lib/forrozin/enciclopedia/semeador.ex` |
| `lib/forrozin/workers/send_confirmation_email.ex` | `lib/forrozin/workers/enviar_email_confirmacao.ex` |
| `lib/forrozin/workers/periodic_backup.ex` | `lib/forrozin/workers/backup_periodico.ex` |
| `lib/forrozin_web/emails/confirmation_email.ex` | `lib/forrozin_web/emails/confirmacao_email.ex` |
| `lib/forrozin_web/live/collection_live.ex` | `lib/forrozin_web/live/acervo_live.ex` |
| `lib/forrozin_web/live/collection_live.html.heex` | `lib/forrozin_web/live/acervo_live.html.heex` |
| `lib/forrozin_web/live/step_live.ex` | `lib/forrozin_web/live/passo_live.ex` |
| `lib/forrozin_web/live/step_live.html.heex` | `lib/forrozin_web/live/passo_live.html.heex` |
| `lib/forrozin_web/live/graph_live.ex` | `lib/forrozin_web/live/grafo_live.ex` |
| `lib/forrozin_web/live/graph_live.html.heex` | `lib/forrozin_web/live/grafo_live.html.heex` |
| `lib/forrozin_web/live/graph_visual_live.ex` | `lib/forrozin_web/live/grafo_visual_live.ex` |
| `lib/forrozin_web/live/graph_visual_live.html.heex` | `lib/forrozin_web/live/grafo_visual_live.html.heex` |
| `lib/mix/tasks/forrozin.extract_connections.ex` | `lib/mix/tasks/forrozin.extrair_conexoes.ex` |
| `lib/mix/tasks/forrozin.restore_backup.ex` | `lib/mix/tasks/forrozin.restaurar_backup.ex` |

### Files to MODIFY (keep path)

`lib/forrozin/accounts.ex`, `lib/forrozin/accounts/user.ex`, `lib/forrozin/admin.ex`, `lib/forrozin/admin/backup.ex`, `lib/forrozin/application.ex`, `lib/forrozin_web/user_auth.ex`, `lib/forrozin_web/router.ex`, `lib/forrozin_web/controllers/user_session_controller.ex`, `lib/forrozin_web/controllers/user_confirmation_controller.ex`, `lib/forrozin_web/controllers/user_session_html/new.html.heex`, `lib/forrozin_web/controllers/user_confirmation_html/result.html.heex`, `lib/forrozin_web/components/layouts/root.html.heex`, `config/config.exs`, `priv/repo/seeds.exs`, `test/support/factory.ex`, all test files.

### Files to DELETE (after new files exist)

All Portuguese-named source files listed in the CREATE table above.

---

## Task 1: DB Migration — Column Renames + Enum Updates

**Files:**
- Create: `priv/repo/migrations/20260413220000_rename_columns_to_english.exs`

- [ ] **Step 1.1: Create the migration file**

```elixir
defmodule Forrozin.Repo.Migrations.RenameColumnsToEnglish do
  use Ecto.Migration

  def up do
    # ── passos ────────────────────────────────────────────────────
    rename table(:passos), :codigo, to: :code
    rename table(:passos), :nome, to: :name
    rename table(:passos), :nota, to: :note
    rename table(:passos), :caminho_imagem, to: :image_path
    rename table(:passos), :posicao, to: :position
    rename table(:passos), :categoria_id, to: :category_id
    rename table(:passos), :secao_id, to: :section_id
    rename table(:passos), :subsecao_id, to: :subsection_id

    execute "UPDATE passos SET status = 'published' WHERE status = 'publicado'"
    execute "UPDATE passos SET status = 'draft'     WHERE status = 'rascunho'"

    # ── categorias ────────────────────────────────────────────────
    rename table(:categorias), :nome, to: :name
    rename table(:categorias), :rotulo, to: :label
    rename table(:categorias), :cor, to: :color

    # ── secoes ────────────────────────────────────────────────────
    rename table(:secoes), :titulo, to: :title
    rename table(:secoes), :codigo, to: :code
    rename table(:secoes), :descricao, to: :description
    rename table(:secoes), :nota, to: :note
    rename table(:secoes), :posicao, to: :position
    rename table(:secoes), :categoria_id, to: :category_id

    # ── subsecoes ─────────────────────────────────────────────────
    rename table(:subsecoes), :titulo, to: :title
    rename table(:subsecoes), :nota, to: :note
    rename table(:subsecoes), :posicao, to: :position
    rename table(:subsecoes), :secao_id, to: :section_id

    # ── conexoes_passos ───────────────────────────────────────────
    rename table(:conexoes_passos), :tipo, to: :type
    rename table(:conexoes_passos), :rotulo, to: :label
    rename table(:conexoes_passos), :descricao, to: :description
    rename table(:conexoes_passos), :passo_origem_id, to: :source_step_id
    rename table(:conexoes_passos), :passo_destino_id, to: :target_step_id

    execute "UPDATE conexoes_passos SET type = 'exit'  WHERE type = 'saida'"
    execute "UPDATE conexoes_passos SET type = 'entry' WHERE type = 'entrada'"

    # ── conceitos_tecnicos ────────────────────────────────────────
    rename table(:conceitos_tecnicos), :titulo, to: :title
    rename table(:conceitos_tecnicos), :descricao, to: :description

    # ── usuarios ──────────────────────────────────────────────────
    rename table(:usuarios), :nome_usuario, to: :username
    rename table(:usuarios), :senha_hash, to: :password_hash
    rename table(:usuarios), :papel, to: :role

    # ── rename unique indexes so Ecto constraint checks still work ─
    execute "ALTER INDEX IF EXISTS passos_codigo_index
               RENAME TO passos_code_index"
    execute "ALTER INDEX IF EXISTS categorias_nome_index
               RENAME TO categorias_name_index"
    execute "ALTER INDEX IF EXISTS usuarios_nome_usuario_index
               RENAME TO usuarios_username_index"
    execute """
    ALTER INDEX IF EXISTS
      conexoes_passos_passo_origem_id_passo_destino_id_tipo_index
    RENAME TO
      conexoes_passos_source_step_id_target_step_id_type_index
    """
  end

  def down do
    raise "Irreversível — restaurar a partir do backup backup_20260413_211128.json"
  end
end
```

- [ ] **Step 1.2: Run the migration**

```bash
mix ecto.migrate
```

Expected output: `[info] == Running ... RenameColumnsToEnglish.up/0 ==`

- [ ] **Step 1.3: Verify column renames in DB**

```bash
mix run -e '
  %{rows: rows} = Forrozin.Repo.query!("SELECT column_name FROM information_schema.columns WHERE table_name = '"'"'passos'"'"' ORDER BY column_name")
  IO.inspect(Enum.map(rows, &hd/1))
'
```

Expected: list includes `"code"`, `"name"`, `"note"`, `"position"`, `"section_id"`, etc. (not `"codigo"` or `"nome"`).

- [ ] **Step 1.4: Verify enum updates**

```bash
mix run -e '
  %{rows: r} = Forrozin.Repo.query!("SELECT DISTINCT status FROM passos")
  IO.inspect(r)
  %{rows: r2} = Forrozin.Repo.query!("SELECT DISTINCT type FROM conexoes_passos")
  IO.inspect(r2)
'
```

Expected: `[["published"]]` (no `"publicado"`), `[["exit"]]` (no `"saida"`).

---

## Task 2: Schema Files — Create + Delete

> After this task the code won't compile until Task 4 (Encyclopedia context). `mix compile 2>&1 | grep error` will show errors — that's expected.

**Files:**
- Create all 6 new schema files + delete the 6 old ones
- The Seeder is handled in Task 3

- [ ] **Step 2.1: Create `lib/forrozin/encyclopedia/category.ex`**

```elixir
defmodule Forrozin.Encyclopedia.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:name, :label, :color]

  schema "categorias" do
    field :name, :string
    field :label, :string
    field :color, :string
    timestamps()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:name)
  end
end
```

- [ ] **Step 2.2: Create `lib/forrozin/encyclopedia/technical_concept.ex`**

```elixir
defmodule Forrozin.Encyclopedia.TechnicalConcept do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:title, :description]

  schema "conceitos_tecnicos" do
    field :title, :string
    field :description, :string
    timestamps()
  end

  def changeset(concept, attrs) do
    concept
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
  end
end
```

- [ ] **Step 2.3: Create `lib/forrozin/encyclopedia/section.ex`**

Read `lib/forrozin/enciclopedia/secao.ex` first to get the full changeset. Then write:

```elixir
defmodule Forrozin.Encyclopedia.Section do
  use Ecto.Schema
  import Ecto.Changeset

  alias Forrozin.Encyclopedia.{Category, Step, Subsection}

  @required_fields [:title, :position]
  @optional_fields [:num, :code, :description, :note, :category_id]

  schema "secoes" do
    field :num, :integer
    field :title, :string
    field :code, :string
    field :description, :string
    field :note, :string
    field :position, :integer

    belongs_to :category, Category
    has_many :steps, Step, foreign_key: :section_id
    has_many :subsections, Subsection, foreign_key: :section_id

    timestamps()
  end

  def changeset(section, attrs) do
    section
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
```

- [ ] **Step 2.4: Create `lib/forrozin/encyclopedia/subsection.ex`**

```elixir
defmodule Forrozin.Encyclopedia.Subsection do
  use Ecto.Schema
  import Ecto.Changeset

  alias Forrozin.Encyclopedia.{Section, Step}

  @required_fields [:title, :position, :section_id]
  @optional_fields [:note]

  schema "subsecoes" do
    field :title, :string
    field :note, :string
    field :position, :integer

    belongs_to :section, Section
    has_many :steps, Step, foreign_key: :subsection_id

    timestamps()
  end

  def changeset(subsection, attrs) do
    subsection
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
```

- [ ] **Step 2.5: Create `lib/forrozin/encyclopedia/connection.ex`**

```elixir
defmodule Forrozin.Encyclopedia.Connection do
  use Ecto.Schema
  import Ecto.Changeset

  alias Forrozin.Encyclopedia.Step

  @valid_types ["exit", "entry"]
  @required_fields [:source_step_id, :target_step_id, :type]
  @optional_fields [:label, :description]

  schema "conexoes_passos" do
    field :type, :string
    field :label, :string
    field :description, :string

    belongs_to :source_step, Step, foreign_key: :source_step_id
    belongs_to :target_step, Step, foreign_key: :target_step_id

    timestamps()
  end

  def changeset(connection, attrs) do
    connection
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:type, @valid_types)
    |> unique_constraint([:source_step_id, :target_step_id, :type])
  end
end
```

- [ ] **Step 2.6: Create `lib/forrozin/encyclopedia/step.ex`**

Read `lib/forrozin/enciclopedia/passo.ex` first to get the full changeset validation rules. Then write:

```elixir
defmodule Forrozin.Encyclopedia.Step do
  use Ecto.Schema
  import Ecto.Changeset

  alias Forrozin.Encyclopedia.{Category, Connection, Section, Subsection, TechnicalConcept}

  @required_fields [:code, :name]
  @optional_fields [
    :note, :image_path, :position, :wip, :status,
    :category_id, :section_id, :subsection_id
  ]

  schema "passos" do
    field :code, :string
    field :name, :string
    field :note, :string
    field :image_path, :string
    field :position, :integer
    field :wip, :boolean, default: false
    field :status, :string, default: "published"

    belongs_to :category, Category
    belongs_to :section, Section
    belongs_to :subsection, Subsection

    many_to_many :technical_concepts, TechnicalConcept,
      join_through: "conceitos_passos",
      join_keys: [passo_id: :id, conceito_id: :id]

    has_many :connections_as_source, Connection, foreign_key: :source_step_id
    has_many :connections_as_target, Connection, foreign_key: :target_step_id

    timestamps()
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:code, min: 1, max: 20)
    |> validate_inclusion(:status, ["published", "draft"])
    |> unique_constraint(:code)
  end
end
```

- [ ] **Step 2.7: Delete old schema files**

```bash
rm lib/forrozin/enciclopedia/passo.ex \
   lib/forrozin/enciclopedia/categoria.ex \
   lib/forrozin/enciclopedia/secao.ex \
   lib/forrozin/enciclopedia/subsecao.ex \
   lib/forrozin/enciclopedia/conexao.ex \
   lib/forrozin/enciclopedia/conceito_tecnico.ex
```

- [ ] **Step 2.8: Check for syntax errors (compilation errors expected)**

```bash
mix compile 2>&1 | grep "error\|warning" | head -30
```

Expected: errors referencing `Enciclopedia` modules not found — these are fixed in later tasks.

---

## Task 3: Seeder — Rename and Translate Internal Code

**Files:**
- Create: `lib/forrozin/encyclopedia/seeder.ex`
- Delete: `lib/forrozin/enciclopedia/semeador.ex`
- Modify: `priv/repo/seeds.exs`

- [ ] **Step 3.1: Read the current semeador**

Read `lib/forrozin/enciclopedia/semeador.ex` in full — it is long and must be preserved exactly (the data inside is in Portuguese and stays Portuguese). Only rename:
- `defmodule Forrozin.Enciclopedia.Semeador` → `defmodule Forrozin.Encyclopedia.Seeder`
- `alias Forrozin.Enciclopedia.{Categoria, Passo, Secao, Subsecao}` → `alias Forrozin.Encyclopedia.{Category, Step, Section, Subsection}`
- The public function `semear!/0` → `seed!/0`
- Internal `@categorias` → `@categories`
- Internal `@secoes` → `@sections`
- Internal variable names: `categorias_map` → `categories_map`, `secao` → `section`, etc.
- Schema struct field names: `%Categoria{nome: ..., rotulo: ..., cor: ...}` → `%Category{name: ..., label: ..., color: ...}`, `%Secao{titulo: ..., posicao: ...}` → `%Section{title: ..., position: ...}`, etc.
- Step struct fields: `%Passo{codigo: ..., nome: ..., nota: ..., wip: ...}` → `%Step{code: ..., name: ..., note: ..., wip: ...}`
- Status values: `"publicado"` → `"published"`
- Alias references to `Categoria` → `Category`, `Passo` → `Step`, `Secao` → `Section`, `Subsecao` → `Subsection`

Save the result at `lib/forrozin/encyclopedia/seeder.ex`.

- [ ] **Step 3.2: Delete old file**

```bash
rm lib/forrozin/enciclopedia/semeador.ex
```

- [ ] **Step 3.3: Update `priv/repo/seeds.exs`**

Read the current `priv/repo/seeds.exs`. It will contain a call like:
```elixir
Forrozin.Enciclopedia.Semeador.semear!()
```
Replace with:
```elixir
Forrozin.Encyclopedia.Seeder.seed!()
```

- [ ] **Step 3.4: Check for syntax errors**

```bash
mix compile 2>&1 | grep "error" | head -20
```

---

## Task 4: Encyclopedia Context

**Files:**
- Create: `lib/forrozin/encyclopedia.ex`
- Delete: `lib/forrozin/enciclopedia.ex`
- Delete: `lib/forrozin/enciclopedia/` directory (should be empty now)

- [ ] **Step 4.1: Create `lib/forrozin/encyclopedia.ex`**

```elixir
defmodule Forrozin.Encyclopedia do
  @moduledoc """
  Read context for the dance step encyclopedia.

  Pure calculation module: all functions are DB queries with no side effects.
  Step visibility is controlled here — steps with `wip: true` or
  `status: "draft"` are not returned to the public.
  """

  import Ecto.Query

  alias Forrozin.Encyclopedia.{Category, TechnicalConcept, Connection, Step, Section}
  alias Forrozin.Repo

  # ---------------------------------------------------------------------------
  # Categories
  # ---------------------------------------------------------------------------

  @doc "Lists all categories ordered by label."
  def list_categories do
    Category
    |> order_by([c], asc: c.label)
    |> Repo.all()
  end

  @doc "Finds a category by its internal name (e.g. 'sacadas', 'bases')."
  def get_category_by_name(name) do
    case Repo.get_by(Category, name: name) do
      nil -> {:error, :not_found}
      category -> {:ok, category}
    end
  end

  # ---------------------------------------------------------------------------
  # Sections
  # ---------------------------------------------------------------------------

  @doc "Lists all sections ordered by position."
  def list_sections do
    Section
    |> order_by([s], asc: s.position)
    |> Repo.all()
  end

  @doc """
  Lists sections with steps and subsections preloaded.

  Options:
  - `admin: true` — includes `wip` steps (for administrators).

  By default omits `wip` and `draft` steps (public visibility).
  """
  def list_sections_with_steps(opts \\ []) do
    admin = Keyword.get(opts, :admin, false)

    visible_steps =
      from(p in Step,
        where:
          ^if(admin,
            do: dynamic([p], p.status == "published"),
            else: dynamic([p], p.wip == false and p.status == "published")
          ),
        order_by: [asc: p.position]
      )

    Section
    |> order_by([s], asc: s.position)
    |> Repo.all()
    |> Repo.preload([
      :category,
      steps: visible_steps,
      subsections: [steps: visible_steps]
    ])
  end

  # ---------------------------------------------------------------------------
  # Steps
  # ---------------------------------------------------------------------------

  @doc "Counts total published, non-wip steps (public count)."
  def count_public_steps do
    Step
    |> where([p], p.wip == false and p.status == "published")
    |> Repo.aggregate(:count)
  end

  @doc """
  Finds a step by its unique code (e.g. "BF", "GP-D").

  Respects visibility policy: wip or draft steps return
  `{:error, :not_found}` for the public.
  """
  def get_step_by_code(code) do
    query =
      from(p in Step,
        where: p.code == ^code and p.wip == false and p.status == "published"
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      step -> {:ok, step}
    end
  end

  @doc """
  Finds a step with full details: category, technical concepts and connections.

  Options:
  - `admin: true` — includes `wip` steps.
  """
  def get_step_with_details(code, opts \\ []) do
    admin = Keyword.get(opts, :admin, false)

    query =
      if admin do
        from(p in Step, where: p.code == ^code and p.status == "published")
      else
        from(p in Step,
          where: p.code == ^code and p.wip == false and p.status == "published"
        )
      end

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      step ->
        step =
          Repo.preload(step, [
            :category,
            :technical_concepts,
            connections_as_source: :target_step,
            connections_as_target: :source_step
          ])

        {:ok, step}
    end
  end

  @doc """
  Searches steps by name (case-insensitive, partial match).

  Options:
  - `admin: true` — includes `wip` steps.

  By default returns only public steps.
  """
  def search_steps(term, opts \\ []) do
    admin = Keyword.get(opts, :admin, false)
    term_lower = String.downcase(term)

    base_query =
      from(p in Step,
        where:
          p.status == "published" and fragment("lower(?)", p.name) |> like(^"%#{term_lower}%"),
        order_by: [asc: p.name]
      )

    query = if admin, do: base_query, else: where(base_query, [p], p.wip == false)

    Repo.all(query)
  end

  # ---------------------------------------------------------------------------
  # Graph
  # ---------------------------------------------------------------------------

  @doc """
  Returns the connection graph between steps.

  Returns a map with:
  - `:nodes` — list of visible steps with `:category` preloaded, ordered by name.
  - `:edges` — list of connections between visible steps, with `:source_step`
    and `:target_step` preloaded.

  Options:
  - `admin: true` — includes `wip` steps in both nodes and edges.
  """
  def build_graph(opts \\ []) do
    admin = Keyword.get(opts, :admin, false)

    nodes =
      from(p in Step,
        where:
          ^if(admin,
            do: dynamic([p], p.status == "published"),
            else: dynamic([p], p.wip == false and p.status == "published")
          ),
        order_by: [asc: p.name],
        preload: [:category]
      )
      |> Repo.all()

    step_ids = Enum.map(nodes, & &1.id)

    edges =
      from(c in Connection,
        where: c.source_step_id in ^step_ids and c.target_step_id in ^step_ids,
        preload: [:source_step, :target_step]
      )
      |> Repo.all()

    %{nodes: nodes, edges: edges}
  end

  @doc """
  Returns all steps (including wip) indexed by code.

  Internal use: Mix tasks for seeding and connection extraction.
  Returns `%{code => step}`.
  """
  def list_all_steps_map do
    Step
    |> Repo.all()
    |> Map.new(&{&1.code, &1})
  end

  # ---------------------------------------------------------------------------
  # Technical Concepts
  # ---------------------------------------------------------------------------

  @doc "Lists all technical concepts ordered by title."
  def list_technical_concepts do
    TechnicalConcept
    |> order_by([c], asc: c.title)
    |> Repo.all()
  end
end
```

- [ ] **Step 4.2: Delete old context file and empty directory**

```bash
rm lib/forrozin/enciclopedia.ex
rmdir lib/forrozin/enciclopedia/ 2>/dev/null || true
```

- [ ] **Step 4.3: Check for syntax errors**

```bash
mix compile 2>&1 | grep "error" | head -20
```

---

## Task 5: Accounts Context + User Schema

**Files:**
- Modify: `lib/forrozin/accounts/user.ex`
- Modify: `lib/forrozin/accounts.ex`

- [ ] **Step 5.1: Read `lib/forrozin/accounts/user.ex`** in full first.

- [ ] **Step 5.2: Update `lib/forrozin/accounts/user.ex`**

Apply these renames throughout the file:
- `schema "usuarios"` — stays `"usuarios"` (table name unchanged)
- `field :nome_usuario` → `field :username`
- `field :senha, :string, virtual: true` → `field :password, :string, virtual: true` (if present)
- `field :senha_hash` → `field :password_hash`
- `field :papel` → `field :role`
- `@campos_obrigatorios` → `@required_fields`
- `@campos_opcionais` → `@optional_fields`
- `def changeset_registro` → `def registration_changeset`
- `def changeset_confirmacao` → `def confirmation_changeset`
- `defp hash_senha` → `defp hash_password`
- Inside `hash_password`: `senha_hash: Argon2.hash_pwd_salt(senha)` → `password_hash: Argon2.hash_pwd_salt(password)` (update local variable names)
- Cast references: `cast(attrs, [:nome_usuario, :email, :senha])` → `cast(attrs, [:username, :email, :password])`
- Validate references: `validate_length(:senha, ...)` → `validate_length(:password, ...)`
- `put_change(:senha_hash, ...)` → `put_change(:password_hash, ...)`

- [ ] **Step 5.3: Update `lib/forrozin/accounts.ex`**

```elixir
defmodule Forrozin.Accounts do
  @moduledoc """
  Action context responsible for users and authentication.
  """

  alias Forrozin.Accounts.User
  alias Forrozin.Repo
  alias Forrozin.Workers.SendConfirmationEmail

  @doc """
  Registers a new user and enqueues the confirmation email.

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  def register_user(attrs) do
    token = generate_token()

    changeset =
      %User{}
      |> User.registration_changeset(attrs)
      |> Ecto.Changeset.put_change(:confirmation_token, token)

    case Repo.insert(changeset) do
      {:ok, user} ->
        %{user_id: user.id}
        |> SendConfirmationEmail.new()
        |> Oban.insert()

        {:ok, user}

      error ->
        error
    end
  end

  @doc """
  Confirms a user's email by token.

  Returns `{:ok, user}` or `{:error, :invalid_token}`.
  """
  def confirm_email(token) do
    case Repo.get_by(User, confirmation_token: token) do
      nil -> {:error, :invalid_token}
      user -> user |> User.confirmation_changeset() |> Repo.update()
    end
  end

  @doc "Returns `true` if the user has confirmed their email."
  def email_confirmed?(%User{confirmed_at: confirmed_at}), do: confirmed_at != nil
  def email_confirmed?(_), do: false

  @doc """
  Authenticates a user by username and password.

  Returns `{:ok, user}` if credentials are valid,
  `{:error, :invalid_credentials}` otherwise.

  Always runs password verification to prevent timing attacks.
  """
  def authenticate_user(username, password) do
    user = Repo.get_by(User, username: username)
    verify_password(user, password)
  end

  defp verify_password(nil, _password) do
    Argon2.no_user_verify()
    {:error, :invalid_credentials}
  end

  defp verify_password(user, password) do
    if Argon2.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end

  @doc "Finds a user by id. Returns `nil` if not found."
  def get_user_by_id(id) do
    Repo.get(User, id)
  end

  @doc "Checks if the user has the admin role."
  def admin?(%User{role: "admin"}), do: true
  def admin?(_), do: false

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
```

- [ ] **Step 5.4: Check for syntax errors**

```bash
mix compile 2>&1 | grep "error" | head -20
```

---

## Task 6: Admin Context + Backup

**Files:**
- Modify: `lib/forrozin/admin.ex`
- Modify: `lib/forrozin/admin/backup.ex`

- [ ] **Step 6.1: Update `lib/forrozin/admin.ex`**

```elixir
defmodule Forrozin.Admin do
  @moduledoc """
  Administrative action context.

  Responsible for operations that modify the encyclopedia state.
  Authorization is the responsibility of the Web layer (LiveViews/Plugs).
  """

  alias Forrozin.Encyclopedia.Connection
  alias Forrozin.Repo

  @doc """
  Creates a directional connection between two steps.

  Returns `{:ok, connection}` or `{:error, changeset}`.
  """
  def create_connection(attrs) do
    %Connection{}
    |> Connection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates the label or description of an existing connection.

  Returns `{:ok, connection}` or `{:error, :not_found}`.
  """
  def update_connection(id, attrs) do
    case Repo.get(Connection, id) do
      nil -> {:error, :not_found}
      connection -> connection |> Connection.changeset(attrs) |> Repo.update()
    end
  end

  @doc """
  Removes a connection by ID.

  Returns `{:ok, connection}` or `{:error, :not_found}`.
  """
  def delete_connection(id) do
    case Repo.get(Connection, id) do
      nil -> {:error, :not_found}
      connection -> Repo.delete(connection)
    end
  end
end
```

- [ ] **Step 6.2: Update `lib/forrozin/admin/backup.ex`**

Read the current file in full first. Then apply these renames:
- `alias Forrozin.Encyclopedia.{Category, TechnicalConcept, Connection, Step, Section, Subsection}`
- `@schemas_ordenados` → `@ordered_schemas`
- `@max_backups` → stays `@max_backups`
- `def criar_backup!` → `def create_backup!`
- `def restaurar_backup!` → `def restore_backup!`
- `def listar_backups` → `def list_backups`
- `defp dump_schema` → stays `dump_schema` (already English)
- `defp dump_join_table` → stays (already English)
- `defp serializar_valor` → `defp serialize_value`
- `defp restaurar_schema` → `defp restore_schema`
- `defp restaurar_join_table` → `defp restore_join_table`
- `defp deserializar_valor` → `defp deserialize_value`
- `defp nome_arquivo` → `defp filename`
- `defp limpar_antigos!` → `defp cleanup_old!`
- `defp default_dir` → stays `default_dir` (already English)
- Update `@ordered_schemas` list to use new schema module names:
  ```elixir
  @ordered_schemas [
    {"categorias", Category},
    {"secoes", Section},
    {"subsecoes", Subsection},
    {"passos", Step},
    {"conceitos_tecnicos", TechnicalConcept},
    {"conexoes_passos", Connection}
  ]
  ```
- Inside `create_backup!`: call `cleanup_old!(dir)` and `filename()`
- Inside the private functions: update all internal calls to match renamed function names

- [ ] **Step 6.3: Check for syntax errors**

```bash
mix compile 2>&1 | grep "error" | head -20
```

---

## Task 7: Workers + Email Module

**Files:**
- Create: `lib/forrozin/workers/send_confirmation_email.ex`
- Create: `lib/forrozin/workers/periodic_backup.ex`
- Create: `lib/forrozin_web/emails/confirmation_email.ex`
- Delete: `lib/forrozin/workers/enviar_email_confirmacao.ex`
- Delete: `lib/forrozin/workers/backup_periodico.ex`
- Delete: `lib/forrozin_web/emails/confirmacao_email.ex`
- Modify: `config/config.exs`

- [ ] **Step 7.1: Create `lib/forrozin/workers/send_confirmation_email.ex`**

Read `lib/forrozin/workers/enviar_email_confirmacao.ex` first. Then write:

```elixir
defmodule Forrozin.Workers.SendConfirmationEmail do
  @moduledoc """
  Oban worker that sends the confirmation email after user registration.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  alias Forrozin.Accounts
  alias ForrozinWeb.Emails.ConfirmationEmail

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    user = Accounts.get_user_by_id(user_id)

    if user do
      ConfirmationEmail.new(user) |> Forrozin.Mailer.deliver()
    end

    :ok
  end
end
```

- [ ] **Step 7.2: Create `lib/forrozin/workers/periodic_backup.ex`**

```elixir
defmodule Forrozin.Workers.PeriodicBackup do
  @moduledoc """
  Oban worker that generates periodic database backups.

  Scheduled via Oban Cron to run every hour.
  Accepts an optional `"dir"` argument to ease testing.
  """

  use Oban.Worker, queue: :backup, max_attempts: 2

  alias Forrozin.Admin.Backup

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    dir = Map.get(args, "dir")

    if dir do
      Backup.create_backup!(dir)
    else
      Backup.create_backup!()
    end

    :ok
  end
end
```

- [ ] **Step 7.3: Read and create `lib/forrozin_web/emails/confirmation_email.ex`**

Read `lib/forrozin_web/emails/confirmacao_email.ex` first. Then write the new file with:
- `defmodule ForrozinWeb.Emails.ConfirmationEmail`
- `@sender` (if the attribute was named `@remetente`, rename it)
- `def new(user)` (was `def novo(user)`)
- Internal function names: any Portuguese helper functions → English
- Route references: `~p"/confirmar/#{token}"` → `~p"/confirm/#{token}"`
- The email body text is user-facing → keep in Portuguese as-is

- [ ] **Step 7.4: Delete old files**

```bash
rm lib/forrozin/workers/enviar_email_confirmacao.ex \
   lib/forrozin/workers/backup_periodico.ex \
   lib/forrozin_web/emails/confirmacao_email.ex
```

- [ ] **Step 7.5: Update `config/config.exs` — Oban cron worker reference**

Find the Oban crontab configuration. It will reference `Forrozin.Workers.BackupPeriodico`. Change to:

```elixir
{Oban.Plugins.Cron,
  crontab: [
    {"@hourly", Forrozin.Workers.PeriodicBackup}
  ]}
```

- [ ] **Step 7.6: Check for syntax errors**

```bash
mix compile 2>&1 | grep "error" | head -20
```

---

## Task 8: LiveViews + Templates

**Files:**
- Create/delete all 8 LiveView files (4 `.ex` + 4 `.html.heex`)

- [ ] **Step 8.1: Create `lib/forrozin_web/live/collection_live.ex`**

Read `lib/forrozin_web/live/acervo_live.ex` first. Then write:

```elixir
defmodule ForrozinWeb.CollectionLive do
  @moduledoc """
  Encyclopedia of dance steps.

  Requires authentication. Step wip/draft visibility is controlled
  in the `Encyclopedia` context, never here.
  """

  use ForrozinWeb, :live_view

  alias Forrozin.Accounts
  alias Forrozin.Encyclopedia

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    sections = Encyclopedia.list_sections_with_steps(admin: admin)
    categories = Encyclopedia.list_categories()
    open_sections = Map.new(sections, fn s -> {s.id, false} end)

    socket =
      assign(socket,
        sections: sections,
        categories: categories,
        open_sections: open_sections,
        search: "",
        search_results: [],
        category_filter: "all",
        email_confirmed: Accounts.email_confirmed?(socket.assigns.current_user),
        page_title: "Acervo"
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"termo" => term}, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    results = if term == "", do: [], else: Encyclopedia.search_steps(term, admin: admin)
    {:noreply, assign(socket, search: term, search_results: results)}
  end

  def handle_event("filter", %{"categoria" => category}, socket) do
    {:noreply, assign(socket, category_filter: category)}
  end

  def handle_event("toggle_section", %{"section_id" => id}, socket) do
    open_sections = Map.update(socket.assigns.open_sections, id, true, fn a -> !a end)
    {:noreply, assign(socket, open_sections: open_sections)}
  end

  def handle_event("expand_all", _params, socket) do
    open_sections = Map.new(socket.assigns.sections, fn s -> {s.id, true} end)
    {:noreply, assign(socket, open_sections: open_sections)}
  end

  def handle_event("collapse_all", _params, socket) do
    open_sections = Map.new(socket.assigns.sections, fn s -> {s.id, false} end)
    {:noreply, assign(socket, open_sections: open_sections)}
  end

  # ---------------------------------------------------------------------------
  # Components
  # ---------------------------------------------------------------------------

  attr :section, :map, required: true
  attr :open, :boolean, required: true

  def section_card(assigns) do
    ~H"""
    <div
      class="mb-2 rounded overflow-hidden"
      style={"border: 1px solid #{if @open, do: "rgba(60,40,20,0.2)", else: "rgba(60,40,20,0.1)"}; background: #{if @open, do: "#fffef9", else: "#fdfcf7"}"}
    >
      <button
        phx-click="toggle_section"
        phx-value-section_id={@section.id}
        class="w-full text-left flex items-center gap-3 px-5 py-3"
        style="background: transparent; border: none; cursor: pointer;"
      >
        <span style={"color: #{category_color(@section)}; font-size: 10px; display: inline-block; transform: #{if @open, do: "rotate(90deg)", else: "rotate(0deg)"}; transition: transform 0.15s;"}>
          ▶
        </span>
        <span class="flex items-center gap-3 flex-wrap flex-1">
          <%= if @section.num do %>
            <span style="font-size: 11px; color: #aaa; font-family: Georgia, serif; font-style: italic;">
              {@section.num}.
            </span>
          <% end %>
          <%= if @section.code do %>
            <code style={"font-size: 11px; color: #{category_color(@section)}; background: #{category_color(@section)}15; padding: 2px 8px; border-radius: 3px; border: 1px solid #{category_color(@section)}30; letter-spacing: 0.5px;"}>
              {@section.code}
            </code>
          <% end %>
          <span style="font-size: 15px; font-weight: 700; color: #1a0e05; font-family: Georgia, serif; letter-spacing: -0.2px;">
            {@section.title}
          </span>
          <span style={"font-size: 10px; color: #{category_color(@section)}; background: #{category_color(@section)}15; padding: 1px 8px; border-radius: 10px; font-family: Georgia, serif; font-style: italic; border: 1px solid #{category_color(@section)}25;"}>
            {category_label(@section)}
          </span>
        </span>
      </button>
      <%= if @open do %>
        <div style="padding: 4px 24px 20px 54px;">
          <%= if @section.description do %>
            <p style="font-size: 13px; color: #7a5c3a; font-style: italic; margin-bottom: 12px; line-height: 1.7; font-family: Georgia, serif;">
              {@section.description}
            </p>
          <% end %>
          <%= if @section.note do %>
            <div style="font-size: 12px; color: #5c3a1a; background: rgba(212,160,84,0.1); border: 1px solid rgba(212,160,84,0.3); border-left: 3px solid #d4a054; border-radius: 0 4px 4px 0; padding: 8px 14px; margin: 0 0 14px; font-family: Georgia, serif; font-style: italic; line-height: 1.7;">
              {@section.note}
            </div>
          <% end %>
          <%= for step <- @section.steps do %>
            <.step_item step={step} />
          <% end %>
          <%= for subsection <- @section.subsections do %>
            <div style="margin-top: 16px;">
              <div style="font-size: 10px; font-weight: 700; color: #9a7a5a; font-family: Georgia, serif; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 10px; padding-bottom: 6px; border-bottom: 1px solid rgba(60,40,20,0.1);">
                {subsection.title}
              </div>
              <%= if subsection.note do %>
                <p style="font-size: 12px; color: #7a5c3a; font-style: italic; margin-bottom: 10px; font-family: Georgia, serif;">
                  {subsection.note}
                </p>
              <% end %>
              <%= for step <- subsection.steps do %>
                <.step_item step={step} />
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :step, :map, required: true

  def step_item(assigns) do
    ~H"""
    <.link
      navigate={~p"/steps/#{@step.code}"}
      style="display: flex; gap: 14px; padding: 12px 0; border-bottom: 1px solid rgba(60,40,20,0.12); text-decoration: none; color: inherit;"
    >
      <%= if @step.image_path do %>
        <img
          src={"/#{@step.image_path}"}
          alt={@step.code}
          loading="lazy"
          style="width: 72px; height: 72px; object-fit: cover; border-radius: 4px; flex-shrink: 0; border: 1px solid rgba(60,40,20,0.15); filter: sepia(20%);"
        />
      <% end %>
      <div style="flex: 1;">
        <div style="display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap;">
          <code style="font-family: 'Courier New', monospace; font-size: 12px; font-weight: 700; color: #5c3a1a; background: rgba(180,120,40,0.1); padding: 2px 7px; border-radius: 3px; letter-spacing: 0.5px; border: 1px solid rgba(180,120,40,0.2);">
            {@step.code}
          </code>
          <span style="font-size: 14px; color: #2c1a0e; font-family: Georgia, serif; line-height: 1.5;">
            {@step.name}
          </span>
        </div>
        <%= if @step.note do %>
          <p style="font-size: 12px; color: #7a5c3a; margin: 5px 0 0; font-family: Georgia, serif; font-style: italic; line-height: 1.6;">
            {String.slice(@step.note, 0, 120)}{if String.length(@step.note) > 120, do: "…"}
          </p>
        <% end %>
      </div>
    </.link>
    """
  end

  # ---------------------------------------------------------------------------
  # Public helpers (used in template)
  # ---------------------------------------------------------------------------

  def filtered_sections(sections, "all"), do: sections

  def filtered_sections(sections, category) do
    Enum.filter(sections, fn s ->
      s.category != nil and s.category.name == category
    end)
  end

  def total_steps(sections) do
    Enum.reduce(sections, 0, fn s, acc ->
      sub_total = Enum.reduce(s.subsections, 0, fn sub, n -> n + length(sub.steps) end)
      acc + length(s.steps) + sub_total
    end)
  end

  def category_color(%{category: %{color: color}}), do: color
  def category_color(_), do: "#7f8c8d"

  def category_label(%{category: %{label: label}}), do: label
  def category_label(_), do: ""
end
```

- [ ] **Step 8.2: Read and write `lib/forrozin_web/live/collection_live.html.heex`**

Read `lib/forrozin_web/live/acervo_live.html.heex` in full. Write the new file applying these renames throughout:
- `@secoes` → `@sections`
- `@secoes_abertas` → `@open_sections`
- `@categorias` → `@categories`
- `@busca` → `@search`
- `@resultados_busca` → `@search_results`
- `@categoria_filtro` → `@category_filter`
- `@email_confirmado` → `@email_confirmed`
- `phx-click="buscar"` → `phx-click="search"` (and corresponding `phx-change`)
- `phx-click="filtrar"` → `phx-click="filter"`
- `phx-click="expandir_tudo"` → `phx-click="expand_all"`
- `phx-click="recolher_tudo"` → `phx-click="collapse_all"`
- Component call: `<.secao_card secao={s} aberta={...}>` → `<.section_card section={s} open={...}>`
- Route: `~p"/acervo"` → `~p"/collection"` (if any links reference it)
- Helper calls: `secoes_filtradas(...)` → `filtered_sections(...)`, `total_passos(...)` → `total_steps(...)`

- [ ] **Step 8.3: Create `lib/forrozin_web/live/step_live.ex`**

```elixir
defmodule ForrozinWeb.StepLive do
  @moduledoc "Detail page for a single encyclopedia step."

  use ForrozinWeb, :live_view

  alias Forrozin.Accounts
  alias Forrozin.Encyclopedia

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)

    case Encyclopedia.get_step_with_details(code, admin: admin) do
      {:ok, step} ->
        {:ok, assign(socket, step: step, page_title: step.name)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Passo não encontrado.")
         |> redirect(to: ~p"/collection")}
    end
  end

  def category_color(%{category: %{color: color}}), do: color
  def category_color(_), do: "#7f8c8d"

  def category_label(%{category: %{label: label}}), do: label
  def category_label(_), do: "—"
end
```

- [ ] **Step 8.4: Read and write `lib/forrozin_web/live/step_live.html.heex`**

Read `lib/forrozin_web/live/passo_live.html.heex` in full. Write the new file applying:
- `@passo` → `@step`
- `@passo.codigo` → `@step.code`
- `@passo.nome` → `@step.name`
- `@passo.nota` → `@step.note`
- `@passo.caminho_imagem` → `@step.image_path`
- `@passo.categoria` → `@step.category`
- `@passo.conceitos_tecnicos` → `@step.technical_concepts`
- `@passo.conexoes_como_origem` → `@step.connections_as_source`
- `@passo.conexoes_como_destino` → `@step.connections_as_target`
- In connection maps: `.passo_destino.codigo` → `.target_step.code`, `.passo_destino.nome` → `.target_step.name`
- In connection maps: `.passo_origem.codigo` → `.source_step.code`, `.passo_origem.nome` → `.source_step.name`
- `.rotulo` → `.label` on connections
- Route: `~p"/passos/#{...}"` → `~p"/steps/#{...}"`
- Helper: `categoria_cor(...)` → `category_color(...)`, `rotulo_categoria(...)` → `category_label(...)`

- [ ] **Step 8.5: Create `lib/forrozin_web/live/graph_live.ex`**

Read `lib/forrozin_web/live/grafo_live.ex` in full. Write the new file applying:
- `defmodule ForrozinWeb.GraphLive`
- `alias Forrozin.{Accounts, Admin, Admin.Backup, Encyclopedia}`
- `on_mount {ForrozinWeb.UserAuth, :ensure_admin}`
- In `mount`: call `Encyclopedia.build_graph()`, assign `:nodes`, `:edges`, `:edges_by_source`, `:edit_mode`, `:sources`, `:targets`, `:last_backup`, `:connection_label`
- Event names: `"toggle_modo_edicao"` → `"toggle_edit_mode"`, `"selecionar_origem"` → `"select_source"`, `"selecionar_destino"` → `"select_target"`, `"atualizar_rotulo"` → `"update_label"`, `"criar_conexoes"` → `"create_connections"`, `"editar_rotulo_conexao"` → `"edit_connection_label"`, `"criar_backup"` → `"create_backup"`, `"remover_conexao"` → `"delete_connection"`
- In event params: `"passo_id"` → `"step_id"`, `"conexao_id"` → `"connection_id"`, `"rotulo"` → `"label"`
- Admin calls: `Admin.criar_conexao` → `Admin.create_connection`, `Admin.editar_conexao` → `Admin.update_connection`, `Admin.remover_conexao` → `Admin.delete_connection`
- `Backup.criar_backup!()` → `Backup.create_backup!()`
- Private `carregar_grafo` → `load_graph`, using `graph.nodes` and `graph.edges` from `Encyclopedia.build_graph()`
- In `load_graph` JSON building: `edge.source_step.code`, `edge.target_step.code`
- Private `toggle_selecao` → `toggle_selection`
- Private `nilify` → `nilify` (already English, keep as-is)
- Return `{:noreply, socket}` with assigns `edges_by_source` (was `arestas_por_origem`) using `Enum.group_by(edges, & &1.source_step_id)`

Full `load_graph` private function:
```elixir
defp load_graph(socket, %{nodes: nodes, edges: edges}) do
  graph_json =
    Jason.encode!(%{
      nodes: Enum.map(nodes, fn p -> %{id: p.code, nome: p.name} end),
      edges:
        Enum.map(edges, fn c ->
          %{from: c.source_step.code, to: c.target_step.code, tipo: c.type}
        end)
    })

  socket
  |> assign(:nodes, nodes)
  |> assign(:edges, edges)
  |> assign(:edges_by_source, Enum.group_by(edges, & &1.source_step_id))
  |> assign(:graph_json, graph_json)
end
```

- [ ] **Step 8.6: Read and write `lib/forrozin_web/live/graph_live.html.heex`**

Read `lib/forrozin_web/live/grafo_live.html.heex` in full. Write the new file applying:
- `@nos` → `@nodes`, `@arestas` → `@edges`, `@arestas_por_origem` → `@edges_by_source`
- `@modo_edicao` → `@edit_mode`
- `@origens` → `@sources`, `@destinos` → `@targets`
- `@ultimo_backup` → `@last_backup`
- `@rotulo_conexao` → `@connection_label`
- `phx-value-passo_id` → `phx-value-step_id`
- `phx-value-conexao_id` → `phx-value-connection_id`
- `phx-click="toggle_modo_edicao"` → `phx-click="toggle_edit_mode"`
- `phx-click="selecionar_origem"` → `phx-click="select_source"`
- `phx-click="selecionar_destino"` → `phx-click="select_target"`
- `phx-click="criar_conexoes"` → `phx-click="create_connections"`
- `phx-click="criar_backup"` → `phx-click="create_backup"`
- `phx-click="remover_conexao"` → `phx-click="delete_connection"`
- Form submit: `phx-submit="editar_rotulo_conexao"` → `phx-submit="edit_connection_label"`
- Form input name: `name="rotulo"` → `name="label"`
- `no.categoria.rotulo` → `node.category.label` (with nil guard: `if node.category, do: node.category.label, else: "—"`)
- `no.categoria.cor` is accessed via category_color-style logic
- `aresta.passo_destino.codigo` → `edge.target_step.code`
- `aresta.passo_origem.codigo` → `edge.source_step.code`
- `aresta.rotulo` → `edge.label`
- Routes: `~p"/grafo/visual"` → `~p"/graph/visual"`, `~p"/acervo"` → `~p"/collection"`, `~p"/passos/#{no.codigo}"` → `~p"/steps/#{node.code}"`
- Counts: `length(@nodes)` and `Enum.reduce(@edges_by_source, 0, fn {_, v}, acc -> acc + length(v) end)`

- [ ] **Step 8.7: Create `lib/forrozin_web/live/graph_visual_live.ex`**

```elixir
defmodule ForrozinWeb.GraphVisualLive do
  use ForrozinWeb, :live_view

  alias Forrozin.{Accounts, Encyclopedia}

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    graph = Encyclopedia.build_graph()
    graph_json = build_json(graph)

    connected_count =
      graph.edges
      |> Enum.flat_map(&[&1.source_step_id, &1.target_step_id])
      |> MapSet.new()
      |> MapSet.size()

    {:ok,
     socket
     |> assign(:page_title, "Mapa de Passos")
     |> assign(:graph_json, graph_json)
     |> assign(:node_count, connected_count)
     |> assign(:edge_count, length(graph.edges))
     |> assign(:is_admin, Accounts.admin?(socket.assigns.current_user))}
  end

  defp build_json(%{nodes: nodes, edges: edges}) do
    connected_codes =
      edges
      |> Enum.flat_map(fn c -> [c.source_step.code, c.target_step.code] end)
      |> MapSet.new()

    connected_nodes = Enum.filter(nodes, &MapSet.member?(connected_codes, &1.code))

    Jason.encode!(%{
      nodes:
        Enum.map(connected_nodes, fn p ->
          %{
            id: p.code,
            nome: p.name,
            categoria: p.category.label,
            cor: p.category.color
          }
        end),
      edges:
        Enum.map(edges, fn c ->
          %{from: c.source_step.code, to: c.target_step.code, label: c.label}
        end)
    })
  end
end
```

- [ ] **Step 8.8: Read and write `lib/forrozin_web/live/graph_visual_live.html.heex`**

Read `lib/forrozin_web/live/grafo_visual_live.html.heex` in full. Apply:
- `@n_nos` → `@node_count`, `@n_arestas` → `@edge_count`
- `{@n_nos} passos · {@n_arestas} conexões` → `{@node_count} passos · {@edge_count} conexões`
- Route: `~p"/grafo"` → `~p"/graph"`, `~p"/acervo"` → `~p"/collection"`
- `phx-hook="GrafoVisual"` → `phx-hook="GraphVisual"`

- [ ] **Step 8.9: Update JS hook name in `assets/js/app.js`**

```js
// Change:
const GrafoVisual = {
// To:
const GraphVisual = {
```

And at the bottom:
```js
// Change:
hooks: {...colocatedHooks, GrafoVisual},
// To:
hooks: {...colocatedHooks, GraphVisual},
```

- [ ] **Step 8.10: Delete old LiveView files**

```bash
rm lib/forrozin_web/live/acervo_live.ex \
   lib/forrozin_web/live/acervo_live.html.heex \
   lib/forrozin_web/live/passo_live.ex \
   lib/forrozin_web/live/passo_live.html.heex \
   lib/forrozin_web/live/grafo_live.ex \
   lib/forrozin_web/live/grafo_live.html.heex \
   lib/forrozin_web/live/grafo_visual_live.ex \
   lib/forrozin_web/live/grafo_visual_live.html.heex
```

- [ ] **Step 8.11: Check for syntax errors**

```bash
mix compile 2>&1 | grep "error" | head -20
```

---

## Task 9: Router + UserAuth + Controllers

**Files:**
- Modify: `lib/forrozin_web/router.ex`
- Modify: `lib/forrozin_web/user_auth.ex`
- Modify: `lib/forrozin_web/controllers/user_session_controller.ex`
- Modify: `lib/forrozin_web/controllers/user_confirmation_controller.ex`
- Modify: `lib/forrozin_web/controllers/user_session_html/new.html.heex`
- Modify: `lib/forrozin_web/controllers/user_confirmation_html/result.html.heex`
- Modify: `lib/forrozin_web/components/layouts/root.html.heex`

- [ ] **Step 9.1: Update `lib/forrozin_web/router.ex`**

```elixir
defmodule ForrozinWeb.Router do
  use ForrozinWeb, :router

  @compile {:no_warn_undefined, Plug.Swoosh.MailboxPreview}

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ForrozinWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug ForrozinWeb.UserAuth, :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :redirect_if_authenticated do
    plug ForrozinWeb.UserAuth, :redirect_if_authenticated
  end

  scope "/", ForrozinWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create
    live "/signup", UserRegistrationLive
  end

  scope "/", ForrozinWeb do
    pipe_through :browser

    live "/", LandingLive
    delete "/logout", UserSessionController, :delete
    get "/confirm/:token", UserConfirmationController, :confirm
  end

  scope "/", ForrozinWeb do
    pipe_through :browser

    live "/collection", CollectionLive
    live "/graph", GraphLive
    live "/graph/visual", GraphVisualLive
    live "/steps/:code", StepLive
  end

  if Application.compile_env(:forrozin, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ForrozinWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
```

- [ ] **Step 9.2: Update `lib/forrozin_web/user_auth.ex`**

The module is already in English. Apply these changes:
- `Accounts.buscar_usuario_por_id(id)` → `Accounts.get_user_by_id(id)` (both occurrences in `mount_current_user`)
- Redirect targets: `~p"/entrar"` → `~p"/login"`, `~p"/acervo"` → `~p"/collection"`, `~p"/grafo/visual"` → `~p"/graph/visual"`

- [ ] **Step 9.3: Read and update `lib/forrozin_web/controllers/user_session_controller.ex`**

Read the file first. Apply:
- `Accounts.autenticar_usuario(nome_usuario, senha)` → `Accounts.authenticate_user(username, password)`
- `:credenciais_invalidas` → `:invalid_credentials`
- Route redirects: `~p"/entrar"` → `~p"/login"`, `~p"/acervo"` → `~p"/collection"`
- Flash message strings may stay in Portuguese (user-facing)

- [ ] **Step 9.4: Read and update `lib/forrozin_web/controllers/user_confirmation_controller.ex`**

Read the file first. Apply:
- `Accounts.confirmar_email(token)` → `Accounts.confirm_email(token)`
- `:token_invalido` → `:invalid_token`
- Route redirects: `~p"/confirmar/..."` → `~p"/confirm/..."`

- [ ] **Step 9.5: Read and update `lib/forrozin_web/controllers/user_session_html/new.html.heex`**

Read the file first. Apply:
- Form action: `~p"/entrar"` → `~p"/login"`
- Link to register: `~p"/cadastro"` → `~p"/signup"`
- Input field names: `"nome_usuario"` → `"username"`, `"senha"` → `"password"`

- [ ] **Step 9.6: Read and update `lib/forrozin_web/controllers/user_confirmation_html/result.html.heex`**

Read the file first. Apply route changes: `~p"/entrar"` → `~p"/login"` if present.

- [ ] **Step 9.7: Read and update `lib/forrozin_web/components/layouts/root.html.heex`**

Read the file first. Apply any route references: `~p"/acervo"` → `~p"/collection"`, `~p"/entrar"` → `~p"/login"`, `~p"/sair"` → `~p"/logout"`.

- [ ] **Step 9.8: Read and update `lib/forrozin_web/live/user_registration_live.html.heex`**

Read the file. Apply:
- Form fields: `"nome_usuario"` → `"username"`, `"senha"` → `"password"`
- Links: `~p"/entrar"` → `~p"/login"`

- [ ] **Step 9.9: Read and update `lib/forrozin_web/live/user_registration_live.ex`**

Read the file. Apply:
- `alias Forrozin.Accounts`
- `Accounts.registrar_usuario(attrs)` → `Accounts.register_user(attrs)`
- Route: `~p"/acervo"` → `~p"/collection"`

- [ ] **Step 9.10: Check compilation — should be clean now**

```bash
mix compile 2>&1 | grep "error"
```

Expected: no errors. If there are errors, fix them before proceeding.

---

## Task 10: Mix Tasks

**Files:**
- Create: `lib/mix/tasks/forrozin.extract_connections.ex`
- Create: `lib/mix/tasks/forrozin.restore_backup.ex`
- Delete: `lib/mix/tasks/forrozin.extrair_conexoes.ex`
- Delete: `lib/mix/tasks/forrozin.restaurar_backup.ex`

- [ ] **Step 10.1: Read `lib/mix/tasks/forrozin.extrair_conexoes.ex` in full**

- [ ] **Step 10.2: Create `lib/mix/tasks/forrozin.extract_connections.ex`**

Rename the module: `Mix.Tasks.Forrozin.ExtrairConexoes` → `Mix.Tasks.Forrozin.ExtractConnections`
The task name in `@shortdoc` and `@moduledoc` can be updated to English.

Apply inside the file:
- `@conexoes` → `@connections`
- Variable names: `codigo_origem` → `source_code`, `codigo_destino` → `target_code`
- `Forrozin.Enciclopedia.listar_todos_passos_mapa()` → `Forrozin.Encyclopedia.list_all_steps_map()`
- `Forrozin.Admin.criar_conexao(...)` → `Forrozin.Admin.create_connection(...)`
- Connection attrs: `passo_origem_id:` → `source_step_id:`, `passo_destino_id:` → `target_step_id:`, `tipo:` → `type:`, `rotulo:` → `label:`
- Enum values in the `@connections` list: `"saida"` → `"exit"`, `"entrada"` → `"entry"` (in the tipo/type field of any connection tuples)

- [ ] **Step 10.3: Read `lib/mix/tasks/forrozin.restaurar_backup.ex` in full**

- [ ] **Step 10.4: Create `lib/mix/tasks/forrozin.restore_backup.ex`**

Rename module: `Mix.Tasks.Forrozin.RestaurarBackup` → `Mix.Tasks.Forrozin.RestoreBackup`
Apply:
- `Forrozin.Admin.Backup.restaurar_backup!(path)` → `Forrozin.Admin.Backup.restore_backup!(path)`
- `Forrozin.Admin.Backup.listar_backups()` → `Forrozin.Admin.Backup.list_backups()`
- Internal variable: `caminho` → `path`, `limpar` flag → `clear`
- Private function: `limpar_tabelas!` → `clear_tables!`

- [ ] **Step 10.5: Delete old mix task files**

```bash
rm lib/mix/tasks/forrozin.extrair_conexoes.ex \
   lib/mix/tasks/forrozin.restaurar_backup.ex
```

- [ ] **Step 10.6: Check compilation**

```bash
mix compile 2>&1 | grep "error"
```

---

## Task 11: Test Support + Test Files

**Files:**
- Modify: `test/support/factory.ex`
- Modify: all test files

- [ ] **Step 11.1: Update `test/support/factory.ex`**

```elixir
defmodule Forrozin.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: Forrozin.Repo

  alias Forrozin.Accounts.User
  alias Forrozin.Encyclopedia.{Category, TechnicalConcept, Connection, Step, Section, Subsection}

  def user_factory do
    %User{
      username: sequence(:username, &"usuario#{&1}"),
      email: sequence(:email, &"usuario#{&1}@example.com"),
      password_hash: Argon2.hash_pwd_salt("senhateste123"),
      role: "user",
      confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end

  def admin_factory do
    %User{
      username: sequence(:username, &"admin#{&1}"),
      email: sequence(:email, &"admin#{&1}@example.com"),
      password_hash: Argon2.hash_pwd_salt("senhateste123"),
      role: "admin",
      confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end

  def category_factory do
    %Category{
      name: sequence(:category_name, &"category_#{&1}"),
      label: sequence(:category_label, &"Category #{&1}"),
      color: "#c0392b"
    }
  end

  def section_factory do
    %Section{
      title: sequence(:section_title, &"Section #{&1}"),
      position: sequence(:section_position, & &1),
      category: build(:category)
    }
  end

  def subsection_factory do
    %Subsection{
      title: sequence(:subsection_title, &"Subsection #{&1}"),
      position: sequence(:subsection_position, & &1),
      section: build(:section)
    }
  end

  def step_factory do
    %Step{
      code: sequence(:step_code, &"P#{&1}"),
      name: sequence(:step_name, &"Step #{&1}"),
      position: sequence(:step_position, & &1),
      section: build(:section),
      category: build(:category)
    }
  end

  def connection_factory do
    %Connection{
      type: "exit",
      source_step: build(:step),
      target_step: build(:step)
    }
  end

  def technical_concept_factory do
    %TechnicalConcept{
      title: sequence(:concept_title, &"Concept #{&1}"),
      description: "Technical description of the concept."
    }
  end
end
```

- [ ] **Step 11.2: Update `test/forrozin/enciclopedia/passo_test.exs` → rename to `test/forrozin/encyclopedia/step_test.exs`**

```bash
mkdir -p test/forrozin/encyclopedia
mv test/forrozin/enciclopedia/passo_test.exs test/forrozin/encyclopedia/step_test.exs
```

Then edit `step_test.exs`:
- `defmodule Forrozin.Enciclopedia.PassoTest` → `defmodule Forrozin.Encyclopedia.StepTest`
- `alias Forrozin.Enciclopedia.Passo` → `alias Forrozin.Encyclopedia.Step`
- `%Passo{}` → `%Step{}`
- Field names: `codigo:` → `code:`, `nome:` → `name:`, `nota:` → `note:`, `posicao:` → `position:`, `categoria_id:` → `category_id:`, `secao_id:` → `section_id:`
- `insert(:passo, ...)` → `insert(:step, ...)`
- Changeset field names in assertions: `.codigo` → `.code`, `.nome` → `.name`

- [ ] **Step 11.3: Rename and update remaining enciclopedia test files**

```bash
mv test/forrozin/enciclopedia/categoria_test.exs    test/forrozin/encyclopedia/category_test.exs
mv test/forrozin/enciclopedia/secao_test.exs        test/forrozin/encyclopedia/section_test.exs
mv test/forrozin/enciclopedia/subsecao_test.exs     test/forrozin/encyclopedia/subsection_test.exs
mv test/forrozin/enciclopedia/conexao_test.exs      test/forrozin/encyclopedia/connection_test.exs
mv test/forrozin/enciclopedia/semeador_test.exs     test/forrozin/encyclopedia/seeder_test.exs
mv test/forrozin/enciclopedia_test.exs              test/forrozin/encyclopedia_test.exs
rmdir test/forrozin/enciclopedia/
```

For each file, apply the same pattern:
- Module name: `Enciclopedia.*Test` → `Encyclopedia.*Test`
- Alias: `Forrozin.Enciclopedia.*` → `Forrozin.Encyclopedia.*`
- Factory calls: `insert(:categoria, ...)` → `insert(:category, ...)`, `insert(:secao, ...)` → `insert(:section, ...)`, `insert(:subsecao, ...)` → `insert(:subsection, ...)`, `insert(:passo, ...)` → `insert(:step, ...)`, `insert(:conexao, ...)` → `insert(:connection, ...)`, `insert(:conceito_tecnico, ...)` → `insert(:technical_concept, ...)`
- Field names in attrs: `nome:` → `name:`, `rotulo:` → `label:`, `cor:` → `color:`, `titulo:` → `title:`, `descricao:` → `description:`, `codigo:` → `code:`, `posicao:` → `position:`, `tipo:` → `type:`, `rotulo:` → `label:`, `passo_origem:` → `source_step:`, `passo_destino:` → `target_step:`
- Context function calls in `encyclopedia_test.exs`: `Enciclopedia.listar_categorias()` → `Encyclopedia.list_categories()`, etc. — apply full rename map from the spec
- Assertions on returned structs: `.nome` → `.name`, `.rotulo` → `.label`, `.titulo` → `.title`, etc.
- Error atoms: `:nao_encontrado` → `:not_found`
- Enum values: `"saida"` → `"exit"`, `"publicado"` → `"published"`, `"rascunho"` → `"draft"`
- `listar_grafo` → `build_graph`, result keys: `grafo.nos` → `graph.nodes`, `grafo.arestas` → `graph.edges`
- `listar_secoes_com_passos` → `list_sections_with_steps`; result: `resultado.passos` → `result.steps`

- [ ] **Step 11.4: Update `test/forrozin/accounts_test.exs` and `test/forrozin/accounts/user_test.exs`**

- `Accounts.registrar_usuario` → `Accounts.register_user`
- `Accounts.autenticar_usuario` → `Accounts.authenticate_user`
- `Accounts.buscar_usuario_por_id` → `Accounts.get_user_by_id`
- `Accounts.confirmar_email` → `Accounts.confirm_email`
- `Accounts.email_confirmado?` → `Accounts.email_confirmed?`
- Error atoms: `:credenciais_invalidas` → `:invalid_credentials`, `:token_invalido` → `:invalid_token`
- Field names in `insert(:user, ...)`: `nome_usuario:` → `username:`, `senha_hash:` → `password_hash:`, `papel:` → `role:`
- In `user_test.exs`: `User.changeset_registro` → `User.registration_changeset`, `User.changeset_confirmacao` → `User.confirmation_changeset`
- Field assertions: `.nome_usuario` → `.username`, `.senha_hash` → `.password_hash`, `.papel` → `.role`

- [ ] **Step 11.5: Rename and update admin test files**

```bash
mv test/forrozin/admin/ test/forrozin/admin/   # stays — Admin module name doesn't change
```

Update `test/forrozin/admin_test.exs`:
- `Admin.criar_conexao` → `Admin.create_connection`
- `Admin.editar_conexao` → `Admin.update_connection`
- `Admin.remover_conexao` → `Admin.delete_connection`
- Factory: `insert(:conexao, ...)` → `insert(:connection, ...)`
- Field: `tipo:` → `type:`, `passo_origem:` → `source_step:`, `passo_destino:` → `target_step:`, `rotulo:` → `label:`
- Assertions: `.rotulo` → `.label`, `.tipo` → `.type`, `.passo_origem_id` → `.source_step_id`, `.passo_destino_id` → `.target_step_id`

Update `test/forrozin/admin/backup_test.exs`:
- `Backup.criar_backup!` → `Backup.create_backup!`
- `Backup.restaurar_backup!` → `Backup.restore_backup!`
- `Backup.listar_backups` → `Backup.list_backups`

- [ ] **Step 11.6: Rename and update worker test files**

```bash
mv test/forrozin/workers/enviar_email_confirmacao_test.exs \
   test/forrozin/workers/send_confirmation_email_test.exs
mv test/forrozin/workers/backup_periodico_test.exs \
   test/forrozin/workers/periodic_backup_test.exs
```

Update each file:
- Module name: `EnviarEmailConfirmacaoTest` → `SendConfirmationEmailTest`, `BackupPeriodicoTest` → `PeriodicBackupTest`
- Worker module alias: `Workers.EnviarEmailConfirmacao` → `Workers.SendConfirmationEmail`, `Workers.BackupPeriodico` → `Workers.PeriodicBackup`

- [ ] **Step 11.7: Update LiveView test files**

```bash
mv test/forrozin_web/live/acervo_live_test.exs       test/forrozin_web/live/collection_live_test.exs
mv test/forrozin_web/live/passo_live_test.exs        test/forrozin_web/live/step_live_test.exs
mv test/forrozin_web/live/grafo_live_test.exs        test/forrozin_web/live/graph_live_test.exs
mv test/forrozin_web/live/grafo_visual_live_test.exs test/forrozin_web/live/graph_visual_live_test.exs
```

For each, apply:
- Module name: `AcervoLiveTest` → `CollectionLiveTest`, `PassoLiveTest` → `StepLiveTest`, `GrafoLiveTest` → `GraphLiveTest`, `GrafoVisualLiveTest` → `GraphVisualLiveTest`
- Route paths: `~p"/acervo"` → `~p"/collection"`, `~p"/passos/#{...}"` → `~p"/steps/#{...}"`, `~p"/grafo"` → `~p"/graph"`, `~p"/grafo/visual"` → `~p"/graph/visual"`
- `live(conn, ~p"/acervo")` → `live(conn, ~p"/collection")`
- Factory calls: `insert(:passo, ...)` → `insert(:step, ...)`, `insert(:conexao, ...)` → `insert(:connection, ...)`
- Field assertions: `codigo:` → `code:`, `nome:` → `name:`
- HTML content assertions: `assert html =~ "BF"` — these test step codes which stay Portuguese ✓
- In `graph_live_test.exs`: event names `"toggle_modo_edicao"` → `"toggle_edit_mode"`, `"selecionar_origem"` → `"select_source"`, `"selecionar_destino"` → `"select_target"`, `"criar_conexoes"` → `"create_connections"`, `"remover_conexao"` → `"delete_connection"`
- Event params: `"passo_id"` → `"step_id"`, `"conexao_id"` → `"connection_id"`
- Redirect assertions: `"/grafo/visual"` → `"/graph/visual"`
- In `step_live_test.exs`: mount param `"codigo"` → `"code"`, redirect `"/acervo"` → `"/collection"`
- In `collection_live_test.exs`: event names: `"buscar"` → `"search"`, `"filtrar"` → `"filter"`, `"toggle_secao"` → `"toggle_section"`, `"expandir_tudo"` → `"expand_all"`, `"recolher_tudo"` → `"collapse_all"`; param key `"secao_id"` → `"section_id"`

- [ ] **Step 11.8: Update `test/forrozin_web/controllers/` test files**

- `user_session_controller_test.exs`: routes `"/entrar"` → `"/login"`, params `"nome_usuario"` → `"username"`, `"senha"` → `"password"`, redirect check `"/acervo"` → `"/collection"`
- `user_confirmation_controller_test.exs`: routes `"/confirmar/..."` → `"/confirm/..."`, redirect `"/entrar"` → `"/login"`

- [ ] **Step 11.9: Update `test/forrozin/encyclopedia/seeder_test.exs`**

- `alias Forrozin.Encyclopedia.Seeder`
- `Seeder.seed!()` (was `Semeador.semear!()`)
- Schema aliases: `Category`, `Section`, `Subsection`, `Step`
- Field assertions: `.name`, `.label`, `.code`, `.title`, `.position`, etc.
- Status assertions: `"published"` (was `"publicado"`)
- Connection type: `"exit"` (was `"saida"`)

---

## Task 12: Final Compilation + Full Test Run

- [ ] **Step 12.1: Full compilation check**

```bash
mix compile --force 2>&1
```

Expected: zero errors, possible warnings about unused variables (fix them).

- [ ] **Step 12.2: Run the full test suite**

```bash
mix test 2>&1
```

Expected: all tests pass. If failures:
- Read the error message carefully
- Identify which rename was missed
- Fix the specific file
- Re-run `mix test`

- [ ] **Step 12.3: Verify the application starts**

```bash
mix run -e 'IO.puts("Application started successfully")'
```

Expected: `Application started successfully` with no crashes.

- [ ] **Step 12.4: Verify DB data is intact**

```bash
mix run -e '
  steps = Forrozin.Encyclopedia.list_sections_with_steps()
  total = Enum.reduce(steps, 0, fn s, acc ->
    sub = Enum.reduce(s.subsections, 0, fn sub, n -> n + length(sub.steps) end)
    acc + length(s.steps) + sub
  end)
  graph = Forrozin.Encyclopedia.build_graph()
  IO.puts("Sections: #{length(steps)}")
  IO.puts("Steps (visible): #{total}")
  IO.puts("Graph nodes: #{length(graph.nodes)}")
  IO.puts("Graph edges: #{length(graph.edges)}")
'
```

Expected: numbers consistent with pre-migration state (121 steps, 131 connections, 21 sections).

- [ ] **Step 12.5: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor: rename all internal identifiers from Portuguese to English

- All module, function, schema field, and file names now in English
- DB columns renamed via migration (ALTER TABLE RENAME COLUMN — no data loss)
- Enum values updated: publicado→published, rascunho→draft, saida→exit, entrada→entry
- Routes: /acervo→/collection, /grafo→/graph, /passos→/steps, /entrar→/login, /cadastro→/signup
- User-facing text (step names, notes, UI copy) unchanged — stays in Portuguese
- DB table names unchanged: passos, categorias, secoes, conexoes_passos, etc.
- EN backup available at priv/backups/backup_20260413_211128_en.json

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Xaves — Engineering Quality Gate

> **Xaves is mandatory. No implementation is considered complete until this phase finishes.**

Xaves is a senior engineer reviewer who validates the entire implementation before merge. Three sequential passes: RFC compliance → production code → test quality.

**Files reviewed:** Only files changed in this branch (the Big Bang rename). No speculation about untouched code.

**Tavano RFC** (embedded for reviewer context):

```
Use the following principles for all code:

## CRITICAL: Zero Tolerance for Ignoring Code Quality Issues

NEVER use @dialyzer {:nowarn_function} or Credo ignores to make lint pass.
This is STRICTLY FORBIDDEN. These directives mask real problems.

Instead:
1. Always understand the root cause of the warning/error completely
2. If the issue doesn't make sense, investigate deeper
3. Never leave problems half-solved or hidden
4. Fix the actual issue in the code (adjust specs, fix logic, refactor)

Follow the Elixir Style Guide (christopheradams):
- Use meaningful, descriptive names for functions and variables
- Prefer function pipelines over deeply nested code
- Use pattern matching to clarify logic and avoid conditionals
- Prefer immutability and pure functions
- Use modules to group related functionality logically
- Keep lines short, limit to one expression per line
- Avoid unnecessary aliases or abbreviations
- Follow consistent indentation and spacing

Elixir-specific quality standards:
- Use `with` for chaining 2+ operations that return {:ok, _} or {:error, _}
- Avoid `with` for single operations — use `case` or pattern matching instead
- Use pipes |> only when chaining 2+ functions; avoid single pipes
- Always pass full entities (structs) instead of IDs when possible
- Follow dependency injection: let callers provide data rather than fetching inside functions

Pipe Chain Rules:
Pipe chains must ALWAYS start with a raw value (variable, literal, or struct), never with a function call.

Bad:
  source.stream(company, funding_account, opts)
  |> Enum.reduce(%{external_transaction: []}, &accumulate_by_type/2)

Good:
  company
  |> source.stream(funding_account, opts)
  |> Enum.reduce(%{external_transaction: []}, &accumulate_by_type/2)
```

- [ ] **Step 13.1 — Pass 1: Tavano RFC Compliance Review**

Run `mix credo --strict 2>&1` and `mix dialyzer 2>&1 | tail -40`. Review output for RFC violations in changed files only.

Check for each changed file:
- No `@dialyzer {:nowarn_function}` or `# credo:disable-for-next-line` suppressions added during this refactor
- No single-element pipes (`value |> function()` with no further chain)
- No pipe chains starting with a function call
- No `with` used for single operations (use `case` instead)
- No ID passed where a full struct should be passed
- All function names are meaningful and descriptive in English

If violations found → treat as CRITICAL → fix inline before proceeding to Pass 2.

- [ ] **Step 13.2 — Pass 2: Production Code Review**

Get the diff of all changed files:

```bash
git diff main..HEAD --name-only
```

For each changed file, verify:
- **No silent data loss** — all Repo operations that can fail use `{:ok, _}` / `{:error, _}` patterns
- **No hardcoded Portuguese strings** in Elixir code (user-facing text in templates is fine; internal atom/string identifiers must be English)
- **No dead code** — no old Portuguese aliases left alongside new English ones
- **Module alias consistency** — every `alias` uses the new English module path
- **Schema field consistency** — every `field` declaration matches the renamed DB column
- **Changeset cast/validate** — all new field names are present in `cast/2` and any relevant `validate_*` calls
- **Graph build function** — `build_graph/0` returns `%{nodes: [...], edges: [...]}` (not `nos`/`arestas`)
- **Route helpers** — all `~p"..."` sigils use new English paths
- **LiveView events** — all `handle_event/3` clauses use English event names

Automatically IMPLEMENT fixes for any CRITICAL issues found.

Non-critical suggestions: list but do NOT implement.

- [ ] **Step 13.3 — Pass 3: Test Quality Review**

For each test file changed, verify:
- **No `async: true` on tests that hit the DB with shared state** — graph tests, seeder tests must be `async: false`
- **No shallow assertions** — `assert html =~ "text"` is acceptable; `assert response == %{}` without checking specific fields is not
- **Factory consistency** — all `insert(:step)`, `insert(:category)`, `insert(:connection)` etc. use English factory names
- **No Portuguese event names in `render_click`** — all events are English (`"toggle_edit_mode"`, not `"toggle_modo_edicao"`)
- **No stale route paths in tests** — all `~p"/..."` use new English routes
- **No missing redirect tests** — auth redirect tests verify the exact target path matches new routes
- **Coverage of critical paths:**
  - `Encyclopedia.build_graph/0` returns `%{nodes: list, edges: list}`
  - `Accounts.register_user/1`, `authenticate_user/2`, `confirm_email/1`
  - `Admin.create_connection/1`, `update_connection/2`, `delete_connection/1`
  - Factory `insert(:step)`, `insert(:connection)`, `insert(:category)` — all produce valid records
  - CollectionLive renders sections on `/collection`
  - StepLive renders step detail on `/steps/:code`
  - GraphLive redirects non-admins to `/graph/visual`

Fix MEDIUM and CRITICAL issues. List non-critical observations only.

- [ ] **Step 13.4 — Apply Critical Fixes**

After all three passes, collect all CRITICAL fixes identified above and apply them if not already applied inline. Run:

```bash
cd forrozin && mix test 2>&1 | tail -20
```

Expected: 0 failures. If failures remain → fix → re-run. Do not proceed until green.

- [ ] **Step 13.5 — Final Merge Readiness Report**

Produce a structured report:

```
## Xaves — Merge Readiness Report

### Pass 1: Tavano RFC Compliance
[List issues found and fixes applied, or "No violations"]

### Pass 2: Production Code
Critical issues found: N
Fixes applied: [list]
Non-critical suggestions: [list]

### Pass 3: Test Quality
Critical/Medium issues found: N
Fixes applied: [list]
Non-critical observations: [list]

### Confidence Level
[SAFE TO MERGE | SAFE WITH MINOR IMPROVEMENTS | NEEDS ADDITIONAL FIXES]

Reason: [one sentence]
```

Commit the Xaves fixes (if any):

```bash
git add -A
git commit -m "$(cat <<'EOF'
fix: Xaves quality gate — RFC compliance + test consistency

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```
