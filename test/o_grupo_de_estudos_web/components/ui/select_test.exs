defmodule OGrupoDeEstudosWeb.UI.SelectTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.Select

  describe "select/1" do
    test "renders labeled select with options" do
      html =
        render_component(&Select.select/1, %{
          id: "category",
          name: "step[category]",
          label: "Categoria",
          options: [{"Sacadas", "sacadas"}, {"Travas", "travas"}]
        })

      assert html =~ ~s(<label for="category")
      assert html =~ "<select"
      assert html =~ ~s(id="category")
      assert html =~ ~s(name="step[category]")
      assert html =~ ~s(value="sacadas")
      assert html =~ "Sacadas"
      assert html =~ ~s(value="travas")
      assert html =~ "Travas"
    end

    test "value matches an option to select it" do
      html =
        render_component(&Select.select/1, %{
          id: "x",
          name: "x",
          label: "X",
          options: [{"A", "a"}, {"B", "b"}],
          value: "b"
        })

      assert html =~ ~r/<option[^>]*value="b"[^>]*selected/
    end

    test "placeholder option when :prompt is set" do
      html =
        render_component(&Select.select/1, %{
          id: "x",
          name: "x",
          label: "X",
          prompt: "Selecione...",
          options: [{"A", "a"}]
        })

      assert html =~ "Selecione..."
    end

    test "error state sets aria-invalid" do
      html =
        render_component(&Select.select/1, %{
          id: "x",
          name: "x",
          label: "X",
          options: [{"A", "a"}],
          errors: ["obrigatório"]
        })

      assert html =~ ~s(aria-invalid="true")
    end
  end
end
