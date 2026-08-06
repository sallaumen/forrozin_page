defmodule OGrupoDeEstudosWeb.StudyBackNavigationTest do
  @moduledoc """
  The phone's back button across the study area and the pages it leads to.

  Same disease as the acervo had: a tab was an assign changed by a click, so the
  browser was handed no history entry and the back gesture left the site instead
  of stepping back one tab. These pages have a second symptom on top of that,
  because the tab does not survive going into a workshop, a sequence or a step
  and coming back: that is a full remount, and a remount keeps only what the
  address carries.

  The params are asserted in alphabetical order because `config/test.exs` sets
  `sort_verified_routes_query_params` so route assertions do not depend on the
  order a keyword list happens to be written in.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "the tabs of the study area" do
    setup ctx do
      teacher = insert(:user, is_teacher: true)
      %{conn: log_in_user(ctx.conn, teacher), teacher: teacher}
    end

    test "each tab is a link with an address of its own", ctx do
      {:ok, lv, _html} = live(ctx.conn, ~p"/study")

      assert has_element?(lv, ~s{a[href="/study?tab=teachers"]})
      assert has_element?(lv, ~s{a[href="/study?tab=students"]})
      assert has_element?(lv, ~s{a[href="/study"]}, "Meu estudo")
    end

    test "a tab opens straight from its address", ctx do
      {:ok, lv, _html} = live(ctx.conn, ~p"/study?tab=students")

      assert has_element?(lv, ~s{[role="tab"][aria-selected="true"]}, "Alunos")
    end

    test "going back returns to the tab before it instead of leaving", ctx do
      {:ok, lv, _html} = live(ctx.conn, ~p"/study?tab=teachers")

      html = render_patch(lv, ~p"/study")

      assert html =~ "O que rolou na prática?"
    end

    test "a tab nobody has falls back to the diary", ctx do
      {:ok, _lv, html} = live(ctx.conn, ~p"/study?tab=inventada")

      assert html =~ "O que rolou na prática?"
    end

    test "someone who does not teach cannot land on the students tab", ctx do
      student = insert(:user, is_teacher: false)

      {:ok, _lv, html} = ctx.conn |> log_in_user(student) |> live(~p"/study?tab=students")

      assert html =~ "O que rolou na prática?"
      refute html =~ "Meus alunos"
    end

    test "from the workshops page the tabs point at the tab, not all at the diary", ctx do
      {:ok, lv, _html} = live(ctx.conn, ~p"/study/workshops")

      assert has_element?(lv, ~s{a[href="/study?tab=teachers"]})
      assert has_element?(lv, ~s{a[href="/study?tab=students"]})
    end
  end

  describe "the period filter of the agenda" do
    setup ctx do
      %{conn: log_in_user(ctx.conn, insert(:user))}
    end

    test "the period is in the address, so it survives opening a workshop", ctx do
      {:ok, lv, _html} = live(ctx.conn, ~p"/study/workshops")

      assert has_element?(lv, ~s{a[href="/study/workshops?period=past"]})
    end

    test "the agenda opens straight on the chosen period", ctx do
      {:ok, lv, _html} = live(ctx.conn, ~p"/study/workshops?period=past")

      assert has_element?(lv, ~s{a[href="/study/workshops?period=past"][aria-current="true"]})
    end

    test "choosing a period is not a step to walk back through", ctx do
      {:ok, lv, _html} = live(ctx.conn, ~p"/study/workshops")

      assert has_element?(
               lv,
               ~s{a[href="/study/workshops?period=month"][data-phx-link-state="replace"]}
             )
    end

    test "a period nobody offers falls back to what is coming", ctx do
      {:ok, lv, _html} = live(ctx.conn, ~p"/study/workshops?period=drop_table")

      assert has_element?(lv, ~s{a[href="/study/workshops"][aria-current="true"]})
    end
  end

  describe "the tabs of the sequences page" do
    setup ctx do
      %{conn: log_in_user(ctx.conn, insert(:user))}
    end

    test "minhas sequências has an address of its own", ctx do
      {:ok, lv, _html} = live(ctx.conn, ~p"/sequence")

      assert has_element?(lv, ~s{a[href="/sequence?tab=mine"]})
    end

    test "the tab opens straight from its address", ctx do
      {:ok, lv, _html} = live(ctx.conn, ~p"/sequence?tab=mine")

      assert has_element?(lv, ~s{a[href="/sequence?tab=mine"][aria-selected="true"]})
    end

    test "going back returns to the community tab", ctx do
      {:ok, lv, _html} = live(ctx.conn, ~p"/sequence?tab=mine")

      render_patch(lv, ~p"/sequence")

      assert has_element?(lv, ~s{a[href="/sequence"][aria-selected="true"]})
    end
  end

  describe "the tabs of a profile" do
    setup ctx do
      %{conn: log_in_user(ctx.conn, insert(:user)), profile: insert(:user)}
    end

    test "each tab is a link under the profile's own address", ctx do
      {:ok, lv, _html} = live(ctx.conn, ~p"/users/#{ctx.profile.username}")

      base = "/users/#{ctx.profile.username}"

      assert has_element?(lv, ~s{a[href="#{base}?tab=favorites"]})
      assert has_element?(lv, ~s{a[href="#{base}?tab=contributions"]})
      assert has_element?(lv, ~s{a[href="#{base}?tab=sequences"]})
    end

    test "a tab opens straight from its address", ctx do
      {:ok, _lv, html} =
        live(ctx.conn, ~p"/users/#{ctx.profile.username}?tab=contributions")

      assert html =~ "Contribuições"
    end

    test "the favourites sub-tab is a place too", ctx do
      {:ok, lv, _html} = live(ctx.conn, ~p"/users/#{ctx.profile.username}?tab=favorites")

      base = "/users/#{ctx.profile.username}"

      assert has_element?(lv, ~s{a[href="#{base}?sub=sequences&tab=favorites"]})
    end

    test "going back from a sub-tab lands on the tab, not outside the profile", ctx do
      base = ~p"/users/#{ctx.profile.username}"

      {:ok, lv, _html} = live(ctx.conn, "#{base}?sub=sequences&tab=favorites")

      html = render_patch(lv, "#{base}?tab=favorites")

      assert html =~ "Favoritos"
    end

    test "a tab nobody has falls back to the steps", ctx do
      {:ok, _lv, html} = live(ctx.conn, ~p"/users/#{ctx.profile.username}?tab=inventada")

      assert html =~ "Passos"
    end
  end
end
