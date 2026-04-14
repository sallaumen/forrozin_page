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

    visibility_filter =
      if admin,
        do: dynamic([p], p.status == "published"),
        else: dynamic([p], p.wip == false and p.status == "published")

    # Direct steps: only those NOT in a subsection (avoids duplicates)
    direct_steps =
      from(p in Step,
        where: ^visibility_filter,
        where: is_nil(p.subsection_id),
        order_by: [asc: p.position]
      )

    # Subsection steps: all visible steps in subsections
    subsection_steps =
      from(p in Step,
        where: ^visibility_filter,
        order_by: [asc: p.position]
      )

    Section
    |> order_by([s], asc: s.position)
    |> Repo.all()
    |> Repo.preload([
      :category,
      steps: {direct_steps, [:suggested_by]},
      subsections: [steps: {subsection_steps, [:suggested_by]}]
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

  # ---------------------------------------------------------------------------
  # Suggested steps
  # ---------------------------------------------------------------------------

  @doc "Lists all suggested steps (community contributions)."
  def list_suggested_steps do
    Step
    |> where([s], not is_nil(s.suggested_by_id))
    |> where([s], s.status == "published")
    |> order_by([s], desc: s.inserted_at)
    |> preload([:category, :suggested_by])
    |> Repo.all()
  end

  @doc "Lists steps suggested by a specific user."
  def list_user_steps(user_id) do
    Step
    |> where([s], s.suggested_by_id == ^user_id)
    |> order_by([s], desc: s.inserted_at)
    |> preload([:category, :suggested_by])
    |> Repo.all()
  end
end
