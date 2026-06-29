defmodule OGrupoDeEstudosWeb.Plugs.ContentSecurityPolicyTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias OGrupoDeEstudosWeb.Plugs.ContentSecurityPolicy

  defp csp(conn) do
    conn |> Plug.Conn.get_resp_header("content-security-policy") |> List.first()
  end

  describe "call/2" do
    test "libera o player do YouTube via frame-src (senao o navegador bloqueia o iframe)" do
      header = conn(:get, "/") |> ContentSecurityPolicy.call([]) |> csp()

      assert header =~ "frame-src"
      assert header =~ "https://www.youtube.com"
      assert header =~ "https://www.youtube-nocookie.com"
    end

    test "mantem o restante restritivo (XSS continua mitigado)" do
      header = conn(:get, "/") |> ContentSecurityPolicy.call([]) |> csp()

      assert header =~ "default-src 'self'"
      assert header =~ "object-src 'none'"
      # frame-ancestors 'none' protege contra clickjacking; nao confundir com frame-src.
      assert header =~ "frame-ancestors 'none'"
      refute header =~ "script-src 'self' 'unsafe-inline'"
    end

    test "expoe o nonce para o snippet inline permitido" do
      conn = conn(:get, "/") |> ContentSecurityPolicy.call([])

      assert is_binary(conn.assigns.csp_nonce)
      assert csp(conn) =~ "'nonce-#{conn.assigns.csp_nonce}'"
    end
  end
end
