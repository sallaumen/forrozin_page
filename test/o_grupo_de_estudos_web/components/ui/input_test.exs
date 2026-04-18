defmodule OGrupoDeEstudosWeb.UI.InputTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.Input

  describe "input/1" do
    test "renders a labeled input with for/id association" do
      html =
        render_component(&Input.input/1, %{
          id: "user-email",
          name: "user[email]",
          label: "Email"
        })

      assert html =~ ~s(<label for="user-email")
      assert html =~ ~s(id="user-email")
      assert html =~ ~s(name="user[email]")
      assert html =~ "Email"
    end

    test "accepts value" do
      html =
        render_component(&Input.input/1, %{
          id: "x",
          name: "x",
          label: "X",
          value: "hello"
        })

      assert html =~ ~s(value="hello")
    end

    test "defaults to type=text" do
      html = render_component(&Input.input/1, %{id: "x", name: "x", label: "X"})
      assert html =~ ~s(type="text")
    end

    test "supports type=email, password, url, number" do
      for type <- ~w(email password url number) do
        html =
          render_component(&Input.input/1, %{
            id: "x",
            name: "x",
            label: "X",
            type: type
          })

        assert html =~ ~s(type="#{type}")
      end
    end

    test "renders hint when provided" do
      html =
        render_component(&Input.input/1, %{
          id: "x",
          name: "x",
          label: "X",
          hint: "max 40 chars"
        })

      assert html =~ "max 40 chars"
      assert html =~ ~s(aria-describedby="x-hint")
    end

    test "renders error and sets aria-invalid when errors present" do
      html =
        render_component(&Input.input/1, %{
          id: "x",
          name: "x",
          label: "X",
          errors: ["obrigatório"]
        })

      assert html =~ "obrigatório"
      assert html =~ ~s(aria-invalid="true")
    end

    test "no errors means no aria-invalid" do
      html = render_component(&Input.input/1, %{id: "x", name: "x", label: "X"})
      refute html =~ "aria-invalid"
    end
  end
end
