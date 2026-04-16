defmodule OGrupoDeEstudosWeb.UI.BackButtonTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.BackButton

  describe "back_button/1" do
    test "renders a button with phx-hook=\"BackButton\"" do
      html = render_component(&BackButton.back_button/1, %{})
      assert html =~ "<button"
      assert html =~ ~s(phx-hook="BackButton")
    end

    test "data-ui attribute present" do
      html = render_component(&BackButton.back_button/1, %{})
      assert html =~ ~s(data-ui="back-button")
    end

    test "aria-label defaults to Voltar" do
      html = render_component(&BackButton.back_button/1, %{})
      assert html =~ ~s(aria-label="Voltar")
    end

    test "custom aria-label via :label attr" do
      html = render_component(&BackButton.back_button/1, %{label: "Retornar"})
      assert html =~ ~s(aria-label="Retornar")
    end

    test "fallback URL via :fallback attr renders as data-fallback" do
      html = render_component(&BackButton.back_button/1, %{fallback: "/community"})
      assert html =~ ~s(data-fallback="/community")
    end

    test "default fallback is /collection" do
      html = render_component(&BackButton.back_button/1, %{})
      assert html =~ ~s(data-fallback="/collection")
    end

    test "unique id required for hook (defaults to back-button)" do
      html = render_component(&BackButton.back_button/1, %{})
      assert html =~ ~s(id="back-button")
    end
  end
end
