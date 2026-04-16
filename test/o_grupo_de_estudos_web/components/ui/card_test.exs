defmodule OGrupoDeEstudosWeb.UI.CardTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.Card

  describe "card/1" do
    test "renders content inside a card wrapper" do
      html =
        render_component(&Card.card/1, %{
          inner_block: [%{inner_block: fn _, _ -> "card body" end, __slot__: :inner_block}]
        })

      assert html =~ "card body"
    end

    test "has data-ui attribute" do
      html =
        render_component(&Card.card/1, %{
          inner_block: [%{inner_block: fn _, _ -> "x" end, __slot__: :inner_block}]
        })

      assert html =~ ~s(data-ui="card")
    end

    test "accepts custom class" do
      html =
        render_component(&Card.card/1, %{
          class: "my-custom",
          inner_block: [%{inner_block: fn _, _ -> "x" end, __slot__: :inner_block}]
        })

      assert html =~ "my-custom"
    end

    test "passes through HTML attributes (e.g., id)" do
      html =
        render_component(&Card.card/1, %{
          id: "step-card-BF",
          inner_block: [%{inner_block: fn _, _ -> "x" end, __slot__: :inner_block}]
        })

      assert html =~ ~s(id="step-card-BF")
    end
  end
end
