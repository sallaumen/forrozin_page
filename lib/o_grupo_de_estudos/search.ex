defmodule OGrupoDeEstudos.Search do
  @moduledoc """
  Helpers for safe text search against the database.
  """

  @doc """
  Escapes `LIKE`/`ILIKE` wildcards (`%`, `_`) and the escape character (`\\`)
  so a user's search term is matched literally instead of as a pattern.

  Use with the default `\\` escape character, e.g.
  `ilike(field, ^"%\#{escape_like(term)}%")`.
  """
  def escape_like(term) do
    term
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
