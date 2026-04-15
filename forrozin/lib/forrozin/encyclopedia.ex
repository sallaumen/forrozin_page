defmodule Forrozin.Encyclopedia do
  @moduledoc """
  Read context for the dance step encyclopedia.

  Pure calculation module: all functions are DB queries with no side effects.
  Step visibility is controlled here — steps with `wip: true` or
  `status: "draft"` are not returned to the public.

  All Repo access is delegated to the Query modules (StepQuery, ConnectionQuery,
  SectionQuery). This context is the public API; Query modules are internal.
  """

  import Ecto.Query, only: [order_by: 2, from: 2, dynamic: 2, where: 3]

  alias Forrozin.Encyclopedia.{
    Category,
    ConnectionQuery,
    SectionQuery,
    StepQuery,
    TechnicalConcept
  }

  alias Forrozin.Repo

  @doc "Lists all categories ordered by label."
  def list_categories do
    Category
    |> Ecto.Query.order_by([c], asc: c.label)
    |> Repo.all()
  end

  @doc "Finds a category by its internal name (e.g. 'sacadas', 'bases')."
  def fetch_category_by_name(name) do
    case Repo.get_by(Category, name: name) do
      nil -> {:error, :not_found}
      category -> {:ok, category}
    end
  end

  @doc "Lists all sections ordered by position."
  def list_sections do
    SectionQuery.list_by()
  end

  @doc """
  Lists sections with steps and subsections preloaded.

  Options:
  - `admin: true` — includes `wip` steps (for administrators).

  By default omits `wip` and `draft` steps (public visibility).
  """
  def list_sections_with_steps(opts \\ []) do
    admin = Keyword.get(opts, :admin, false)

    # NOTE: The local `import Ecto.Query` here is intentional. The inline
    # query sub-expressions passed to `Repo.preload/2` use `from/2` and
    # `dynamic/2` macros that must reference schema modules directly (e.g.
    # `Forrozin.Encyclopedia.Step`). Extracting them into SectionQuery would
    # require passing the visibility filter as an argument, which couples the
    # query module to domain policy. Keeping them here — scoped to this
    # function — is the pragmatic trade-off.
    import Ecto.Query

    visibility_filter =
      if admin,
        do: dynamic([p], p.status == "published"),
        else: dynamic([p], p.wip == false and p.status == "published")

    # Direct steps: only those NOT in a subsection (avoids duplicates).
    # Official steps (no suggested_by_id) come first, community steps after.
    direct_steps =
      from(p in Forrozin.Encyclopedia.Step,
        where: ^visibility_filter,
        where: is_nil(p.subsection_id),
        order_by: [
          asc: fragment("CASE WHEN ? IS NULL THEN 0 ELSE 1 END", p.suggested_by_id),
          asc: p.position
        ]
      )

    # Subsection steps: all visible steps in subsections, same ordering.
    subsection_steps =
      from(p in Forrozin.Encyclopedia.Step,
        where: ^visibility_filter,
        order_by: [
          asc: fragment("CASE WHEN ? IS NULL THEN 0 ELSE 1 END", p.suggested_by_id),
          asc: p.position
        ]
      )

    SectionQuery.list_by()
    |> Repo.preload([
      :category,
      steps: {direct_steps, [:suggested_by]},
      subsections: [steps: {subsection_steps, [:suggested_by]}]
    ])
  end

  @doc "Counts total published, non-wip steps (public count)."
  def count_public_steps do
    StepQuery.count_by(public_only: true)
  end

  @doc """
  Finds a step by its unique code (e.g. "BF", "GP-D").

  Respects visibility policy: wip or draft steps return
  `{:error, :not_found}` for the public.
  """
  def fetch_step_by_code(code) do
    case StepQuery.get_by(code: code, public_only: true) do
      nil -> {:error, :not_found}
      step -> {:ok, step}
    end
  end

  @doc """
  Finds a step with full details: category, technical concepts and connections.

  Options:
  - `admin: true` — includes `wip` steps.
  """
  def fetch_step_with_details(code, opts \\ []) do
    admin = Keyword.get(opts, :admin, false)

    query_opts =
      if admin,
        do: [code: code, status: "published"],
        else: [code: code, public_only: true]

    case StepQuery.get_by(query_opts) do
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
  Searches steps by name or code (case-insensitive, partial match).

  Options:
  - `admin: true` — includes `wip` steps.

  By default returns only public steps.
  """
  def search_steps(term, opts \\ []) do
    admin = Keyword.get(opts, :admin, false)

    base_opts = [search: term, order_by: [asc: :name]]

    extra_opts =
      if admin,
        do: [status: "published"],
        else: [status: "published", wip: false]

    StepQuery.list_by(base_opts ++ extra_opts)
  end

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

    node_opts =
      if admin,
        do: [status: "published", order_by: [asc: :name], preload: [:category]],
        else: [public_only: true, order_by: [asc: :name], preload: [:category]]

    nodes = StepQuery.list_by(node_opts)
    step_ids = Enum.map(nodes, & &1.id)

    edges =
      ConnectionQuery.list_by(
        step_ids: step_ids,
        preload: [:source_step, :target_step]
      )

    %{nodes: nodes, edges: edges}
  end

  @doc """
  Returns all steps (including wip) indexed by code.

  Internal use: Mix tasks for seeding and connection extraction.
  Returns `%{code => step}`.
  """
  def list_all_steps_map do
    StepQuery.list_by()
    |> Map.new(&{&1.code, &1})
  end

  @doc "Lists all technical concepts ordered by title."
  def list_technical_concepts do
    TechnicalConcept
    |> Ecto.Query.order_by([c], asc: c.title)
    |> Repo.all()
  end

  @doc "Lists all suggested steps (community contributions)."
  def list_suggested_steps do
    StepQuery.list_by(
      has_suggestions: true,
      status: "published",
      order_by: [desc: :inserted_at],
      preload: [:category, :suggested_by]
    )
  end

  @doc """
  Lists suggested steps filtered by approval status.

  Options:
  - `filter: "pending"` — only unapproved suggestions.
  - `filter: "approved"` — only approved suggestions.
  - `filter: "all"` (default) — all suggestions.
  """
  def list_suggested_steps_filtered(opts \\ []) do
    filter = Keyword.get(opts, :filter, "all")

    base = [
      has_suggestions: true,
      status: "published",
      order_by: [desc: :inserted_at],
      preload: [:category, :suggested_by]
    ]

    extra =
      case filter do
        "pending" -> [pending_only: true]
        "approved" -> [approved_only: true]
        _ -> []
      end

    StepQuery.list_by(base ++ extra)
  end

  @doc "Lists steps suggested by a specific user."
  def list_user_steps(user_id) do
    StepQuery.list_by(
      suggested_by_id: user_id,
      order_by: [desc: :inserted_at],
      preload: [:category, :suggested_by]
    )
  end
end
