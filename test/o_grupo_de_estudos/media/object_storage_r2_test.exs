defmodule OGrupoDeEstudos.Media.ObjectStorage.R2Test do
  @moduledoc """
  R2 adapter of the object port, without touching the network: HTTP goes
  through Req.Test and URL signing is checked by the shape of the URL. What
  matters is the right bucket per prefix, streaming, and short-lived URLs.
  """

  use ExUnit.Case, async: false

  alias OGrupoDeEstudos.Media.ObjectStorage.R2

  @account_id "conta123"
  @endpoint "https://conta123.r2.cloudflarestorage.com"

  setup do
    Req.Test.set_req_test_from_context(%{async: false})

    Application.put_env(:o_grupo_de_estudos, R2,
      account_id: @account_id,
      access_key_id: "AKIATESTE",
      secret_access_key: "segredo-de-teste",
      private_bucket: "ogde-private",
      public_bucket: "ogde-public",
      public_base_url: "https://midia.teste.dev",
      req_options: [plug: {Req.Test, __MODULE__}, retry: false]
    )

    on_exit(fn -> Application.delete_env(:o_grupo_de_estudos, R2) end)

    dir = Path.join(System.tmp_dir!(), "r2_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    source = Path.join(dir, "origem.mp4")
    File.write!(source, "bytes do video")
    on_exit(fn -> File.rm_rf!(dir) end)

    %{dir: dir, source: source}
  end

  describe "put/2" do
    test "gallery media goes up through a signed PUT to the private bucket", ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/ogde-private/workshop_media/v.mp4"
        assert conn.query_params["X-Amz-Signature"]
        assert Plug.Conn.get_req_header(conn, "content-type") == ["video/mp4"]
        assert Plug.Conn.get_req_header(conn, "content-length") == ["14"]
        {:ok, corpo, conn} = Plug.Conn.read_body(conn)
        assert corpo == "bytes do video"
        Req.Test.text(conn, "")
      end)

      assert :ok = R2.put("workshop_media/v.mp4", ctx.source)
    end

    test "avatar goes to the public bucket", ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/ogde-public/avatars/u1_9.png"
        Req.Test.text(conn, "")
      end)

      assert :ok = R2.put("avatars/u1_9.png", ctx.source)
    end

    test "non-2xx response becomes an error", ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        conn |> Plug.Conn.put_status(403) |> Req.Test.text("AccessDenied")
      end)

      assert {:error, {403, _corpo}} = R2.put("flyers/x.png", ctx.source)
    end

    test "missing source returns an error instead of raising", _ctx do
      assert {:error, :enoent} = R2.put("flyers/x.png", "/nao/existe.png")
    end
  end

  describe "delete/1 e exists?/1" do
    test "delete returns :ok on 204", _ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/ogde-private/workshop_media/v.mp4"
        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert :ok = R2.delete("workshop_media/v.mp4")
    end

    test "exists? issues a HEAD", _ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "HEAD"
        Plug.Conn.send_resp(conn, 200, "")
      end)

      assert R2.exists?("avatars/u1.png")
    end

    test "exists? returns false for a key with no object", _ctx do
      Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)

      refute R2.exists?("avatars/fantasma.png")
    end
  end

  describe "list/1" do
    test "lists by prefix and returns the keys", _ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_params["prefix"] == "avatars/u1_"

        conn
        |> Plug.Conn.put_resp_content_type("application/xml")
        |> Plug.Conn.send_resp(200, """
        <?xml version="1.0" encoding="UTF-8"?>
        <ListBucketResult>
          <Name>ogde-public</Name>
          <Contents><Key>avatars/u1_1.png</Key></Contents>
          <Contents><Key>avatars/u1_2.png</Key></Contents>
        </ListBucketResult>
        """)
      end)

      assert R2.list("avatars/u1_") == ["avatars/u1_1.png", "avatars/u1_2.png"]
    end

    test "empty prefix returns an empty list", _ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/xml")
        |> Plug.Conn.send_resp(200, """
        <?xml version="1.0" encoding="UTF-8"?>
        <ListBucketResult><Name>ogde-public</Name></ListBucketResult>
        """)
      end)

      assert R2.list("avatars/u9_") == []
    end
  end

  describe "public_url/1 e serve/1" do
    test "public URL comes from the configured domain, stable enough to store" do
      assert R2.public_url("avatars/u1.png") == "https://midia.teste.dev/avatars/u1.png"
    end

    test "serving restricted media redirects to a short-lived signed URL" do
      assert {:redirect, url} = R2.serve("workshop_media/v.mp4")

      assert url =~ "#{@endpoint}/ogde-private/workshop_media/v.mp4?"
      assert url =~ "X-Amz-Signature="
      assert url =~ "X-Amz-Expires=3600"
    end
  end

  describe "with_local_file/2" do
    test "downloads to a temporary file, runs the function and cleans up", _ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        Req.Test.text(conn, "conteudo baixado")
      end)

      assert {:ok, {content, path}} =
               R2.with_local_file("workshop_media/v.mov", fn path ->
                 {File.read!(path), path}
               end)

      assert content == "conteudo baixado"
      refute File.exists?(path)
    end

    test "missing object returns not_found without running the function", _ctx do
      Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)

      assert {:error, :not_found} =
               R2.with_local_file("workshop_media/nada.mov", fn _ ->
                 flunk("não era para rodar")
               end)
    end
  end

  describe "free_bytes/0" do
    test "R2 has no volume to fill: the workshop quota is the limit" do
      assert R2.free_bytes() == :unknown
    end
  end
end
