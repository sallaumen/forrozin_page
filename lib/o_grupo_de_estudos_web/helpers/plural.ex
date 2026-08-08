defmodule OGrupoDeEstudosWeb.Helpers.Plural do
  @moduledoc """
  Counted labels in natural portuguese, instead of the "(s)" shortcut.

  Zero takes the plural, as portuguese does: "0 passos", "1 passo",
  "2 passos". Whole phrases work too, so adjectives agree along.
  """

  @doc ~S|plural(1, "passo", "passos") => "1 passo"|
  def plural(1, singular, _plural), do: "1 #{singular}"
  def plural(count, _singular, plural), do: "#{count} #{plural}"
end
