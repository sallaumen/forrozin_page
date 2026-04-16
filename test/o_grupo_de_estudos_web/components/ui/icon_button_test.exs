defmodule OGrupoDeEstudosWeb.UI.IconButtonTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.IconButton

  describe "icon_button/1" do
    test "requires aria-label and renders it" do
      html = render_component(&IconButton.icon_button/1, %{
        label: "Fechar modal",
        icon: "hero-x-mark"
      })
      assert html =~ ~s(aria-label="Fechar modal")
    end

    test "renders the icon via heroicons" do
      html = render_component(&IconButton.icon_button/1, %{
        label: "Remover",
        icon: "hero-trash"
      })
      assert html =~ "hero-trash"
    end

    test "has data-ui attribute" do
      html = render_component(&IconButton.icon_button/1, %{
        label: "x",
        icon: "hero-x-mark"
      })
      assert html =~ ~s(data-ui="icon-button")
    end

    test "each variant renders correct data-variant" do
      for variant <- [:default, :ghost, :danger] do
        html = render_component(&IconButton.icon_button/1, %{
          label: "x",
          icon: "hero-x-mark",
          variant: variant
        })
        assert html =~ ~s(data-variant="#{variant}")
      end
    end

    test "passes through phx-click" do
      html = render_component(&IconButton.icon_button/1, %{
        label: "Delete",
        icon: "hero-trash",
        "phx-click": "delete_item"
      })
      assert html =~ ~s(phx-click="delete_item")
    end
  end
end
