defmodule OGrupoDeEstudosWeb.OgImageController do
  @moduledoc """
  The image a messenger shows under a shared workshop or program link.

  Serving the flyer through a page-addressed door (`/workshops/:slug/og-image`)
  instead of pointing the meta tag at the raw file keeps the crop lazy: only the
  crawler pays for the square derivative, once, and pages render without touching
  the storage.

  No permission check on purpose: a flyer key is already unguessable and public by
  design, and the whole point of a private workshop's link is being shareable with
  whoever received the invite.
  """

  use OGrupoDeEstudosWeb, :controller

  alias OGrupoDeEstudos.Media.Storage
  alias OGrupoDeEstudos.Workshops

  def workshop(conn, %{"slug" => slug}) do
    serve_flyer(conn, Workshops.get_by_slug(slug))
  end

  def program(conn, %{"slug" => slug}) do
    serve_flyer(conn, Workshops.get_program_by_slug(slug))
  end

  defp serve_flyer(conn, nil), do: send_resp(conn, 404, "")

  defp serve_flyer(conn, %{flyer_path: nil}), do: redirect(conn, to: "/icons/icon-512.png")

  defp serve_flyer(conn, %{flyer_path: flyer_path}) do
    case Storage.serve_og_square(flyer_path) do
      {:file, path} ->
        conn
        |> put_resp_content_type(MIME.from_path(path))
        |> put_resp_header("cache-control", "public, max-age=86400")
        |> send_file(200, path)

      {:redirect, remote_url} ->
        redirect(conn, external: remote_url)

      {:error, :not_found} ->
        redirect(conn, to: "/icons/icon-512.png")
    end
  end
end
