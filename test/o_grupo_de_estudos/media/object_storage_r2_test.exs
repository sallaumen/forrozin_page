defmodule OGrupoDeEstudos.Media.ObjectStorage.R2Test do
  @moduledoc """
  Adapter R2 da porta de objetos, sem tocar a rede.

  As operações HTTP passam por um plug de teste (Req.Test) que finge o R2; a
  assinatura de URL é calculo puro e é conferida pela forma da URL. O que
  importa: bucket certo por prefixo, streaming (nada de vídeo inteiro na RAM)
  e URL assinada com validade curta.
  """

  # async: false — configura o adapter via Application env, que é global.
  use ExUnit.Case, async: false

  alias OGrupoDeEstudos.Media.ObjectStorage.R2

  @conta "conta123"
  @endpoint "https://conta123.r2.cloudflarestorage.com"

  setup do
    Req.Test.set_req_test_from_context(%{async: false})

    Application.put_env(:o_grupo_de_estudos, R2,
      account_id: @conta,
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
    origem = Path.join(dir, "origem.mp4")
    File.write!(origem, "bytes do video")
    on_exit(fn -> File.rm_rf!(dir) end)

    %{dir: dir, origem: origem}
  end

  describe "put/2" do
    test "mídia de galeria sobe por PUT assinado no bucket privado", ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/ogde-private/workshop_media/v.mp4"
        assert conn.query_params["X-Amz-Signature"]
        assert Plug.Conn.get_req_header(conn, "content-type") == ["video/mp4"]
        {:ok, corpo, conn} = Plug.Conn.read_body(conn)
        assert corpo == "bytes do video"
        Req.Test.text(conn, "")
      end)

      assert :ok = R2.put("workshop_media/v.mp4", ctx.origem)
    end

    test "avatar vai para o bucket público", ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/ogde-public/avatars/u1_9.png"
        Req.Test.text(conn, "")
      end)

      assert :ok = R2.put("avatars/u1_9.png", ctx.origem)
    end

    test "resposta que não é 2xx vira erro", ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        conn |> Plug.Conn.put_status(403) |> Req.Test.text("AccessDenied")
      end)

      assert {:error, {403, _corpo}} = R2.put("flyers/x.png", ctx.origem)
    end

    test "origem que não existe devolve erro sem estourar", _ctx do
      assert {:error, :enoent} = R2.put("flyers/x.png", "/nao/existe.png")
    end
  end

  describe "delete/1 e exists?/1" do
    test "delete devolve :ok no 204", _ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/ogde-private/workshop_media/v.mp4"
        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert :ok = R2.delete("workshop_media/v.mp4")
    end

    test "exists? é um HEAD", _ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "HEAD"
        Plug.Conn.send_resp(conn, 200, "")
      end)

      assert R2.exists?("avatars/u1.png")
    end

    test "exists? de chave sem objeto é false", _ctx do
      Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)

      refute R2.exists?("avatars/fantasma.png")
    end
  end

  describe "list/1" do
    test "lista por prefixo e devolve as chaves", _ctx do
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

    test "prefixo sem nada devolve lista vazia", _ctx do
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
    test "URL pública sai do domínio configurado, estável para gravar no banco" do
      assert R2.public_url("avatars/u1.png") == "https://midia.teste.dev/avatars/u1.png"
    end

    test "servir mídia restrita é redirect para URL assinada de vida curta" do
      assert {:redirect, url} = R2.serve("workshop_media/v.mp4")

      assert url =~ "#{@endpoint}/ogde-private/workshop_media/v.mp4?"
      assert url =~ "X-Amz-Signature="
      # 1 hora: o bastante para assistir, curto demais para virar link eterno.
      assert url =~ "X-Amz-Expires=3600"
    end
  end

  describe "with_local_file/2" do
    test "baixa para um temporário, roda a função e limpa", _ctx do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        Req.Test.text(conn, "conteudo baixado")
      end)

      assert {:ok, {conteudo, caminho}} =
               R2.with_local_file("workshop_media/v.mov", fn caminho ->
                 {File.read!(caminho), caminho}
               end)

      assert conteudo == "conteudo baixado"
      refute File.exists?(caminho)
    end

    test "objeto que não existe devolve not_found sem rodar a função", _ctx do
      Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)

      assert {:error, :not_found} =
               R2.with_local_file("workshop_media/nada.mov", fn _ ->
                 flunk("não era para rodar")
               end)
    end
  end

  describe "free_bytes/0" do
    test "R2 não tem volume para encher: quem limita é a cota por workshop" do
      assert R2.free_bytes() == :unknown
    end
  end
end
