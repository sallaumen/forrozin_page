defmodule OGrupoDeEstudosWeb.Meta do
  @moduledoc """
  Text for link previews: what WhatsApp shows under a shared link.

  A preview card holds one line or two. The page text arrives with paragraphs and
  line breaks, so the summary collapses it to one line and cuts it where the card
  would cut anyway, instead of trusting each messenger to be sensible about it.
  """

  @limit 160

  @doc "The text in one line, at most #{@limit} characters, cut with an ellipsis."
  @spec summary(String.t() | nil) :: String.t() | nil
  def summary(nil), do: nil

  def summary(text) do
    collapsed = text |> String.split(~r/\s+/, trim: true) |> Enum.join(" ")

    if String.length(collapsed) <= @limit do
      collapsed
    else
      String.slice(collapsed, 0, @limit - 1) <> "…"
    end
  end
end
