defmodule OGrupoDeEstudosWeb.RootLayoutTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "root layout" do
    test "viewport meta includes viewport-fit=cover for safe-area support", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~s(<meta name="viewport")

      assert html =~ "viewport-fit=cover",
             "viewport meta should include viewport-fit=cover to enable safe-area-inset"
    end

    test "viewport meta includes width=device-width and initial-scale=1", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "width=device-width"
      assert html =~ "initial-scale=1"
    end

    test "root layout preloads Inter variable font", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~s(<link rel="preload"),
             "root layout should include a <link rel=\"preload\"> for fonts"

      assert html =~ "Inter-Variable.woff2",
             "root layout should preload Inter-Variable.woff2 to avoid FOIT"

      assert html =~ ~s(as="font"),
             "preload link should declare as=\"font\""

      assert html =~ "crossorigin",
             "preload link for font must have crossorigin attribute"
    end

    test "root layout links to PWA manifest", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~s(<link rel="manifest"),
             "root layout should reference /manifest.json"

      assert html =~ "manifest.json"
    end
  end

  describe "loading splash" do
    test "ships inside the first HTTP response, before any JavaScript runs", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ ~s(id="app-splash"),
             "the splash has to arrive with the HTML: it covers the wait for CSS and JS"
    end

    test "carries the logo inline, so the wait costs no extra request", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      [_, splash] = String.split(html, ~s(id="app-splash"), parts: 2)
      [splash, _] = String.split(splash, "</div>", parts: 2)

      assert splash =~ "M212.8 166.9 A140 140 0 0 0 212.8 433.1"
      refute splash =~ "<img"
    end

    test "tells assistive technology that the app is loading", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      [_, splash] = String.split(html, ~s(id="app-splash"), parts: 2)
      [splash, _] = String.split(splash, "</div>", parts: 2)

      assert splash =~ ~s(role="status")
      assert splash =~ "Carregando"
    end

    test "covers pages served by a plain controller too", %{conn: conn} do
      html = conn |> get(~p"/login") |> html_response(200)

      assert html =~ ~s(id="app-splash")
    end
  end
end
