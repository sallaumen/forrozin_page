defmodule OGrupoDeEstudosWeb.UI.BottomSheetTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.BottomSheet

  defp slot(text), do: [%{inner_block: fn _, _ -> text end, __slot__: :inner_block}]

  describe "bottom_sheet/1" do
    test "renders as <dialog> element" do
      html = render_component(&BottomSheet.bottom_sheet/1, %{
        id: "filter-sheet",
        inner_block: slot("filter content")
      })
      assert html =~ "<dialog"
      assert html =~ "filter content"
    end

    test "id attribute set correctly" do
      html = render_component(&BottomSheet.bottom_sheet/1, %{
        id: "my-sheet",
        inner_block: slot("x")
      })
      assert html =~ ~s(id="my-sheet")
    end

    test "has data-ui attribute and phx-hook for JS control" do
      html = render_component(&BottomSheet.bottom_sheet/1, %{
        id: "x",
        inner_block: slot("x")
      })
      assert html =~ ~s(data-ui="bottom-sheet")
      assert html =~ ~s(phx-hook="BottomSheet")
    end

    test "includes optional title as heading" do
      html = render_component(&BottomSheet.bottom_sheet/1, %{
        id: "x",
        title: "Filtros",
        inner_block: slot("x")
      })
      assert html =~ "Filtros"
      assert html =~ "<h2"
    end

    test "close button has aria-label" do
      html = render_component(&BottomSheet.bottom_sheet/1, %{
        id: "x",
        inner_block: slot("x")
      })
      assert html =~ "aria-label"
    end

    test "dialog element present" do
      html = render_component(&BottomSheet.bottom_sheet/1, %{
        id: "x",
        inner_block: slot("x")
      })
      assert html =~ "<dialog"
    end
  end
end
