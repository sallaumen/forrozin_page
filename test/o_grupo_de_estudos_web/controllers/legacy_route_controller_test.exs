defmodule OGrupoDeEstudosWeb.LegacyRouteControllerTest do
  @moduledoc """
  The Portuguese routes were renamed to English. A link already shared (a program
  on WhatsApp, a bookmarked manage page) has to land on the new address instead
  of a 404.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  describe "renamed public routes" do
    test "an old program link lands on the new address", %{conn: conn} do
      conn = get(conn, "/programacao/fim-de-semana-abc123")

      assert redirected_to(conn, 301) == "/programs/fim-de-semana-abc123"
    end

    test "an old manage link lands on the new address", %{conn: conn} do
      conn = get(conn, "/workshops/aulao-xyz789/gerenciar")

      assert redirected_to(conn, 301) == "/workshops/aulao-xyz789/manage"
    end
  end

  describe "renamed form routes" do
    test "new workshop", %{conn: conn} do
      assert redirected_to(get(conn, "/study/workshops/novo"), 301) == "/study/workshops/new"
    end

    test "edit workshop", %{conn: conn} do
      conn = get(conn, "/study/workshops/aulao-xyz789/editar")

      assert redirected_to(conn, 301) == "/study/workshops/aulao-xyz789/edit"
    end

    test "new program", %{conn: conn} do
      assert redirected_to(get(conn, "/study/programacoes/nova"), 301) == "/study/programs/new"
    end

    test "edit program", %{conn: conn} do
      conn = get(conn, "/study/programacoes/fim-de-semana-abc123/editar")

      assert redirected_to(conn, 301) == "/study/programs/fim-de-semana-abc123/edit"
    end
  end

  test "the query string survives, so a workshop still starts inside its program", %{conn: conn} do
    conn = get(conn, "/study/workshops/novo?program=fim-de-semana-abc123")

    assert redirected_to(conn, 301) ==
             "/study/workshops/new?program=fim-de-semana-abc123"
  end

  test "the new address is served by the LiveView, not by another redirect", %{conn: conn} do
    owner = insert(:user)
    program = insert(:workshop_program, owner: owner, status: :published)

    conn = get(conn, "/programs/#{program.slug}")

    assert html_response(conn, 200) =~ program.title
  end
end
