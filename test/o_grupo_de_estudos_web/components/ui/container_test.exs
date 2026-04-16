defmodule OGrupoDeEstudosWeb.UI.ContainerTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.Container

  describe "container/1" do
    test "renders content inside a div wrapper" do
      html =
        render_component(&Container.container/1, %{
          inner_block: [%{inner_block: fn _, _ -> "page content" end, __slot__: :inner_block}]
        })

      assert html =~ "page content"
      assert html =~ "<div"
    end

    test "accepts custom class via :class attr" do
      html =
        render_component(&Container.container/1, %{
          class: "custom-class",
          inner_block: [%{inner_block: fn _, _ -> "x" end, __slot__: :inner_block}]
        })

      assert html =~ "custom-class"
    end

    test "has data-ui attribute for identification" do
      html =
        render_component(&Container.container/1, %{
          inner_block: [%{inner_block: fn _, _ -> "x" end, __slot__: :inner_block}]
        })

      assert html =~ ~s(data-ui="container")
    end
  end
end
