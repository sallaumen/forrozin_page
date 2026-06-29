defmodule OGrupoDeEstudosWeb.GraphVisual.GraphData do
  @moduledoc """
  Pure graph-data computations for the visual graph (`GraphVisualLive`):

    * Cytoscape JSON building (`build_json/2`, `build_orphans_json/1`)
    * edge-spread geometry for parallel/bidirectional edges (`compute_edge_spread/1`)
    * node search for the graph search box (`search_graph_nodes/2`)
    * missing-edge detection for manual sequences (`find_missing_edges/2`)

  All functions are pure (no Repo/socket/IO). Two distinct input contracts:

    * `build_json/2`, `build_orphans_json/1`, `compute_edge_spread/1`,
      `find_missing_edges/2` consume RAW `Encyclopedia.build_graph` structs:
      nodes expose `code/name/note/highlighted/suggested_by_id/like_count/category`
      (category is a `%Category{}` with `name/label/color`); edges expose
      `source_step.code`, `target_step.code`, `label`.
    * `search_graph_nodes/2` consumes assign-shaped maps where `category` is a
      STRING label (`%{code, name, category}`).

  Behaviour preserved verbatim on extraction from `GraphVisualLive`:
  `truncate_note/2` uses a byte-size guard with a grapheme slice (so a multibyte
  note can exceed the byte cap yet keep all graphemes) and a single U+2026 `…`;
  `search_graph_nodes/2` is accent-sensitive (`String.downcase`, never the
  accent-stripping `TextSearch.normalize/1`); `compute_edge_spread/1` output order
  follows `Enum.group_by` (not input order).
  """

  alias OGrupoDeEstudosWeb.GraphVisual.StudyJourney

  @typedoc "Raw graph from `Encyclopedia.build_graph`; node `category` is a `%Category{}` or nil."
  @type raw_graph :: %{nodes: [map()], edges: [map()]}

  @typedoc """
  Contexto da jornada de estudos para colorir/filtrar o grafo. `learned` são os
  códigos aprendidos; `full_map?` desliga a revelação progressiva (mostra tudo);
  `goal_code` é a próxima meta a destacar. O default não altera o grafo (full
  map, nada aprendido).
  """
  @type journey :: %{
          learned: MapSet.t(String.t()),
          full_map?: boolean(),
          goal_code: String.t() | nil
        }

  @typedoc "Assign-shaped search node where `category` is a STRING label."
  @type search_node :: %{code: String.t(), name: String.t(), category: String.t()}

  @typedoc "An edge with computed lateral spread for Cytoscape rendering."
  @type spread_edge :: %{from: String.t(), to: String.t(), label: term(), spread: integer()}

  @typedoc "A gap in a manual sequence: a consecutive pair with no connecting edge."
  @type missing_edge :: %{from: String.t(), to: String.t(), position: pos_integer()}

  @doc """
  Returns up to 8 nodes matching `term` (case-insensitive substring on code,
  name or category), ranked exact-code > code-prefix > name-prefix > other and
  tie-broken by name. Accent-SENSITIVE (uses `String.downcase`, never accent
  stripping). Consumes assign-shaped `search_node`s (string category).
  """
  @spec search_graph_nodes([search_node()], String.t()) :: [search_node()]
  def search_graph_nodes(nodes, term) do
    term = String.downcase(term)

    nodes
    |> Enum.filter(fn node ->
      String.contains?(String.downcase(node.code), term) or
        String.contains?(String.downcase(node.name), term) or
        String.contains?(String.downcase(node.category), term)
    end)
    |> Enum.sort_by(fn node ->
      code = String.downcase(node.code)
      name = String.downcase(node.name)

      cond do
        code == term -> {0, node.name}
        String.starts_with?(code, term) -> {1, node.name}
        String.starts_with?(name, term) -> {2, node.name}
        true -> {3, node.name}
      end
    end)
    |> Enum.take(8)
  end

  @default_journey %{learned: MapSet.new(), full_map?: true, goal_code: nil}

  @doc """
  Encodes the graph as the Cytoscape nodes/edges JSON. Consumes RAW graph
  structs (node `category` is a `%Category{}` or nil). When `include_orphans`
  is false only edge-connected nodes are emitted; each node still carries an
  `orphan` flag. Notes are truncated to 300 graphemes.

  The optional `journey` adds the study-journey overlay: each node gets
  `learned`/`frontier`/`goal` flags and each edge a `state`
  (`learned`/`frontier`/`hidden`). When `journey.full_map?` is false only the
  learned-plus-frontier nodes and their non-hidden edges are emitted (revelação
  progressiva). The default keeps the original behaviour (full map, no overlay).
  """
  @spec build_json(raw_graph(), boolean(), journey()) :: String.t()
  def build_json(graph, include_orphans, journey \\ @default_journey)

  def build_json(%{nodes: nodes, edges: edges}, include_orphans, journey) do
    learned = journey.learned
    frontier = StudyJourney.frontier(learned, edge_pairs(edges))
    connected = connected_codes(edges)
    visible = visible_codes(nodes, connected, include_orphans, journey, frontier)

    Jason.encode!(%{
      nodes: encode_nodes(nodes, visible, connected, learned, frontier, journey.goal_code),
      edges: encode_edges(edges, learned, visible, journey.full_map?)
    })
  end

  defp edge_pairs(edges) do
    Enum.map(edges, fn e -> {e.source_step.code, e.target_step.code} end)
  end

  defp connected_codes(edges) do
    edges
    |> Enum.flat_map(fn c -> [c.source_step.code, c.target_step.code] end)
    |> MapSet.new()
  end

  defp visible_codes(nodes, connected, include_orphans, %{full_map?: true}, _frontier) do
    base =
      if include_orphans, do: nodes, else: Enum.filter(nodes, &MapSet.member?(connected, &1.code))

    MapSet.new(base, & &1.code)
  end

  defp visible_codes(_nodes, _connected, _include_orphans, %{learned: learned}, frontier) do
    StudyJourney.visible_codes(learned, frontier)
  end

  defp encode_nodes(nodes, visible, connected, learned, frontier, goal_code) do
    nodes
    |> Enum.filter(&MapSet.member?(visible, &1.code))
    |> Enum.map(&node_map(&1, connected, learned, frontier, goal_code))
  end

  defp node_map(p, connected, learned, frontier, goal_code) do
    cat = p.category

    %{
      id: p.code,
      nome: p.name,
      categoria: if(cat, do: cat.label, else: "Outros"),
      categoriaName: if(cat, do: cat.name, else: "outros"),
      cor: if(cat, do: cat.color, else: "#9a7a5a"),
      nota: truncate_note(p.note, 300),
      highlighted: p.highlighted || false,
      suggested: p.suggested_by_id != nil,
      suggested_by_id: p.suggested_by_id,
      orphan: not MapSet.member?(connected, p.code),
      like_count: p.like_count || 0,
      learned: MapSet.member?(learned, p.code),
      frontier: MapSet.member?(frontier, p.code),
      goal: p.code == goal_code
    }
  end

  defp encode_edges(edges, learned, visible, full_map?) do
    edges
    |> compute_edge_spread()
    |> Enum.map(fn e -> Map.put(e, :state, StudyJourney.edge_state(learned, {e.from, e.to})) end)
    |> Enum.filter(&edge_visible?(&1, visible, full_map?))
  end

  defp edge_visible?(_edge, _visible, true), do: true

  defp edge_visible?(edge, visible, false) do
    edge.state != :hidden and MapSet.member?(visible, edge.from) and
      MapSet.member?(visible, edge.to)
  end

  @doc """
  Encodes only the orphan (edge-less) nodes as a compact JSON list
  (`id/nome/categoria/cor`). Consumes RAW graph structs.
  """
  @spec build_orphans_json(raw_graph()) :: String.t()
  def build_orphans_json(%{nodes: nodes, edges: edges}) do
    connected_codes =
      edges
      |> Enum.flat_map(fn c -> [c.source_step.code, c.target_step.code] end)
      |> MapSet.new()

    orphans =
      nodes
      |> Enum.reject(&MapSet.member?(connected_codes, &1.code))
      |> Enum.map(fn p ->
        cat = p.category

        %{
          id: p.code,
          nome: p.name,
          categoria: if(cat, do: cat.label, else: "Outros"),
          cor: if(cat, do: cat.color, else: "#9a7a5a")
        }
      end)

    Jason.encode!(orphans)
  end

  defp truncate_note(nil, _max), do: nil
  defp truncate_note(text, max) when byte_size(text) <= max, do: text
  defp truncate_note(text, max), do: String.slice(text, 0, max) <> "…"

  @doc """
  Computes lateral spread for edges so parallel edges from the same source fan
  out and reciprocal pairs separate. Output order follows `Enum.group_by`
  (not input order).
  """
  @spec compute_edge_spread([map()]) :: [spread_edge()]
  def compute_edge_spread(edges) do
    all_pairs = MapSet.new(edges, fn e -> {e.source_step.code, e.target_step.code} end)

    edges
    |> Enum.group_by(& &1.source_step.code)
    |> Enum.flat_map(fn {_source, group} ->
      spread_group(group, length(group))
    end)
    |> Enum.map(&apply_bidirectional_spread(&1, all_pairs))
  end

  defp apply_bidirectional_spread(%{spread: 0, from: from, to: to} = edge, pairs) do
    if MapSet.member?(pairs, {to, from}) do
      %{edge | spread: if(from <= to, do: 20, else: -20)}
    else
      edge
    end
  end

  defp apply_bidirectional_spread(edge, _pairs), do: edge

  defp spread_group(group, count) do
    group
    |> Enum.with_index()
    |> Enum.map(fn {edge, idx} ->
      spread = if count > 2, do: round((idx - (count - 1) / 2) * 20), else: 0

      %{
        from: edge.source_step.code,
        to: edge.target_step.code,
        label: edge.label,
        spread: spread
      }
    end)
  end

  @doc """
  Given an ordered list of step codes and the graph edges, returns the
  consecutive pairs with no connecting (directed) edge, each tagged with its
  1-based `position` in the sequence.
  """
  @spec find_missing_edges([String.t()], [map()]) :: [missing_edge()]
  def find_missing_edges(step_codes, edges) do
    edge_set =
      edges
      |> Enum.map(fn e -> {e.source_step.code, e.target_step.code} end)
      |> MapSet.new()

    step_codes
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index()
    |> Enum.reject(fn {[src, tgt], _i} -> MapSet.member?(edge_set, {src, tgt}) end)
    |> Enum.map(fn {[src, tgt], i} -> %{from: src, to: tgt, position: i + 1} end)
  end
end
