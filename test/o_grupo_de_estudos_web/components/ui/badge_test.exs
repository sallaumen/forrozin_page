defmodule OGrupoDeEstudosWeb.UI.BadgeTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.Badge

  describe "badge/1" do
    test "renders with default variant (neutral)" do
      html =
        render_component(&Badge.badge/1, %{
          inner_block: [%{inner_block: fn _, _ -> "Sacadas" end, __slot__: :inner_block}]
        })

      assert html =~ "Sacadas"
      assert html =~ ~s(data-variant="neutral")
    end

    test "renders each variant" do
      for variant <- [:neutral, :info, :success, :warning, :danger, :accent] do
        html =
          render_component(&Badge.badge/1, %{
            variant: variant,
            inner_block: [%{inner_block: fn _, _ -> "x" end, __slot__: :inner_block}]
          })

        assert html =~ ~s(data-variant="#{variant}"),
               "expected data-variant=\"#{variant}\" in output"
      end
    end

    test "passes through valid variant" do
      html =
        render_component(&Badge.badge/1, %{
          variant: :info,
          inner_block: [%{inner_block: fn _, _ -> "x" end, __slot__: :inner_block}]
        })

      assert html =~ "x"
    end
  end
end
