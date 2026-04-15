defmodule OGrupoDeEstudosWeb.StepLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.StepLive

  defp logged_in_conn(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  describe "access" do
    test "redirects to /login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/steps/BF")
    end

    test "redirects to /collection when step does not exist", %{conn: conn} do
      {:error, {:redirect, %{to: "/collection"}}} =
        live(logged_in_conn(conn), ~p"/steps/INEXISTENTE")
    end
  end

  describe "step detail" do
    test "displays step name and code", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, code: "BF", name: "Base Frontal")
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/steps/BF")
      assert html =~ "Base Frontal"
      assert html =~ "BF"
    end

    test "displays technical note when present", %{conn: conn} do
      section = insert(:section)

      insert(:step,
        section: section,
        code: "BF2",
        name: "Base Frontal",
        note: "Descrição mecânica do passo."
      )

      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/steps/BF2")
      assert html =~ "Descrição mecânica do passo."
    end

    test "does not display wip step for regular user", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, code: "WIP1", name: "Passo WIP", wip: true)
      {:error, {:redirect, %{to: "/collection"}}} = live(logged_in_conn(conn), ~p"/steps/WIP1")
    end
  end

  describe "youtube_embed_url/1" do
    test "returns {:youtube, embed_url} for standard youtube.com/watch?v= URL" do
      assert {:youtube, "https://www.youtube.com/embed/dQw4w9WgXcQ"} =
               StepLive.youtube_embed_url("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    end

    test "returns {:youtube, embed_url} for youtu.be short URL" do
      assert {:youtube, "https://www.youtube.com/embed/dQw4w9WgXcQ"} =
               StepLive.youtube_embed_url("https://youtu.be/dQw4w9WgXcQ")
    end

    test "returns {:youtube, embed_url} ignoring extra query params" do
      assert {:youtube, "https://www.youtube.com/embed/dQw4w9WgXcQ"} =
               StepLive.youtube_embed_url(
                 "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s&list=PLabc"
               )
    end

    test "returns :external for non-YouTube URL" do
      assert :external = StepLive.youtube_embed_url("https://vimeo.com/123456")
    end

    test "returns :external for youtube.com without video id" do
      assert :external = StepLive.youtube_embed_url("https://www.youtube.com/watch")
    end

    test "returns :external for nil" do
      assert :external = StepLive.youtube_embed_url(nil)
    end

    test "returns :external for empty youtu.be" do
      assert :external = StepLive.youtube_embed_url("https://youtu.be/")
    end
  end
end
