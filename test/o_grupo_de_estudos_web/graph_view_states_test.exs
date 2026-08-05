defmodule OGrupoDeEstudosWeb.GraphViewStatesTest do
  @moduledoc """
  The map's sequence panel only draws states it can actually be put in.

  Two whole branches, a hundred and thirty two lines of them, waited for
  `:favorites` and `:saved`. No line in the app ever assigns those, so nobody
  had ever seen them render, and reading the file they looked like features. A
  branch that cannot run is worse than no branch: it is a promise the code does
  not keep.
  """

  use ExUnit.Case, async: true

  @template "lib/o_grupo_de_estudos_web/live/graph_visual_live.html.heex"

  defp assigned_states do
    "lib/**/*.ex"
    |> Path.wildcard()
    |> Enum.flat_map(fn path ->
      ~r/assign\(:seq_view, :(\w+)\)/
      |> Regex.scan(File.read!(path), capture: :all_but_first)
      |> List.flatten()
    end)
    |> MapSet.new()
  end

  defp drawn_states do
    ~r/@seq_view ==? :(\w+)/
    |> Regex.scan(File.read!(@template), capture: :all_but_first)
    |> List.flatten()
    |> MapSet.new()
  end

  test "every state the panel draws is a state the app can reach" do
    orphans = MapSet.difference(drawn_states(), assigned_states())

    assert MapSet.to_list(orphans) == [],
           """
           O painel desenha estados que nada atribui: #{inspect(MapSet.to_list(orphans))}.
           Ou o estado passa a ser atribuído, ou o ramo sai.
           """
  end
end
