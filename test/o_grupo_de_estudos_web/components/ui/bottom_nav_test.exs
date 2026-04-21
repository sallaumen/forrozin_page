defmodule OGrupoDeEstudosWeb.UI.BottomNavTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.BottomNav

  defp user, do: %{username: "tavano", first_name: "Tavano"}

  describe "bottom_nav/1" do
    test "data-ui attribute present" do
      html =
        render_component(&BottomNav.bottom_nav/1, %{
          current_user: user(),
          current_path: "/collection"
        })

      assert html =~ ~s(data-ui="bottom-nav")
    end

    test "renders tab links including estudos and generator" do
      html =
        render_component(&BottomNav.bottom_nav/1, %{
          current_user: user(),
          current_path: "/collection"
        })

      assert html =~ ~s(href="/collection")
      assert html =~ ~s(href="/graph/visual")
      assert html =~ ~s(href="/study")
      assert html =~ ~s(href="/graph/visual?mode=generator")
      assert html =~ ~s(href="/community")
      assert html =~ ~s(href="/notifications")
      assert html =~ ~s(href="/users/tavano")
    end

    test "tab labels present" do
      html =
        render_component(&BottomNav.bottom_nav/1, %{
          current_user: user(),
          current_path: "/collection"
        })

      assert html =~ "Acervo"
      assert html =~ "Mapa"
      assert html =~ "Estudos"
      assert html =~ "Gerador"
      assert html =~ "Comunidade"
      assert html =~ "Alertas"
      assert html =~ "Perfil"
    end

    test "generator tab can be active independently from the map tab" do
      html =
        render_component(&BottomNav.bottom_nav/1, %{
          current_user: user(),
          current_path: "/graph/visual?mode=generator"
        })

      assert html =~ ~s(href="/graph/visual?mode=generator")
      assert html =~ ~s(data-active="true")
    end

    test "active tab marked with data-active=true when current_path matches" do
      html =
        render_component(&BottomNav.bottom_nav/1, %{
          current_user: user(),
          current_path: "/collection"
        })

      assert html =~ ~s(data-active="true")
    end

    test "inactive tabs have data-active=false" do
      html =
        render_component(&BottomNav.bottom_nav/1, %{
          current_user: user(),
          current_path: "/collection"
        })

      assert html =~ ~s(data-active="false")
    end
  end
end
