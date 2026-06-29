defmodule OGrupoDeEstudosWeb.GraphVisual.GraphDataTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.GraphVisual.GraphData

  # ── helpers ───────────────────────────────────────────────────────────

  defp mknode(code, opts \\ []) do
    %{
      code: code,
      name: Keyword.get(opts, :name, "Nome #{code}"),
      note: Keyword.get(opts, :note, nil),
      highlighted: Keyword.get(opts, :highlighted, false),
      suggested_by_id: Keyword.get(opts, :suggested_by_id, nil),
      like_count: Keyword.get(opts, :like_count, 0),
      category: Keyword.get(opts, :category, %{name: "basico", label: "Básico", color: "#abc"})
    }
  end

  defp edge(from, to, label \\ "x") do
    %{source_step: %{code: from}, target_step: %{code: to}, label: label}
  end

  defp decode_nodes(json), do: Jason.decode!(json)["nodes"]
  defp decode_edges(json), do: Jason.decode!(json)["edges"]
  defp by_code(nodes, code), do: Enum.find(nodes, &(&1["id"] == code))

  # ── build_json/2 ──────────────────────────────────────────────────────

  describe "build_json/2" do
    test "connected nodes produce 11-key maps with every field mapped" do
      a = mknode("BF", name: "Base", note: "nota curta", highlighted: true, like_count: 5)

      b =
        mknode("IV",
          name: "Inversão",
          note: nil,
          highlighted: false,
          suggested_by_id: 7,
          like_count: 0
        )

      json = GraphData.build_json(%{nodes: [a, b], edges: [edge("BF", "IV")]}, false)
      nodes = decode_nodes(json)

      assert is_binary(json)
      assert length(nodes) == 2

      bf = by_code(nodes, "BF")

      assert bf == %{
               "id" => "BF",
               "nome" => "Base",
               "categoria" => "Básico",
               "categoriaName" => "basico",
               "cor" => "#abc",
               "nota" => "nota curta",
               "highlighted" => true,
               "suggested" => false,
               "suggested_by_id" => nil,
               "orphan" => false,
               "like_count" => 5,
               "learned" => false,
               "frontier" => false,
               "goal" => false
             }

      iv = by_code(nodes, "IV")
      assert iv["nota"] == nil
      assert iv["highlighted"] == false
      assert iv["suggested"] == true
      assert iv["suggested_by_id"] == 7
      assert iv["orphan"] == false
      assert iv["like_count"] == 0
    end

    test "nil category falls back to Outros/outros/#9a7a5a" do
      json =
        GraphData.build_json(
          %{nodes: [mknode("X", category: nil)], edges: [edge("X", "X")]},
          false
        )

      x = decode_nodes(json) |> by_code("X")

      assert x["categoria"] == "Outros"
      assert x["categoriaName"] == "outros"
      assert x["cor"] == "#9a7a5a"
      assert x["orphan"] == false
    end

    test "orphan node excluded when include_orphans is false" do
      graph = %{nodes: [mknode("A"), mknode("Z")], edges: [edge("A", "B")]}
      nodes = GraphData.build_json(graph, false) |> decode_nodes()

      assert by_code(nodes, "A")
      refute by_code(nodes, "Z")
    end

    test "orphan node included and flagged when include_orphans is true" do
      graph = %{nodes: [mknode("A"), mknode("Z")], edges: [edge("A", "B")]}
      nodes = GraphData.build_json(graph, true) |> decode_nodes()

      assert by_code(nodes, "Z")["orphan"] == true
      assert by_code(nodes, "A")["orphan"] == false
    end

    test "empty graph returns empty nodes and edges" do
      json = GraphData.build_json(%{nodes: [], edges: []}, false)
      assert decode_nodes(json) == []
      assert decode_edges(json) == []
    end

    test "highlighted nil is coerced to false" do
      json =
        GraphData.build_json(
          %{nodes: [mknode("A", highlighted: nil)], edges: [edge("A", "A")]},
          false
        )

      assert (decode_nodes(json) |> by_code("A"))["highlighted"] == false
    end

    test "like_count nil is coerced to 0" do
      json =
        GraphData.build_json(
          %{nodes: [mknode("A", like_count: nil)], edges: [edge("A", "A")]},
          false
        )

      assert (decode_nodes(json) |> by_code("A"))["like_count"] == 0
    end

    test "note over 300 bytes is truncated to 300 graphemes plus ellipsis" do
      long = String.duplicate("a", 350)

      json =
        GraphData.build_json(%{nodes: [mknode("A", note: long)], edges: [edge("A", "A")]}, false)

      assert (decode_nodes(json) |> by_code("A"))["nota"] == String.duplicate("a", 300) <> "…"
    end

    test "note exactly 300 bytes is kept unchanged" do
      exact = String.duplicate("a", 300)

      json =
        GraphData.build_json(%{nodes: [mknode("A", note: exact)], edges: [edge("A", "A")]}, false)

      assert (decode_nodes(json) |> by_code("A"))["nota"] == exact
    end

    test "multibyte note over byte cap but under grapheme cap keeps all graphemes plus ellipsis" do
      # 200 × "ç" = 400 bytes but only 200 graphemes; byte_size > 300 triggers
      # the slice, but String.slice(_, 0, 300) returns all 200 graphemes.
      note = String.duplicate("ç", 200)

      json =
        GraphData.build_json(%{nodes: [mknode("A", note: note)], edges: [edge("A", "A")]}, false)

      assert (decode_nodes(json) |> by_code("A"))["nota"] == note <> "…"
    end

    test "edges carry compute_edge_spread output with from/to/label/spread" do
      json =
        GraphData.build_json(
          %{nodes: [mknode("A"), mknode("B")], edges: [edge("A", "B", "L")]},
          false
        )

      assert decode_edges(json) == [
               %{"from" => "A", "to" => "B", "label" => "L", "spread" => 0, "state" => "hidden"}
             ]
    end
  end

  # ── build_orphans_json/1 ──────────────────────────────────────────────

  describe "build_orphans_json/1" do
    test "serializes only orphan nodes with the 4-key shape" do
      z = mknode("Z", name: "Zeta", category: %{name: "c", label: "Cat", color: "#111"})
      json = GraphData.build_orphans_json(%{nodes: [mknode("A"), z], edges: [edge("A", "B")]})

      assert Jason.decode!(json) == [
               %{"id" => "Z", "nome" => "Zeta", "categoria" => "Cat", "cor" => "#111"}
             ]
    end

    test "orphan with nil category falls back to Outros/#9a7a5a and has no categoriaName" do
      json = GraphData.build_orphans_json(%{nodes: [mknode("O", category: nil)], edges: []})
      [o] = Jason.decode!(json)

      assert o["categoria"] == "Outros"
      assert o["cor"] == "#9a7a5a"
      refute Map.has_key?(o, "categoriaName")
    end

    test "fully connected graph returns empty list" do
      json =
        GraphData.build_orphans_json(%{
          nodes: [mknode("A"), mknode("B")],
          edges: [edge("A", "B")]
        })

      assert Jason.decode!(json) == []
    end

    test "empty graph returns empty list" do
      assert GraphData.build_orphans_json(%{nodes: [], edges: []}) |> Jason.decode!() == []
    end

    test "all-orphan graph returns every node in order" do
      json =
        GraphData.build_orphans_json(%{nodes: [mknode("A"), mknode("B"), mknode("C")], edges: []})

      assert Jason.decode!(json) |> Enum.map(& &1["id"]) == ["A", "B", "C"]
    end
  end

  # ── compute_edge_spread/1 (+ spread_group, apply_bidirectional_spread) ──

  describe "compute_edge_spread/1" do
    defp spread_of(edges, from, to) do
      Enum.find(edges, &(&1.from == from and &1.to == to)).spread
    end

    test "empty edge list returns empty" do
      assert GraphData.compute_edge_spread([]) == []
    end

    test "single edge with no reverse has spread 0" do
      assert GraphData.compute_edge_spread([edge("A", "B", "L")]) ==
               [%{from: "A", to: "B", label: "L", spread: 0}]
    end

    test "two edges from same source (count=2) both have spread 0" do
      result = GraphData.compute_edge_spread([edge("A", "B"), edge("A", "C")])
      assert Enum.map(result, & &1.spread) == [0, 0]
    end

    test "three edges from same source (count=3) spread symmetrically in order" do
      result = GraphData.compute_edge_spread([edge("A", "B"), edge("A", "C"), edge("A", "D")])
      assert Enum.map(result, & &1.spread) == [-20, 0, 20]
    end

    test "four edges from same source (count=4) spread to integer values" do
      edges = [edge("A", "B"), edge("A", "C"), edge("A", "D"), edge("A", "E")]
      # spreads are exact integers (round/1 only int-casts; spacing is a multiple of 10)
      assert GraphData.compute_edge_spread(edges) |> Enum.map(& &1.spread) == [-30, -10, 10, 30]
    end

    test "five edges from same source (count=5)" do
      edges = for t <- ~w(B C D E F), do: edge("A", t)

      assert GraphData.compute_edge_spread(edges) |> Enum.map(& &1.spread) == [
               -40,
               -20,
               0,
               20,
               40
             ]
    end

    test "bidirectional pair gets +20/-20 by lexical from<=to" do
      result = GraphData.compute_edge_spread([edge("A", "B"), edge("B", "A")])
      assert spread_of(result, "A", "B") == 20
      assert spread_of(result, "B", "A") == -20
    end

    test "bidirectional rule only adjusts spread==0 edges (B->A reverse present for nonzero A->B)" do
      # source A: 3 edges -> spreads [-20, 0, 20]; B->A makes {B,A} the reverse of the
      # NONZERO edge A->B. The spread==0 guard is the only thing keeping A->B at -20:
      # without it, {B,A} present + A<=B would flip A->B to +20. This pins the contract.
      edges = [edge("A", "B"), edge("A", "C"), edge("A", "D"), edge("B", "A")]
      result = GraphData.compute_edge_spread(edges)

      # load-bearing: nonzero edge with a present reverse stays put (guard active)
      assert spread_of(result, "A", "B") == -20
      assert spread_of(result, "A", "D") == 20
      # A->C is spread 0 but its reverse {C,A} is absent -> unchanged
      assert spread_of(result, "A", "C") == 0
      # B->A is spread 0 with reverse {A,B} present, B<=A false -> -20
      assert spread_of(result, "B", "A") == -20
    end

    test "self-loop with spread 0 and reverse takes the +20 branch" do
      assert GraphData.compute_edge_spread([edge("A", "A")]) |> spread_of("A", "A") == 20
    end

    test "multiple independent sources are grouped separately (assert by membership)" do
      edges = [edge("A", "B"), edge("A", "C"), edge("A", "D"), edge("X", "Y")]
      result = GraphData.compute_edge_spread(edges)

      assert length(result) == 4
      assert spread_of(result, "X", "Y") == 0

      assert Enum.sort([
               spread_of(result, "A", "B"),
               spread_of(result, "A", "C"),
               spread_of(result, "A", "D")
             ]) == [-20, 0, 20]
    end

    test "label and codes are copied verbatim" do
      assert GraphData.compute_edge_spread([edge("FOO", "BAR", "my-label")]) ==
               [%{from: "FOO", to: "BAR", label: "my-label", spread: 0}]
    end
  end

  # ── search_graph_nodes/2 ──────────────────────────────────────────────

  describe "search_graph_nodes/2" do
    defp snode(code, name, category), do: %{code: code, name: name, category: category}

    test "empty node list returns empty" do
      assert GraphData.search_graph_nodes([], "bf") == []
    end

    test "matches by code substring, case-insensitive" do
      nodes = [snode("BF", "Base", "Básico"), snode("IV", "Inversão", "Giros")]
      assert GraphData.search_graph_nodes(nodes, "bf") == [snode("BF", "Base", "Básico")]
    end

    test "matches by name substring" do
      nodes = [snode("X", "Caminhada", "Y")]
      assert GraphData.search_graph_nodes(nodes, "minh") == nodes
    end

    test "matches by category substring" do
      nodes = [snode("X", "foo", "Giros")]
      assert GraphData.search_graph_nodes(nodes, "gir") == nodes
    end

    test "no match returns empty" do
      assert GraphData.search_graph_nodes([snode("BF", "Base", "Básico")], "zzz") == []
    end

    test "is accent-sensitive (does not normalize accents)" do
      assert GraphData.search_graph_nodes([snode("X", "Inversão", "C")], "inversao") == []
    end

    test "ranks exact code, then code-prefix, then name-prefix, then other" do
      nodes = [
        snode("BA", "Zeta", "c"),
        snode("BAR", "Alpha", "c"),
        snode("X", "Bahia", "c"),
        snode("Y", "Samba", "c")
      ]

      assert GraphData.search_graph_nodes(nodes, "ba") |> Enum.map(& &1.code) == [
               "BA",
               "BAR",
               "X",
               "Y"
             ]
    end

    test "ties within a rank are broken by name ascending" do
      nodes = [snode("COB", "Zebra", "c"), snode("COA", "Abelha", "c")]
      assert GraphData.search_graph_nodes(nodes, "co") |> Enum.map(& &1.code) == ["COA", "COB"]
    end

    test "caps results at 8" do
      nodes = for i <- 0..9, do: snode("A#{i}", "alpha#{i}", "c")
      assert GraphData.search_graph_nodes(nodes, "a") |> length() == 8
    end

    test "lowercases the term before matching" do
      assert GraphData.search_graph_nodes([snode("bf", "base", "c")], "BF") == [
               snode("bf", "base", "c")
             ]
    end
  end

  # ── find_missing_edges/2 ──────────────────────────────────────────────

  describe "find_missing_edges/2" do
    test "empty step_codes returns empty" do
      assert GraphData.find_missing_edges([], [edge("A", "B")]) == []
    end

    test "single step code returns empty (no adjacent pair)" do
      assert GraphData.find_missing_edges(["A"], [edge("A", "B")]) == []
    end

    test "all consecutive pairs present returns empty" do
      assert GraphData.find_missing_edges(["A", "B", "C"], [edge("A", "B"), edge("B", "C")]) == []
    end

    test "one missing middle pair reports 1-based position" do
      assert GraphData.find_missing_edges(["A", "B", "C"], [edge("A", "B")]) ==
               [%{from: "B", to: "C", position: 2}]
    end

    test "multiple missing pairs report correct positions" do
      assert GraphData.find_missing_edges(["A", "B", "C", "D"], [edge("B", "C")]) ==
               [%{from: "A", to: "B", position: 1}, %{from: "C", to: "D", position: 3}]
    end

    test "direction matters: A->B does not satisfy pair B->A" do
      assert GraphData.find_missing_edges(["B", "A"], [edge("A", "B")]) ==
               [%{from: "B", to: "A", position: 1}]
    end

    test "empty edges marks all pairs missing" do
      assert GraphData.find_missing_edges(["A", "B", "C"], []) ==
               [%{from: "A", to: "B", position: 1}, %{from: "B", to: "C", position: 2}]
    end

    test "repeated step code without a self-edge is missing" do
      assert GraphData.find_missing_edges(["A", "A"], [edge("A", "B")]) ==
               [%{from: "A", to: "A", position: 1}]
    end

    test "repeated step code WITH a self-edge is satisfied" do
      assert GraphData.find_missing_edges(["A", "A"], [edge("A", "A")]) == []
    end
  end

  # ── build_json/3 — overlay da jornada de estudos ──────────────────────

  defp journey(opts) do
    %{
      learned: MapSet.new(Keyword.get(opts, :learned, [])),
      full_map?: Keyword.get(opts, :full_map?, true),
      goal_code: Keyword.get(opts, :goal_code, nil)
    }
  end

  describe "build_json/3 jornada" do
    test "default (sem journey) mantém o comportamento atual com flags falsas" do
      graph = %{nodes: [mknode("BF"), mknode("SC")], edges: [edge("BF", "SC")]}
      bf = GraphData.build_json(graph, true) |> decode_nodes() |> by_code("BF")

      assert bf["learned"] == false
      assert bf["frontier"] == false
      assert bf["goal"] == false
    end

    test "tagueia nós aprendidos, de fronteira e a meta" do
      graph = %{
        nodes: [mknode("BF"), mknode("SC"), mknode("IV")],
        edges: [edge("BF", "SC"), edge("BF", "IV")]
      }

      nodes =
        GraphData.build_json(graph, true, journey(learned: ["BF"], goal_code: "SC"))
        |> decode_nodes()

      assert by_code(nodes, "BF")["learned"] == true
      assert by_code(nodes, "SC")["frontier"] == true
      assert by_code(nodes, "SC")["goal"] == true
      assert by_code(nodes, "IV")["frontier"] == true
      assert by_code(nodes, "IV")["learned"] == false
    end

    test "tagueia o estado das arestas (learned/frontier/hidden)" do
      graph = %{
        nodes: [mknode("BF"), mknode("SC"), mknode("IV")],
        edges: [edge("BF", "SC"), edge("SC", "IV")]
      }

      edges =
        GraphData.build_json(graph, true, journey(learned: ["BF", "SC"]))
        |> decode_edges()

      bf_sc = Enum.find(edges, &(&1["from"] == "BF" and &1["to"] == "SC"))
      sc_iv = Enum.find(edges, &(&1["from"] == "SC" and &1["to"] == "IV"))

      assert bf_sc["state"] == "learned"
      assert sc_iv["state"] == "frontier"
    end

    test "fora do mapa completo, só mostra aprendidos + fronteira e oculta o resto" do
      graph = %{
        nodes: [mknode("BF"), mknode("SC"), mknode("IV"), mknode("XX")],
        edges: [edge("BF", "SC"), edge("SC", "IV"), edge("XX", "IV")]
      }

      json = GraphData.build_json(graph, true, journey(learned: ["BF"], full_map?: false))
      codes = json |> decode_nodes() |> Enum.map(& &1["id"]) |> Enum.sort()
      edges = decode_edges(json)

      # BF (aprendido) + SC (fronteira); IV e XX ficam ocultos
      assert codes == ["BF", "SC"]
      # só a aresta BF->SC (frontier) aparece; SC->IV e XX->IV são ocultas
      assert Enum.map(edges, &{&1["from"], &1["to"]}) == [{"BF", "SC"}]
    end

    test "no mapa completo, mostra tudo mesmo com a jornada ativa" do
      graph = %{
        nodes: [mknode("BF"), mknode("SC"), mknode("XX")],
        edges: [edge("BF", "SC"), edge("XX", "SC")]
      }

      json = GraphData.build_json(graph, true, journey(learned: ["BF"], full_map?: true))
      codes = json |> decode_nodes() |> Enum.map(& &1["id"]) |> Enum.sort()

      assert codes == ["BF", "SC", "XX"]
      assert length(decode_edges(json)) == 2
    end
  end
end
