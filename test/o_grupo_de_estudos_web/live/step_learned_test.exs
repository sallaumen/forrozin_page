defmodule OGrupoDeEstudosWeb.StepLearnedTest do
  @moduledoc """
  The learn gesture lives in `step_detail`, shared by the step page and the
  collection drawer, instead of only inside the graph.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Engagement

  setup do
    %{step: insert(:step, code: "IV", name: "Inversão base"), user: insert(:user)}
  end

  describe "on the step page" do
    test "offers the mark gesture", ctx do
      {:ok, _lv, html} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      assert html =~ "Já sei este passo"
    end

    test "marking records the learning", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      html = render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})

      assert Engagement.learned?(ctx.user.id, ctx.step.id)
      assert html =~ "Você já sabe"
    end

    test "clicking again unmarks it, so the gesture is reversible", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})
      render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})

      refute Engagement.learned?(ctx.user.id, ctx.step.id)
    end

    test "who already knows it sees the state on open, without clicking", ctx do
      {:ok, :learned} = Engagement.toggle_learned(ctx.user.id, ctx.step.id)

      {:ok, _lv, html} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      assert html =~ "Você já sabe"
    end
  end

  describe "in the collection, through the drawer" do
    test "same gesture, same component", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.user), ~p"/collection")

      html = render_click(lv, "open_step", %{"code" => ctx.step.code})
      assert html =~ "Já sei este passo"

      render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})
      assert Engagement.learned?(ctx.user.id, ctx.step.id)
    end
  end

  describe "the side effect that has to show on screen" do
    test "marking as learned also favorites, and the favorite button follows", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      html = render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})

      assert Engagement.favorited?(ctx.user.id, "step", ctx.step.id)
      assert html =~ "Favoritado"
    end

    test "unmarking as learned does not unfavorite", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})
      render_click(lv, "toggle_step_learned", %{"code" => ctx.step.code})

      assert Engagement.favorited?(ctx.user.id, "step", ctx.step.id)
    end
  end

  describe "unknown code" do
    test "does not crash the page", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.user), ~p"/steps/#{ctx.step.code}")

      assert render_click(lv, "toggle_step_learned", %{"code" => "NAO-EXISTE"})
    end
  end
end
