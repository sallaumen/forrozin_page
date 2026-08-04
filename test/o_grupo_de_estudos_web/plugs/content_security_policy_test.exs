defmodule OGrupoDeEstudosWeb.Plugs.ContentSecurityPolicyTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias OGrupoDeEstudosWeb.Plugs.ContentSecurityPolicy

  defp csp(conn) do
    conn |> Plug.Conn.get_resp_header("content-security-policy") |> List.first()
  end

  describe "call/2" do
    test "allows YouTube and Instagram embeds through frame-src" do
      header = conn(:get, "/") |> ContentSecurityPolicy.call([]) |> csp()

      assert header =~ "frame-src"
      assert header =~ "https://www.youtube.com"
      assert header =~ "https://www.youtube-nocookie.com"
      assert header =~ "https://www.instagram.com"
    end

    test "allows video and image from external storage without opening script" do
      header = conn(:get, "/") |> ContentSecurityPolicy.call([]) |> csp()

      assert header =~ "media-src 'self' https:"
      assert header =~ "img-src 'self' data: https:"
    end

    test "mantem o restante restritivo (XSS continua mitigado)" do
      header = conn(:get, "/") |> ContentSecurityPolicy.call([]) |> csp()

      assert header =~ "default-src 'self'"
      assert header =~ "object-src 'none'"
      assert header =~ "frame-ancestors 'none'"
      refute header =~ "script-src 'self' 'unsafe-inline'"
    end

    test "exposes the nonce for the allowed inline snippet" do
      conn = conn(:get, "/") |> ContentSecurityPolicy.call([])

      assert is_binary(conn.assigns.csp_nonce)
      assert csp(conn) =~ "'nonce-#{conn.assigns.csp_nonce}'"
    end
  end
end
