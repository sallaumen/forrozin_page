defmodule OGrupoDeEstudosWeb.CollectionBackNavigationTest do
  @moduledoc """
  The phone's back button, inside the acervo.

  Opening a family, switching tab and opening a step each changed an assign and
  nothing else. The browser was handed no history entry, so the back gesture
  skipped the whole acervo at once and left the site. Each of those is a place,
  and a place lives in the URL.

  What stays out of the URL stays out on purpose: the search term and the edit
  mode describe how the page is being used, not which page it is.

  The params are asserted in alphabetical order because `config/test.exs` sets
  `sort_verified_routes_query_params`, which exists so route assertions do not
  depend on the order a keyword list happens to be written in. Outside the test
  env the same address comes out in the order `collection_path/1` declares.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.CollectionLive

  setup do
    category = insert(:category, name: "bases", label: "Bases", color: "#8a5a2b")
    section = insert(:section, category: category, title: "Bases", code: "B", position: 1)
    step = insert(:step, section: section, category: category, code: "BF", name: "Base frontal")

    %{user: insert(:user), category: category, section: section, step: step}
  end

  defp open(conn, user, path \\ "/collection"), do: live(log_in_user(conn, user), path)

  defp with_filters_open(lv) do
    lv |> element("#collection-filter-toggle") |> render_click()
    lv
  end

  describe "the address of the acervo" do
    test "a default is not worth writing down" do
      assert CollectionLive.collection_path([]) == "/collection"
      assert CollectionLive.collection_path(category: "all") == "/collection"
      assert CollectionLive.collection_path(tab: "collection") == "/collection"
      assert CollectionLive.collection_path(section: nil, detail: "") == "/collection"
    end

    test "the family and the filter travel together" do
      assert CollectionLive.collection_path(section: "abc", category: "bases") ==
               "/collection?category=bases&section=abc"
    end

    test "the tab is written the way a url is written, not the way an assign is" do
      assert CollectionLive.collection_path(tab: "my_steps") == "/collection?tab=my-steps"
    end
  end

  describe "opening a family" do
    test "the tile is a link, so the phone knows there is somewhere to go back to", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user)

      assert has_element?(lv, ~s{a[href="/collection?section=#{ctx.section.id}"]})
    end

    test "the family opens straight from its own address", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user, "/collection?section=#{ctx.section.id}")

      assert has_element?(lv, "#collection-drilldown-shell")
      assert has_element?(lv, "#collection-step-BF")
    end

    test "going back to the acervo address brings the mosaic back", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user, "/collection?section=#{ctx.section.id}")

      html = render_patch(lv, "/collection")

      assert html =~ "collection-overview-grid"
      refute html =~ "collection-drilldown-shell"
    end

    test "leaving the family is a step back, not one more step forward", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user, "/collection?section=#{ctx.section.id}")

      assert has_element?(lv, ~s{#collection-breadcrumb-back[data-fallback="/collection"]})
    end
  end

  describe "the tabs" do
    test "Meus passos has an address of its own", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user)

      assert has_element?(lv, ~s{#collection-tabs a[href="/collection?tab=my-steps"]})
    end

    test "the tab opens straight from its address, and the acervo is one back", ctx do
      {:ok, lv, html} = open(ctx.conn, ctx.user, "/collection?tab=my-steps")

      assert html =~ "Você ainda não sugeriu nenhum passo"
      assert has_element?(lv, ~s{#collection-tabs a[href="/collection"]})
    end

    test "the filter follows along when the tab changes", ctx do
      {:ok, lv, _html} = ctx.conn |> open(ctx.user, "/collection?category=bases")

      assert has_element?(
               lv,
               ~s{#collection-tabs a[href="/collection?category=bases&tab=my-steps"]}
             )
    end
  end

  describe "the step drawer" do
    test "a step opens on top of the family it belongs to", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user, "/collection?section=#{ctx.section.id}")

      lv |> element("#collection-step-BF") |> render_click()

      assert_patch(lv, "/collection?detail=BF&section=#{ctx.section.id}")
    end

    test "the drawer opens straight from its address", ctx do
      {:ok, lv, html} =
        open(ctx.conn, ctx.user, "/collection?section=#{ctx.section.id}&detail=BF")

      assert has_element?(lv, "#collection-drawer-back")
      assert html =~ "Base frontal"
    end

    test "going back closes the drawer and leaves the family standing", ctx do
      {:ok, lv, _html} =
        open(ctx.conn, ctx.user, "/collection?section=#{ctx.section.id}&detail=BF")

      html = render_patch(lv, "/collection?section=#{ctx.section.id}")

      refute has_element?(lv, "#collection-drawer-back")
      assert html =~ "collection-drilldown-shell"
    end

    test "closing the drawer is a step back, not one more step forward", ctx do
      {:ok, lv, _html} =
        open(ctx.conn, ctx.user, "/collection?section=#{ctx.section.id}&detail=BF")

      fallback = "/collection?section=#{ctx.section.id}"

      assert has_element?(lv, ~s{#collection-drawer-back[data-fallback="#{fallback}"]})
      assert has_element?(lv, ~s{#collection-drawer-close[data-fallback="#{fallback}"]})
    end

    test "a step opened from the search does not drag a family along", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user)

      render_change(lv, "search", %{"term" => "base"})
      lv |> element("#collection-step-list-BF") |> render_click()

      assert_patch(lv, "/collection?detail=BF")
    end

    test "a code nobody published leaves the acervo as it was", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user, "/collection?detail=NAO-EXISTE")

      refute has_element?(lv, "#collection-drawer-back")
      assert has_element?(lv, "#collection-overview-grid")
    end
  end

  describe "the category filter" do
    test "the filter is in the address, so it survives leaving the page", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user)

      assert lv |> with_filters_open() |> has_element?(~s{a[href="/collection?category=bases"]})
    end

    test "choosing a filter is not a step to walk back through", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user)

      assert lv
             |> with_filters_open()
             |> has_element?(
               ~s{a[href="/collection?category=bases"][data-phx-link-state="replace"]}
             )
    end

    test "the filter stays put when a family opens on top of it", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user, "/collection?category=bases")

      assert has_element?(
               lv,
               ~s{a[href="/collection?category=bases&section=#{ctx.section.id}"]}
             )
    end
  end

  describe "what the url does not carry" do
    test "typing in the search does not pile up steps to walk back through", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user)

      html = render_change(lv, "search", %{"term" => "base"})

      assert html =~ "Base frontal"
      refute html =~ "term=base", "cada letra digitada viraria uma entrada no histórico"
    end

    test "a deep-linked step still lands on the row, marked", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user, "/collection?step=BF")

      assert has_element?(lv, "#collection-drilldown-shell")
      assert has_element?(lv, "#collection-step-BF[data-deep-linked='true']")
    end
  end
end
