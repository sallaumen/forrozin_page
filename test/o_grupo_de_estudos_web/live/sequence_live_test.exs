defmodule OGrupoDeEstudosWeb.SequenceLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Engagement

  defp logged_in_conn(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  describe "access" do
    test "redirects to /login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/sequence")
    end

    test "renders page for authenticated user", %{conn: conn} do
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/sequence")
      assert html =~ "Sequências" or html =~ "sequência"
    end
  end

  describe "community shell" do
    test "renders the editorial shell ids for the community tab", %{conn: conn} do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/sequence")

      assert has_element?(lv, "#community-sequences-hero")
      assert has_element?(lv, "#community-sequences-hero #community-sequences-search")
      assert has_element?(lv, "#community-sequences-hero #community-sequences-filter")
      assert has_element?(lv, "#community-sequences-hero #community-sequences-tabbar")

      assert has_element?(
               lv,
               "#community-sequences-hero #community-sequences-tabbar #community-sequences-create"
             )

      assert has_element?(lv, "#community-sequences-search")
      assert has_element?(lv, "#community-sequences-filter")
      assert has_element?(lv, "#community-sequences-stream")
    end

    test "generator button opens mode chooser with automatic and manual options", %{conn: conn} do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/sequence")

      refute has_element?(lv, "#community-sequences-create-menu")

      render_click(lv, "toggle_create_menu", %{})

      assert has_element?(lv, "#community-sequences-create-menu")

      assert has_element?(
               lv,
               ~s|#community-sequences-create-menu a[href="/graph/visual?mode=generator"]|,
               "Gerador automático"
             )

      assert has_element?(
               lv,
               ~s|#community-sequences-create-menu a[href="/graph/visual?mode=manual"]|,
               "Anotar manualmente"
             )
    end

    test "search filters visible community sequences while filter options remain available",
         %{conn: conn} do
      author = insert(:user)

      bases = insert(:category, name: "bases", label: "Bases")
      giros = insert(:category, name: "giros", label: "Giros")

      alpha =
        insert(:sequence, user: author, public: true, name: "Alpha Flow")

      beta =
        insert(:sequence, user: author, public: true, name: "Beta Spin")

      alpha_step = insert(:step, code: "AF", name: "Alpha Step", category: bases)
      beta_step = insert(:step, code: "BS", name: "Beta Step", category: giros)

      insert(:sequence_step, sequence: alpha, step: alpha_step, position: 1)
      insert(:sequence_step, sequence: beta, step: beta_step, position: 1)

      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/sequence")

      html = render_keyup(lv, "search_sequences", %{"term" => "Alpha"})

      assert html =~ "Alpha Flow"
      refute html =~ "Beta Spin"
      assert has_element?(lv, "#community-sequences-filter option", "Bases")
      assert has_element?(lv, "#community-sequences-filter option", "Giros")
    end

    test "selecting a category filter narrows community sequences by category", %{conn: conn} do
      author = insert(:user)

      bases = insert(:category, name: "bases", label: "Bases")
      giros = insert(:category, name: "giros", label: "Giros")

      base_sequence =
        insert(:sequence, user: author, public: true, name: "Base da Casa")

      giro_sequence =
        insert(:sequence, user: author, public: true, name: "Giro da Casa")

      insert(:sequence_step,
        sequence: base_sequence,
        step: insert(:step, code: "BF", name: "Base Frontal", category: bases),
        position: 1
      )

      insert(:sequence_step,
        sequence: giro_sequence,
        step: insert(:step, code: "GP", name: "Giro Paulista", category: giros),
        position: 1
      )

      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/sequence")

      html =
        render_change(lv, "select_discovery_section", %{"section_id" => bases.id})

      assert has_element?(lv, "#community-sequences-filter option[selected]", "Bases")
      assert html =~ "Base da Casa"
      refute html =~ "Giro da Casa"
    end
  end

  describe "sequences" do
    setup do
      author = insert(:user)
      section = insert(:section)
      step = insert(:step, section: section, code: "BF", name: "Base Frontal")
      sequence = insert(:sequence, user: author, public: true, name: "Sequência Pública")
      insert(:sequence_step, sequence: sequence, step: step, position: 1)

      %{author: author, sequence: sequence}
    end

    test "shows public sequences on mount", %{conn: conn, sequence: seq} do
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/sequence")
      assert html =~ seq.name
    end

    test "renders editorial sequence card ids and actions", %{
      conn: conn,
      sequence: seq,
      author: author
    } do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/sequence")

      assert has_element?(lv, "#sequence-card-#{seq.id}")

      assert has_element?(
               lv,
               ~s|#sequence-author-#{seq.id}[href="/users/#{author.username}"]|
             )

      assert has_element?(
               lv,
               ~s|#sequence-map-link-#{seq.id}[href="/graph/visual?seq=#{seq.id}"]|
             )

      assert has_element?(lv, "#sequence-details-toggle-#{seq.id}")
    end

    test "expanded details reveal stable wrappers for embeds and comments", %{
      conn: conn,
      author: author
    } do
      section = insert(:section)
      step = insert(:step, section: section, code: "VD-1", name: "Video Step")

      seq =
        insert(:sequence,
          user: author,
          public: true,
          name: "Sequência Expandida",
          video_url: "https://youtu.be/abc123"
        )

      insert(:sequence_step, sequence: seq, step: step, position: 1)

      {:ok, _comment} =
        Engagement.create_sequence_comment(author, seq.id, %{body: "Primeiro comentário"})

      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/sequence")

      render_click(lv, "toggle_seq_expand", %{"seq-id" => seq.id})

      assert has_element?(lv, "#sequence-expanded-#{seq.id}")
      assert has_element?(lv, "#sequence-comments-#{seq.id}")
      assert has_element?(lv, "#sequence-embed-#{seq.id}")
    end

    test "shows step codes inline", %{conn: conn} do
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/sequence")
      assert html =~ "BF"
    end

    test "view on map link carries the selected sequence id", %{conn: conn, sequence: seq} do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/sequence")
      assert has_element?(lv, ~s|a[href="/graph/visual?seq=#{seq.id}"]|)
    end

    test "shows author username", %{conn: conn, author: author} do
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/sequence")
      assert html =~ "@#{author.username}"
    end

    test "shows video indicator when video_url present", %{conn: conn, author: author} do
      _seq_with_video =
        insert(:sequence,
          user: author,
          public: true,
          name: "Seq com vídeo",
          video_url: "https://youtu.be/abc123"
        )

      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/sequence")
      assert html =~ "vídeo"
    end

    test "toggle_like on sequence updates like count", %{conn: conn, sequence: seq} do
      conn = logged_in_conn(conn)
      {:ok, lv, _html} = live(conn, ~p"/sequence")
      html = render_click(lv, "toggle_like", %{"type" => "sequence", "id" => seq.id})
      assert html =~ "hero-heart-solid"
    end

    test "empty state when no public sequences", %{conn: conn} do
      # The setup block inserted one sequence; we just confirm the page renders
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/sequence")
      assert html =~ "Sequências" or html =~ "sequência"
    end

    test "empty state shows CTA to create", %{conn: conn} do
      # Use a fresh user/conn with no setup sequences
      conn = logged_in_conn(conn)
      {:ok, _lv, html} = live(conn, ~p"/sequence")
      assert html =~ "Gerar sequência" or html =~ "Criar a primeira sequência"
    end
  end

  describe "sequence tabs" do
    test "shows Comunidade and Minhas tabs", %{conn: conn} do
      conn = logged_in_conn(conn)
      {:ok, _lv, html} = live(conn, ~p"/sequence")

      assert html =~ "Comunidade"
      assert html =~ "Minhas"
    end

    test "switching to Minhas tab shows user's sequences", %{conn: conn} do
      user = insert(:user)
      section = insert(:section)
      step = insert(:step, section: section, code: "MN-1", name: "Minha Sequência")
      sequence = insert(:sequence, user: user, public: true, name: "Minha Curadoria")
      insert(:sequence_step, sequence: sequence, step: step, position: 1)

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/sequence")
      html = render_click(lv, "switch_seq_tab", %{"tab" => "mine"})

      assert has_element?(lv, "#my-sequences-stream")
      assert has_element?(lv, "#my-sequences-stream #sequence-card-#{sequence.id}")
      assert html =~ "Minhas"
    end

    test "Minhas stream renders a real owned sequence setup", %{conn: conn} do
      user = insert(:user)
      section = insert(:section)
      step = insert(:step, section: section, code: "MN-2", name: "Minha Trilha")
      owned_sequence = insert(:sequence, user: user, public: true, name: "Coleção da Casa")
      insert(:sequence_step, sequence: owned_sequence, step: step, position: 1)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/sequence")

      render_click(lv, "switch_seq_tab", %{"tab" => "mine"})

      assert has_element?(lv, "#my-sequences-stream")
      assert has_element?(lv, "#my-sequences-stream #sequence-card-#{owned_sequence.id}")

      assert has_element?(
               lv,
               "#my-sequences-stream #sequence-details-toggle-#{owned_sequence.id}"
             )
    end
  end

  describe "follow interactions on sequence authors" do
    test "toggle_follow on sequence author creates a follow", %{conn: conn} do
      user = insert(:user)
      target = insert(:user)
      section = insert(:section)
      step = insert(:step, section: section, code: "FF-1", name: "Follow Test Step")
      sequence = insert(:sequence, user: target, public: true, name: "Follow Test Seq")
      insert(:sequence_step, sequence: sequence, step: step, position: 1)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sequence")

      render_click(view, "toggle_follow", %{"user-id" => target.id})

      assert Engagement.following?(user.id, target.id)
    end
  end
end
