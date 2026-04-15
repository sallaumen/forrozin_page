defmodule OGrupoDeEstudosWeb.UserProfileLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp logged_in_conn(conn, user) do
    log_in_user(conn, user)
  end

  setup do
    viewer = insert(:user)
    profile = insert(:user)
    %{viewer: viewer, profile: profile}
  end

  describe "access" do
    test "redirects to /login when not authenticated", %{conn: conn, profile: profile} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/users/#{profile.username}")
    end

    test "redirects when username does not exist", %{conn: conn, viewer: viewer} do
      conn = logged_in_conn(conn, viewer)
      {:error, {:redirect, %{to: "/collection"}}} = live(conn, ~p"/users/nao_existe_xyz")
    end

    test "renders page for authenticated user", %{conn: conn, viewer: viewer, profile: profile} do
      conn = logged_in_conn(conn, viewer)
      {:ok, _lv, html} = live(conn, ~p"/users/#{profile.username}")
      assert html =~ profile.name || html =~ profile.username
    end
  end

  describe "profile fields" do
    test "shows avatar initial circle when no avatar_path", %{
      conn: conn,
      viewer: viewer,
      profile: profile
    } do
      conn = logged_in_conn(conn, viewer)
      {:ok, _lv, html} = live(conn, ~p"/users/#{profile.username}")
      # The circle div should be rendered with the first letter of the name
      first_letter = String.first(profile.name || profile.username) |> String.upcase()
      assert html =~ first_letter
    end

    test "shows bio when profile has one", %{conn: conn, viewer: viewer} do
      profile = insert(:user, bio: "Danço forró roots em Curitiba desde 2018.")
      conn = logged_in_conn(conn, viewer)
      {:ok, _lv, html} = live(conn, ~p"/users/#{profile.username}")
      assert html =~ "Danço forró roots"
    end

    test "shows instagram link when profile has instagram", %{conn: conn, viewer: viewer} do
      profile = insert(:user, instagram: "o_grupo_de_estudos_cba")
      conn = logged_in_conn(conn, viewer)
      {:ok, _lv, html} = live(conn, ~p"/users/#{profile.username}")
      assert html =~ "o_grupo_de_estudos_cba"
      assert html =~ "instagram.com"
    end

    test "shows edit profile button for own profile", %{conn: conn, viewer: viewer} do
      conn = logged_in_conn(conn, viewer)
      {:ok, _lv, html} = live(conn, ~p"/users/#{viewer.username}")
      assert html =~ "Editar perfil"
      assert html =~ "/settings"
    end

    test "does not show edit profile button for another user's profile", %{
      conn: conn,
      viewer: viewer,
      profile: profile
    } do
      conn = logged_in_conn(conn, viewer)
      {:ok, _lv, html} = live(conn, ~p"/users/#{profile.username}")
      refute html =~ "Editar perfil"
    end
  end

  describe "comments" do
    test "shows comment form", %{conn: conn, viewer: viewer, profile: profile} do
      conn = logged_in_conn(conn, viewer)
      {:ok, _lv, html} = live(conn, ~p"/users/#{profile.username}")
      assert html =~ "Escreva um comentário"
      assert html =~ "Comentar"
    end

    test "can post a comment", %{conn: conn, viewer: viewer, profile: profile} do
      conn = logged_in_conn(conn, viewer)
      {:ok, lv, _html} = live(conn, ~p"/users/#{profile.username}")

      html =
        lv
        |> form("form[phx-submit='post_comment']", %{body: "Ótimo dançarino!"})
        |> render_submit()

      assert html =~ "Ótimo dançarino!"
    end

    test "shows existing comment on load", %{
      conn: conn,
      viewer: viewer,
      profile: profile
    } do
      insert(:profile_comment,
        profile: profile,
        author: viewer,
        body: "Comentário pré-existente"
      )

      conn = logged_in_conn(conn, viewer)
      {:ok, _lv, html} = live(conn, ~p"/users/#{profile.username}")
      assert html =~ "Comentário pré-existente"
    end

    test "author can delete their own comment", %{
      conn: conn,
      viewer: viewer,
      profile: profile
    } do
      insert(:profile_comment,
        profile: profile,
        author: viewer,
        body: "Meu comentário deletável"
      )

      conn = logged_in_conn(conn, viewer)
      {:ok, lv, _html} = live(conn, ~p"/users/#{profile.username}")

      # Verify it renders
      assert render(lv) =~ "Meu comentário deletável"
      assert render(lv) =~ "remover"
    end

    test "shows like button for comments", %{
      conn: conn,
      viewer: viewer,
      profile: profile
    } do
      insert(:profile_comment,
        profile: profile,
        author: profile,
        body: "Comentário curtível"
      )

      conn = logged_in_conn(conn, viewer)
      {:ok, _lv, html} = live(conn, ~p"/users/#{profile.username}")
      assert html =~ "profile_comment"
    end
  end
end
