defmodule OGrupoDeEstudosWeb.AppShellTest do
  @moduledoc """
  The app around the page: tab bar, top bar and one way back.

  A workshop, a programme and a step are places, not tasks: you got there by
  tapping a card in a list. Taking the whole app away says "you left the app and
  opened a web page", and it also takes the bell and the profile with it. Only a
  form you must finish or cancel earns a bare screen.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Workshops

  setup do
    teacher = insert(:user, is_teacher: true)
    workshop = insert(:workshop, organizer: teacher, price_cents: 5000)
    program = insert(:workshop_program, owner: teacher)
    step = insert(:step, code: "IV", name: "Inversão")

    %{teacher: teacher, workshop: workshop, program: program, step: step}
  end

  defp tab_bar, do: ~s(data-ui="bottom-nav")

  # The page has other links to the same paths (the breadcrumb, for one), so the
  # search starts after the tab bar opens.
  defp active_tab(html, path) do
    with [_, bar] <- String.split(html, tab_bar(), parts: 2),
         [tag] <- Regex.run(~r/<a href="#{Regex.escape(path)}"[^>]*>/, bar) do
      tag =~ ~s(data-active="true")
    else
      _no_tab -> false
    end
  end

  describe "the places you reach by tapping a card" do
    test "the workshop keeps the tab bar", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.teacher), ~p"/workshops/#{ctx.workshop.slug}")

      assert html =~ tab_bar()
    end

    test "the programme keeps the tab bar", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.teacher), ~p"/programs/#{ctx.program.slug}")

      assert html =~ tab_bar()
    end

    test "the enrolment panel keeps the tab bar", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.teacher), ~p"/workshops/#{ctx.workshop.slug}/manage")

      assert html =~ tab_bar()
    end

    test "the step keeps the tab bar", ctx do
      {:ok, _lv, html} = live(log_in_user(ctx.conn, ctx.teacher), ~p"/steps/#{ctx.step.code}")

      assert html =~ tab_bar()
    end
  end

  describe "which tab lights up" do
    test "a workshop lives under Estudos, and the tab says so", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.teacher), ~p"/workshops/#{ctx.workshop.slug}")

      assert active_tab(html, "/study")
    end

    test "a step lives under Acervo", ctx do
      {:ok, _lv, html} = live(log_in_user(ctx.conn, ctx.teacher), ~p"/steps/#{ctx.step.code}")

      assert active_tab(html, "/collection")
    end
  end

  describe "whoever opened the link with no account" do
    test "gets no tab bar on the workshop, since there is no app to go back into", ctx do
      {:ok, _lv, html} = live(ctx.conn, ~p"/workshops/#{ctx.workshop.slug}")

      refute html =~ tab_bar()
    end

    test "gets no tab bar on the programme either", ctx do
      {:ok, _lv, html} = live(ctx.conn, ~p"/programs/#{ctx.program.slug}")

      refute html =~ tab_bar()
    end
  end

  describe "one way back, and it says where it goes" do
    test "the workshop drops the generic back of the bare header", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.teacher), ~p"/workshops/#{ctx.workshop.slug}")

      refute html =~ ~s(data-ui="back-button")
      assert html =~ "Workshops"
    end

    test "the programme gained the way back it never had", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.teacher), ~p"/programs/#{ctx.program.slug}")

      assert html =~ ~s(href="/study/workshops")
    end
  end

  describe "the buttons the standard top bar puts on the page" do
    test "switching the theme does not take the workshop down", ctx do
      {:ok, lv, _} = live(log_in_user(ctx.conn, ctx.teacher), ~p"/workshops/#{ctx.workshop.slug}")

      render_click(lv, "toggle_dark_mode", %{})

      assert render(lv) =~ ctx.workshop.title
    end

    test "switching the theme does not take the programme down", ctx do
      {:ok, lv, _} = live(log_in_user(ctx.conn, ctx.teacher), ~p"/programs/#{ctx.program.slug}")

      render_click(lv, "toggle_dark_mode", %{})

      assert render(lv) =~ ctx.program.title
    end
  end

  describe "a task, not a place" do
    test "creating a workshop still gets a bare screen", ctx do
      {:ok, _lv, html} = live(log_in_user(ctx.conn, ctx.teacher), ~p"/study/workshops/new")

      refute html =~ tab_bar()
    end
  end

  describe "the tab bar never sits on top of the content" do
    test "the workshop reserves room for it", ctx do
      {:ok, _} = Workshops.enroll(ctx.workshop, insert(:user))

      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.teacher), ~p"/workshops/#{ctx.workshop.slug}")

      assert html =~ "pb-24"
    end
  end
end
