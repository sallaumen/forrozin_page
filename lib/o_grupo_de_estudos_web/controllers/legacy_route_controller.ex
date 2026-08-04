defmodule OGrupoDeEstudosWeb.LegacyRouteController do
  @moduledoc """
  Permanent redirects for the routes that were renamed from Portuguese to English.

  A program link circulates on WhatsApp and a manage link gets bookmarked, so an
  address that was already shared has to keep working. These can be dropped once
  the old links stop showing up in the access logs.
  """

  use OGrupoDeEstudosWeb, :controller

  def program(conn, %{"slug" => slug}), do: moved(conn, ~p"/programs/#{slug}")

  def manage_workshop(conn, %{"slug" => slug}), do: moved(conn, ~p"/workshops/#{slug}/manage")

  def new_workshop(conn, _params), do: moved(conn, ~p"/study/workshops/new")

  def edit_workshop(conn, %{"slug" => slug}), do: moved(conn, ~p"/study/workshops/#{slug}/edit")

  def new_program(conn, _params), do: moved(conn, ~p"/study/programs/new")

  def edit_program(conn, %{"slug" => slug}), do: moved(conn, ~p"/study/programs/#{slug}/edit")

  # The query string carries `?program=slug`, which makes a workshop start inside
  # a program: dropping it on the redirect would silently create it loose.
  defp moved(conn, path) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: with_query(path, conn.query_string))
  end

  defp with_query(path, ""), do: path
  defp with_query(path, query), do: path <> "?" <> query
end
