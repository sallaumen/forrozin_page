defmodule OGrupoDeEstudosWeb.UI.TopNavTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.TopNav
  alias OGrupoDeEstudos.Accounts.User

  defp user(attrs \\ %{}) do
    struct(User, Map.merge(%{username: "tavano", name: "Tavano Silva"}, attrs))
  end

  describe "top_nav/1" do
    test "renders brand link to /collection" do
      html = render_component(&TopNav.top_nav/1, %{
        current_user: user(),
        is_admin: false,
        nav_mode: :primary
      })

      assert html =~ ~s(href="/collection")
      assert html =~ "O Grupo de Estudos"
    end

    test "has data-ui attribute with data-mode" do
      html = render_component(&TopNav.top_nav/1, %{
        current_user: user(),
        is_admin: false,
        nav_mode: :primary
      })

      assert html =~ ~s(data-ui="top-nav")
      assert html =~ ~s(data-mode="primary")
    end

    test "desktop nav includes Acervo, Mapa, Comunidade links" do
      html = render_component(&TopNav.top_nav/1, %{
        current_user: user(),
        is_admin: false,
        nav_mode: :primary
      })

      assert html =~ "Acervo"
      assert html =~ "Mapa"
      assert html =~ "Comunidade"
    end

    test "admin sees admin links when is_admin=true" do
      html = render_component(&TopNav.top_nav/1, %{
        current_user: user(),
        is_admin: true,
        nav_mode: :primary
      })

      assert html =~ "Conexões"
      assert html =~ ~s(href="/admin/links")
      assert html =~ ~s(href="/admin/backups")
    end

    test "non-admin does NOT see admin links" do
      html = render_component(&TopNav.top_nav/1, %{
        current_user: user(),
        is_admin: false,
        nav_mode: :primary
      })

      refute html =~ "Conexões"
      refute html =~ "/admin/links"
      refute html =~ "/admin/backups"
    end

    test "greeting + settings + logout always present for authenticated user" do
      html = render_component(&TopNav.top_nav/1, %{
        current_user: user(),
        is_admin: false,
        nav_mode: :primary
      })

      assert html =~ "Tavano"
      assert html =~ ~s(href="/users/tavano")
      assert html =~ ~s(href="/settings")
      assert html =~ "sair"
    end

    test "detail mode renders back button (data-ui=\"back-button\")" do
      html = render_component(&TopNav.top_nav/1, %{
        current_user: user(),
        is_admin: false,
        nav_mode: :detail,
        title: "BF — Base Fundamental"
      })

      assert html =~ ~s(data-ui="back-button")
    end

    test "detail mode shows title when provided" do
      html = render_component(&TopNav.top_nav/1, %{
        current_user: user(),
        is_admin: false,
        nav_mode: :detail,
        title: "Configurações"
      })

      assert html =~ "Configurações"
    end

    test "detail mode without title renders without error" do
      html = render_component(&TopNav.top_nav/1, %{
        current_user: user(),
        is_admin: false,
        nav_mode: :detail
      })

      assert html =~ ~s(data-mode="detail")
    end
  end
end
