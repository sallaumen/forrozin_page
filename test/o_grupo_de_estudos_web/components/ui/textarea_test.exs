defmodule OGrupoDeEstudosWeb.UI.TextareaTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.Textarea

  describe "textarea/1" do
    test "renders a labeled textarea with for/id association" do
      html = render_component(&Textarea.textarea/1, %{
        id: "step-note",
        name: "step[note]",
        label: "Descrição técnica"
      })
      assert html =~ ~s(<label for="step-note")
      assert html =~ "<textarea"
      assert html =~ ~s(id="step-note")
      assert html =~ ~s(name="step[note]")
    end

    test "default rows is 4" do
      html = render_component(&Textarea.textarea/1, %{id: "x", name: "x", label: "X"})
      assert html =~ ~s(rows="4")
    end

    test "custom rows" do
      html = render_component(&Textarea.textarea/1, %{
        id: "x", name: "x", label: "X", rows: 8
      })
      assert html =~ ~s(rows="8")
    end

    test "renders value as inner content" do
      html = render_component(&Textarea.textarea/1, %{
        id: "x", name: "x", label: "X", value: "Linha 1\nLinha 2"
      })
      assert html =~ "Linha 1"
      assert html =~ "Linha 2"
    end

    test "error state sets aria-invalid" do
      html = render_component(&Textarea.textarea/1, %{
        id: "x", name: "x", label: "X", errors: ["too long"]
      })
      assert html =~ ~s(aria-invalid="true")
      assert html =~ "too long"
    end

    test "hint is announced via aria-describedby" do
      html = render_component(&Textarea.textarea/1, %{
        id: "x", name: "x", label: "X", hint: "markdown ok"
      })
      assert html =~ "markdown ok"
      assert html =~ ~s(aria-describedby="x-hint")
    end
  end
end
