defmodule OGrupoDeEstudosWeb.CollectionLayoutTest do
  @moduledoc """
  The acervo is a tool, and these are the ways it had stopped acting like one.

  Every case here was measured in a browser at 375px before it was written down.
  The search bar was sliding under the header, two buttons were wired to state
  no template reads, and the families with no description of their own got a
  sentence invented to fill the card with.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    category = insert(:category, label: "Bases", color: "#8a5a2b")
    section = insert(:section, category: category, title: "Bases", description: nil)

    step =
      insert(:step,
        section: section,
        category: category,
        code: "BF",
        name: "Base frontal",
        like_count: 1
      )

    %{user: insert(:user), category: category, section: section, step: step}
  end

  defp open(conn, user), do: live(log_in_user(conn, user), ~p"/collection")

  describe "the bar that carries the search" do
    test "offsets from the measured header instead of a guessed number", ctx do
      {:ok, _lv, html} = open(ctx.conn, ctx.user)

      assert html =~ "var(--top-nav-h"

      refute html =~ "top-[48px]",
             "o topo mede 56px para quem estuda e 76px para quem administra"
    end

    test "the search field is tall enough to hit and large enough not to zoom", ctx do
      {:ok, _lv, html} = open(ctx.conn, ctx.user)

      [_, field] = String.split(html, ~s(name="term"), parts: 2)
      opening_tag = field |> String.split(">", parts: 2) |> hd()

      assert opening_tag =~ "min-h-11"
      assert opening_tag =~ "text-base", "abaixo de 16px o Safari do iPhone dá zoom sozinho"
    end
  end

  describe "controls that do something" do
    test "the pair of buttons wired to state nobody renders is gone", ctx do
      {:ok, _lv, html} = open(ctx.conn, ctx.user)

      refute html =~ "expandir"
      refute html =~ "phx-click=\"expand_all\""
      refute html =~ "phx-click=\"collapse_all\""
    end
  end

  describe "what a family says about itself" do
    test "a family with no description of its own stays quiet", ctx do
      {:ok, _lv, html} = open(ctx.conn, ctx.user)

      assert html =~ ctx.section.title
      refute html =~ "Explora os caminhos"
      refute html =~ "Explora os destaques"
    end

    test "the like count is a number, so it never has to agree with a word", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user)

      html = render_click(lv, "enter_section", %{"section_id" => ctx.section.id})

      assert html =~ ctx.step.name
      refute html =~ "1 likes"
      refute html =~ "1 like"
    end
  end

  describe "a family row, which used to be a card" do
    test "carries the family mark, the name and the count", ctx do
      {:ok, _lv, html} = open(ctx.conn, ctx.user)

      assert html =~ ctx.section.title
      assert html =~ "7 passos" or html =~ "1 passos"
      refute html =~ "hover:shadow-[0_16px_40px", "a família deixou de ser card com sombra"
    end

    test "a step row says what you know about the step without four colours", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.user)

      html = render_click(lv, "enter_section", %{"section_id" => ctx.section.id})

      refute html =~ "bg-gold-500/15", "a pill dourada de likes saiu"
      refute html =~ "bg-accent-purple/10", "o círculo roxo de sugestão saiu"
    end
  end

  describe "the step page, where the graph is the navigation" do
    setup ctx do
      target = insert(:step, section: ctx.section, category: ctx.category, code: "BQ")
      insert(:connection, source_step: ctx.step, target_step: target)

      {:ok, _lv, html} = live(log_in_user(ctx.conn, ctx.user), ~p"/steps/#{ctx.step.code}")

      %{html: html}
    end

    test "a connection is tall enough to hit with a thumb", ctx do
      [_, chip] = String.split(ctx.html, ~s(href="/steps/BQ"), parts: 2)
      opening_tag = chip |> String.split(">", parts: 2) |> hd()

      assert opening_tag =~ "min-h-11", "a conexão media 24px de altura"
    end

    test "liking and favouriting are not 20px tall anymore", ctx do
      for event <- ~w(toggle_step_like toggle_step_favorite) do
        [_, button] = String.split(ctx.html, ~s(phx-click="#{event}"), parts: 2)
        opening_tag = button |> String.split(">", parts: 2) |> hd()

        assert opening_tag =~ "min-h-11", "#{event} continua abaixo do alvo de toque"
      end
    end

    test "the suggest pencils carry a hit area larger than the drawing", ctx do
      assert ctx.html =~ "after:size-11",
             "os lápis de sugerir edição mediam 18px, e são a porta da contribuição"
    end
  end
end
