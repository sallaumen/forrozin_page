defmodule OGrupoDeEstudosWeb.WorkshopMediaController do
  @moduledoc """
  Serves gallery media only to whoever may see it.

  It exists because `Plug.Static` runs before the session and has no way to ask
  who the person is: paid content cannot be served by a static plug.
  """

  use OGrupoDeEstudosWeb, :controller

  alias OGrupoDeEstudos.Workshops

  # The content_type stored on the row came from the uploader's browser. Serving
  # anything outside this list would open stored XSS: a forged "image/svg+xml"
  # runs script on the site origin when opened straight from the URL. Outside the
  # list, the file goes down as a generic binary.
  @tipos_seguros ~w(image/jpeg image/png image/webp video/mp4 video/quicktime)

  def show(conn, %{"id" => media_id}) do
    case autorizada(conn, media_id) do
      {:ok, media} -> entregar(conn, media)
      :error -> nao_encontrado(conn)
    end
  end

  def poster(conn, %{"id" => media_id}) do
    case autorizada(conn, media_id) do
      {:ok, media} -> entregar_poster(conn, media)
      :error -> nao_encontrado(conn)
    end
  end

  defp autorizada(conn, media_id) do
    with %{} = media <- Workshops.get_media(media_id),
         %{} = workshop <- Workshops.get_workshop(media.workshop_id),
         true <- is_nil(media.deleted_at),
         true <- Workshops.can_see_media?(workshop, conn.assigns[:current_user]) do
      {:ok, media}
    else
      _recusado -> :error
    end
  end

  defp entregar(conn, media) do
    conn
    |> put_resp_content_type(tipo_seguro(media.content_type), nil)
    |> responder(Workshops.serve_media(media))
  end

  # The poster is a video frame: same permission as the media, otherwise the class
  # could be reconstructed in thumbnails without paying for it. Always JPEG: the
  # transcode generated it, never the uploader's browser.
  defp entregar_poster(conn, media) do
    conn
    |> put_resp_content_type("image/jpeg", nil)
    |> responder(Workshops.serve_poster(media))
  end

  # The storage port decides how: a local file goes out through the kernel
  # sendfile; an external provider goes out as a short-lived signed URL.
  #
  # The skip is a sobelow false positive: it flags any variable in send_file, but
  # this path comes from `ObjectStorage.serve/1` with an opaque server-generated
  # key. User input is only the id, resolved through the database by `autorizada/2`.
  # sobelow_skip ["Traversal.SendFile"]
  defp responder(conn, {:file, caminho}) do
    conn |> cabecalhos_de_midia() |> send_file(200, caminho)
  end

  defp responder(conn, {:redirect, url}), do: redirect(conn, external: url)
  defp responder(conn, {:error, :not_found}), do: nao_encontrado(conn)

  defp cabecalhos_de_midia(conn) do
    conn
    # Paid content: never in a shared cache.
    |> put_resp_header("cache-control", "private, no-store")
    |> put_resp_header("x-content-type-options", "nosniff")
  end

  # No charset in any case: the file is binary, and "image/png; charset=utf-8"
  # is nonsense.
  defp tipo_seguro(tipo) when tipo in @tipos_seguros, do: tipo
  defp tipo_seguro(_desconfiado), do: "application/octet-stream"

  defp nao_encontrado(conn), do: conn |> put_status(:not_found) |> text("Não encontrado")
end
