defmodule OGrupoDeEstudosWeb.UI.LogoMarkTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.LogoMark

  describe "logo_mark/1" do
    test "renders the mark as inline svg, costing no extra request" do
      html = render_component(&LogoMark.logo_mark/1, %{})

      assert html =~ ~s(data-ui="logo-mark")
      assert html =~ "<svg"
      refute html =~ "<img"
    end

    test "draws the two dancers with currentColor so it inherits the text color" do
      html = render_component(&LogoMark.logo_mark/1, %{})

      assert html =~ ~s(fill="currentColor")
      assert html =~ ~s(stroke="currentColor")
      assert html =~ "M212.8 166.9 A140 140 0 0 0 212.8 433.1"
      assert html =~ "M299.2 166.9 A140 140 0 0 1 299.2 433.1"
    end

    test "is decorative by default: screen readers skip it" do
      html = render_component(&LogoMark.logo_mark/1, %{})

      assert html =~ ~s(aria-hidden="true")
      refute html =~ "aria-label"
    end

    test "reads as an image with the given label when one is passed" do
      html = render_component(&LogoMark.logo_mark/1, %{label: "O"})

      assert html =~ ~s(role="img")
      assert html =~ ~s(aria-label="O")
      refute html =~ "aria-hidden"
    end

    test "crops to the mark by default and accepts another viewbox" do
      assert render_component(&LogoMark.logo_mark/1, %{}) =~ ~s(viewBox="96 76 320 384")

      assert render_component(&LogoMark.logo_mark/1, %{viewbox: "0 0 512 512"}) =~
               ~s(viewBox="0 0 512 512")
    end

    test "forwards class and arbitrary attributes to the svg" do
      html = render_component(&LogoMark.logo_mark/1, %{class: "h-8", style: "height: 1.6em"})

      assert html =~ "h-8"
      assert html =~ "height: 1.6em"
    end
  end
end
