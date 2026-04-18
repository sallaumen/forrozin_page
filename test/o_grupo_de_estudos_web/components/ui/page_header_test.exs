defmodule OGrupoDeEstudosWeb.UI.PageHeaderTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.PageHeader

  describe "page_header/1" do
    test "renders title as h1" do
      html = render_component(&PageHeader.page_header/1, %{title: "Acervo"})
      assert html =~ "<h1"
      assert html =~ "Acervo"
    end

    test "data-ui attribute present" do
      html = render_component(&PageHeader.page_header/1, %{title: "x"})
      assert html =~ ~s(data-ui="page-header")
    end

    test "breadcrumb slot renders content above title" do
      html =
        render_component(&PageHeader.page_header/1, %{
          title: "BF",
          breadcrumb: [
            %{inner_block: fn _, _ -> ~s(<span>acervo › BF</span>) end, __slot__: :breadcrumb}
          ]
        })

      assert html =~ "acervo"
      bread_pos = html |> :binary.match("acervo") |> elem(0)
      h1_pos = html |> :binary.match("<h1") |> elem(0)
      assert bread_pos < h1_pos, "breadcrumb should render before h1"
    end

    test "actions slot renders content beside title" do
      html =
        render_component(&PageHeader.page_header/1, %{
          title: "BF",
          actions: [
            %{inner_block: fn _, _ -> ~s(<button>Salvar</button>) end, __slot__: :actions}
          ]
        })

      assert html =~ "Salvar"
    end
  end
end
