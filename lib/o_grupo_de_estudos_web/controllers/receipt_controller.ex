defmodule OGrupoDeEstudosWeb.ReceiptController do
  @moduledoc """
  Serves a payment receipt only to whoever sent it and to whoever runs the class.

  A receipt carries bank data, so it never goes near `Plug.Static`: that plug
  runs before the session and has no way to ask who is calling. Anything that is
  not an explicit yes comes back as 404, which does not even confirm the file
  exists.
  """

  use OGrupoDeEstudosWeb, :controller

  alias OGrupoDeEstudos.Workshops

  # The content type came from the sender's browser. Serving anything outside
  # this list would open stored XSS: a forged "image/svg+xml" runs script on the
  # site origin when opened straight from the URL.
  @safe_types ~w(image/jpeg image/png image/webp application/pdf)

  def workshop(conn, %{"id" => enrollment_id}) do
    enrollment_id
    |> Workshops.fetch_workshop_receipt(conn.assigns[:current_user])
    |> deliver(conn)
  end

  def program(conn, %{"id" => enrollment_id}) do
    enrollment_id
    |> Workshops.fetch_program_receipt(conn.assigns[:current_user])
    |> deliver(conn)
  end

  defp deliver({:error, :not_found}, conn), do: not_found(conn)

  defp deliver({:ok, enrollment}, conn) do
    conn
    |> put_resp_content_type(safe_type(enrollment.receipt_content_type), nil)
    |> respond(Workshops.serve_receipt(enrollment))
  end

  # The storage port decides how: a local file goes through the kernel sendfile,
  # an external provider goes out as a short-lived signed URL.
  #
  # The skip is a sobelow false positive: it flags any variable in send_file, but
  # this path comes from the storage with an opaque server-generated key. User
  # input is only the id, resolved through the database with a permission check.
  # sobelow_skip ["Traversal.SendFile"]
  defp respond(conn, {:file, path}) do
    conn |> receipt_headers() |> send_file(200, path)
  end

  defp respond(conn, {:redirect, url}), do: redirect(conn, external: url)
  defp respond(conn, {:error, :not_found}), do: not_found(conn)

  defp receipt_headers(conn) do
    conn
    # Bank data: never in a shared cache, never guessed by content sniffing.
    |> put_resp_header("cache-control", "private, no-store")
    |> put_resp_header("x-content-type-options", "nosniff")
  end

  defp safe_type(type) when type in @safe_types, do: type
  defp safe_type(_untrusted), do: "application/octet-stream"

  defp not_found(conn), do: conn |> put_status(:not_found) |> text("Não encontrado")
end
