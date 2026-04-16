defmodule OGrupoDeEstudosWeb.UI.SkeletonTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.Skeleton

  describe "skeleton/1" do
    test "renders a decorative pulse block" do
      html = render_component(&Skeleton.skeleton/1, %{})

      assert html =~ ~s(data-ui="skeleton")
      assert html =~ "animate-pulse"
    end

    test "has aria-hidden=true (decorative, not read by screen readers)" do
      html = render_component(&Skeleton.skeleton/1, %{})

      assert html =~ ~s(aria-hidden="true")
    end

    test "accepts custom class for sizing" do
      html = render_component(&Skeleton.skeleton/1, %{class: "h-12 w-full"})

      assert html =~ "h-12 w-full"
    end
  end
end
