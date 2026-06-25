defmodule OGrupoDeEstudos.Sequences.Generator.GraphTraversalTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Sequences.Generator.GraphTraversal, as: GT

  defp conn(source, target), do: %{source_step_id: source, target_step_id: target}

  describe "build_adjacency/1" do
    test "maps each source to its targets" do
      adj = GT.build_adjacency([conn("a", "b"), conn("a", "c"), conn("b", "c")])
      assert Enum.sort(adj["a"]) == ["b", "c"]
      assert adj["b"] == ["c"]
    end
  end

  describe "build_reverse_adjacency/1" do
    test "maps each target to its sources" do
      radj = GT.build_reverse_adjacency([conn("a", "b"), conn("c", "b")])
      assert Enum.sort(radj["b"]) == ["a", "c"]
    end
  end

  describe "reachable_from/2" do
    test "finds all reachable nodes" do
      adj = GT.build_adjacency([conn("a", "b"), conn("b", "c"), conn("c", "d")])
      assert GT.reachable_from("a", adj) == MapSet.new(["a", "b", "c", "d"])
      assert GT.reachable_from("c", adj) == MapSet.new(["c", "d"])
    end
  end

  describe "bfs_distances/2" do
    test "computes shortest distances from the start" do
      adj = GT.build_adjacency([conn("a", "b"), conn("b", "c"), conn("c", "d")])
      dists = GT.bfs_distances("a", adj)
      assert dists["a"] == 0
      assert dists["b"] == 1
      assert dists["d"] == 3
    end
  end

  describe "bfs_path/3" do
    test "returns a path from source to target" do
      adj = GT.build_adjacency([conn("a", "b"), conn("b", "c")])
      assert {:ok, path} = GT.bfs_path("a", "c", adj)
      assert hd(path) == "a"
      assert List.last(path) == "c"
    end

    test "returns :no_path when target is unreachable" do
      adj = GT.build_adjacency([conn("a", "b")])
      assert GT.bfs_path("a", "z", adj) == :no_path
    end

    test "returns the trivial path when source == target" do
      assert GT.bfs_path("a", "a", %{}) == {:ok, ["a"]}
    end
  end
end
