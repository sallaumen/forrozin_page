defmodule OGrupoDeEstudosWeb.GraphVisual.TextSearch do
  @moduledoc """
  Accent-insensitive text normalization shared by the graph-step search and the
  sequence-library filters: NFD-decompose, strip combining marks (`\\p{Mn}`),
  downcase. `nil` normalizes to `""`.

  Deliberately distinct from `GraphData.search_graph_nodes/2`, which is
  accent-SENSITIVE (plain `String.downcase`); do not consolidate the two.
  """

  @doc "Normalizes `text` for accent-insensitive substring matching."
  @spec normalize(String.t() | nil | term()) :: String.t()
  def normalize(nil), do: ""

  def normalize(text) do
    text
    |> to_string()
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
  end
end
