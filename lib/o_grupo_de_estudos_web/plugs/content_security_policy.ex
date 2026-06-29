defmodule OGrupoDeEstudosWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Sets a Content-Security-Policy header with a per-request nonce.

  The nonce is exposed as `conn.assigns.csp_nonce` so the one inline script we
  keep (the dark-mode anti-FOUC snippet in `root.html.heex`, which must run in
  `<head>` before paint) can be allowlisted via `nonce={@csp_nonce}`. Every
  other inline script is blocked, which is the core XSS mitigation.

  Notes on the chosen directives:
  - `script-src 'self' 'nonce-...'`: app.js and its same-origin dynamic vendor
    imports load via `'self'`; the dark-mode snippet via the nonce.
  - `style-src 'unsafe-inline'`: unavoidable here — templates use `style="..."`
    attributes and Cytoscape sets inline styles at runtime. Style injection is a
    far lower risk than script injection.
  - `connect-src 'self'`: covers the same-origin LiveView WebSocket.
  - `frame-src 'self' youtube.com youtube-nocookie.com instagram.com`: allows
    the embedded media players (YouTube video/Shorts and Instagram post/reel
    iframes — see `MediaEmbed`). Without it the browser blocks the iframe
    ("This content is blocked") because frame-src falls back to
    `default-src 'self'`. Not to be confused with `frame-ancestors 'none'`:
    that stops US from being framed; `frame-src` controls what WE may frame.
  - `img-src 'self' data: https:`: same-origin avatars/icons plus data URIs.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    nonce = 18 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", policy(nonce))
  end

  defp policy(nonce) do
    Enum.join(
      [
        "default-src 'self'",
        "script-src 'self' 'nonce-#{nonce}'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: https:",
        "font-src 'self'",
        "connect-src 'self'",
        "frame-src 'self' https://www.youtube.com https://www.youtube-nocookie.com https://www.instagram.com https://instagram.com",
        "frame-ancestors 'none'",
        "base-uri 'self'",
        "object-src 'none'",
        "form-action 'self'"
      ],
      "; "
    )
  end
end
