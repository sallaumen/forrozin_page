defmodule OGrupoDeEstudosWeb.ArchitectureTest do
  @moduledoc """
  The layer rules of CLAUDE.md, executable. A grep someone has to remember to
  run is a rule that erodes; a failing test is not.

  The web layer talks to contexts only: no Repo, no Ecto queries, no `*Query`
  modules. Whatever the web needs, the owning context exposes.
  """

  use ExUnit.Case, async: true

  @web_root "lib/o_grupo_de_estudos_web"

  test "web layer does not touch Repo or Ecto.Query" do
    forbidden = ~r/\bRepo\.|import Ecto\.Query/

    assert scan(forbidden) == []
  end

  test "web layer does not call Query modules directly" do
    forbidden = ~r/\b[A-Z][A-Za-z]*Query\./

    assert scan(forbidden) == []
  end

  defp scan(forbidden) do
    for path <- web_files(),
        {line, number} <- numbered_lines(path),
        Regex.match?(forbidden, strip_comment(line)),
        do: "#{path}:#{number}: #{String.trim(line)}"
  end

  defp web_files do
    Path.wildcard("#{@web_root}/**/*.{ex,heex}")
  end

  defp numbered_lines(path) do
    path |> File.read!() |> String.split("\n") |> Enum.with_index(1)
  end

  defp strip_comment(line) do
    line |> String.split("#", parts: 2) |> hd()
  end
end
