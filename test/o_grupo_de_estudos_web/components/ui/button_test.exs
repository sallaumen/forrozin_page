defmodule OGrupoDeEstudosWeb.UI.ButtonTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.Button

  defp slot(text), do: [%{inner_block: fn _, _ -> text end, __slot__: :inner_block}]

  describe "button/1" do
    test "renders as <button> by default with type=button" do
      html = render_component(&Button.button/1, %{inner_block: slot("Click me")})
      assert html =~ "Click me"
      assert html =~ ~s(<button)
      assert html =~ ~s(type="button")
    end

    test "renders with default variant=primary and size=md" do
      html = render_component(&Button.button/1, %{inner_block: slot("x")})
      assert html =~ ~s(data-variant="primary")
      assert html =~ ~s(data-size="md")
    end

    test "renders each variant" do
      for variant <- [:primary, :ghost, :danger] do
        html = render_component(&Button.button/1, %{variant: variant, inner_block: slot("x")})
        assert html =~ ~s(data-variant="#{variant}")
      end
    end

    test "renders each size" do
      for size <- [:sm, :md, :lg] do
        html = render_component(&Button.button/1, %{size: size, inner_block: slot("x")})
        assert html =~ ~s(data-size="#{size}")
      end
    end

    test "type=submit renders type=\"submit\"" do
      html = render_component(&Button.button/1, %{type: "submit", inner_block: slot("Save")})
      assert html =~ ~s(type="submit")
    end

    test "loading state disables the button and shows spinner" do
      html = render_component(&Button.button/1, %{loading: true, inner_block: slot("Saving")})
      assert html =~ "disabled"
      assert html =~ "animate-spin"
    end

    test "passes through phx-click" do
      html = render_component(&Button.button/1, %{"phx-click": "save", inner_block: slot("Save")})
      assert html =~ ~s(phx-click="save")
    end

    test "data-confirm attribute passes through" do
      html =
        render_component(&Button.button/1, %{
          "data-confirm": "Tem certeza?",
          inner_block: slot("Delete")
        })

      assert html =~ ~s(data-confirm="Tem certeza?")
    end
  end
end
