defmodule OGrupoDeEstudosWeb.NavigationTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.Navigation
  alias Phoenix.LiveView.Socket

  describe "on_mount/4" do
    test ":primary sets nav_mode to :primary" do
      socket = %Socket{assigns: %{__changed__: %{}}}
      {:cont, result} = Navigation.on_mount(:primary, %{}, %{}, socket)

      assert result.assigns.nav_mode == :primary
    end

    test ":detail sets nav_mode to :detail" do
      socket = %Socket{assigns: %{__changed__: %{}}}
      {:cont, result} = Navigation.on_mount(:detail, %{}, %{}, socket)

      assert result.assigns.nav_mode == :detail
    end
  end
end
