defmodule OGrupoDeEstudosWeb.UI.SocialBubbleTest do
  @moduledoc """
  Where the people button sits, and why it is not a fixed number.

  It sat at `bottom-20`: 80px, chosen when the tab bar was 56px tall and nothing
  else. On an iPhone the bar also carries `env(safe-area-inset-bottom)`, so it is
  around 90px, and the button's lower edge fell 12px inside it. Measured in the
  browser at 375px by feeding the same inset the phone reports.

  The bar publishes its own height in `--bottom-nav-h`, which is what the map's
  floating button already reads. Both offsets here come from it.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias OGrupoDeEstudosWeb.UI.SocialBubble

  defp bubble(opts \\ []) do
    render_component(
      &SocialBubble.social_bubble/1,
      Keyword.merge([current_user: %{id: Ecto.UUID.generate(), username: "tavano"}], opts)
    )
  end

  test "the button measures its gap from the bar instead of guessing it" do
    html = bubble()

    assert html =~ "var(--bottom-nav-h)"

    refute html =~ "bottom-20",
           "80px era a barra de 56px mais folga; num iPhone a barra passa de 90"
  end

  test "the panel is measured from the same bar, so it stays above the button" do
    html = bubble(bubble_open: true)

    [_, painel] = String.split(html, ~s(animation: fadeSlideUp), parts: 2)
    abertura = painel |> String.split(">", parts: 2) |> hd()

    refute abertura =~ "bottom-[136px]"
    assert html =~ "var(--bottom-nav-h)"
  end

  test "a wide screen keeps its own offsets, where there is no tab bar to clear" do
    html = bubble()

    assert html =~ "md:bottom-6"
  end
end
