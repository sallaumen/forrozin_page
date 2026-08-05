defmodule OGrupoDeEstudosWeb.UI.BottomNavTest do
  @moduledoc """
  The tab bar: five places, not seven items.

  Apple and Material both stop at five, and it is not arbitrary: at 375px seven
  tabs give each one 53px with a 10px label, and the label is what makes a tab
  bar learnable. Two of the seven were not places at all. "Gerador" is
  `/graph/visual?mode=generator`, a mode of the map, reachable from the map's own
  panel; notifications are a check-in, and the bell lives in the top bar.
  """

  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.BottomNav

  defp user, do: %{username: "tavano", first_name: "Tavano"}

  defp nav(overrides \\ []) do
    assigns = Enum.into(overrides, %{current_user: user(), current_path: "/collection"})

    render_component(&BottomNav.bottom_nav/1, assigns)
  end

  describe "bottom_nav/1" do
    test "data-ui attribute present" do
      assert nav() =~ ~s(data-ui="bottom-nav")
    end

    test "the five places of the product, and nothing else" do
      html = nav()

      for path <- ~w(/collection /graph/visual /study /sequence /users/tavano) do
        assert html =~ ~s(href="#{path}")
      end

      assert count(html, "<a ") == 5
    end

    test "every tab keeps its label, which is what makes the bar learnable" do
      html = nav()

      for label <- ["Acervo", "Mapa", "Estudos", "Sequências", "Perfil"] do
        assert html =~ label
      end
    end

    test "the generator is a mode of the map, not a place of its own" do
      html = nav()

      refute html =~ "mode=generator"
      refute html =~ "Gerador"
    end

    test "notifications are a check-in: the bell lives in the top bar" do
      html = nav()

      refute html =~ ~s(href="/notifications")
      refute html =~ "Alertas"
    end

    test "the map tab stays lit while the generator mode is open" do
      assert nav(current_path: "/graph/visual?mode=generator") =~ ~s(data-active="true")
    end

    test "active tab marked with data-active=true when current_path matches" do
      assert nav() =~ ~s(data-active="true")
    end

    test "inactive tabs have data-active=false" do
      assert nav() =~ ~s(data-active="false")
    end

    test "a pending study request still shows up on the Estudos tab" do
      assert nav(pending_study_count: 2) =~ "2"
    end
  end

  defp count(html, needle), do: length(String.split(html, needle)) - 1
end
