defmodule OGrupoDeEstudosWeb.WorkshopMediaControllerTest do
  # async: false — troca :uploads_path, que é config global.
  use OGrupoDeEstudosWeb.ConnCase, async: false

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    dir = Path.join(System.tmp_dir!(), "media_ctrl_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    anterior = Application.get_env(:o_grupo_de_estudos, :uploads_path)
    Application.put_env(:o_grupo_de_estudos, :uploads_path, dir)

    on_exit(fn ->
      case anterior do
        nil -> Application.delete_env(:o_grupo_de_estudos, :uploads_path)
        valor -> Application.put_env(:o_grupo_de_estudos, :uploads_path, valor)
      end

      File.rm_rf!(dir)
    end)

    origem = Path.join(dir, "origem.png")
    File.write!(origem, @png)

    dono = insert(:user)
    aluna = insert(:user)
    workshop = insert(:workshop, organizer: dono)
    {:ok, _} = Workshops.enroll(workshop, aluna)

    {:ok, media} =
      Workshops.add_media(workshop, aluna, %{
        tmp_path: origem,
        content_type: "image/png",
        byte_size: byte_size(@png)
      })

    %{dir: dir, dono: dono, aluna: aluna, workshop: workshop, media: media}
  end

  describe "GET /workshop-media/:id" do
    test "quem se inscreveu recebe o arquivo", ctx do
      conn = get(log_in_user(build_conn(), ctx.aluna), ~p"/workshop-media/#{ctx.media.id}")

      assert conn.status == 200
      # Binario nao leva charset.
      assert get_resp_header(conn, "content-type") == ["image/png"]
    end

    test "quem administra recebe", ctx do
      conn = get(log_in_user(build_conn(), ctx.dono), ~p"/workshop-media/#{ctx.media.id}")

      assert conn.status == 200
    end

    test "estranho logado NAO recebe", ctx do
      conn = get(log_in_user(build_conn(), insert(:user)), ~p"/workshop-media/#{ctx.media.id}")

      assert conn.status == 404
    end

    test "visitante sem conta NAO recebe, mesmo com a URL exata", ctx do
      conn = get(build_conn(), ~p"/workshop-media/#{ctx.media.id}")

      assert conn.status == 404
    end

    test "nao vai para cache compartilhado", ctx do
      conn = get(log_in_user(build_conn(), ctx.aluna), ~p"/workshop-media/#{ctx.media.id}")

      assert get_resp_header(conn, "cache-control") == ["private, no-store"]
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "midia apagada some, mesmo para quem podia ver", ctx do
      {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.aluna, ctx.media.id)

      conn = get(log_in_user(build_conn(), ctx.aluna), ~p"/workshop-media/#{ctx.media.id}")

      assert conn.status == 404
    end

    test "id inventado nao quebra", ctx do
      conn = get(log_in_user(build_conn(), ctx.aluna), ~p"/workshop-media/nao-e-uuid")

      assert conn.status == 404
    end

    test "content_type fora da allowlist sai como binario generico", ctx do
      # O content_type gravado veio do navegador de quem subiu o arquivo. Um
      # cliente hostil que burlasse a validacao do upload e gravasse
      # "image/svg+xml" ganharia XSS armazenado: SVG aberto direto na URL
      # executa script na origem do site, com a sessao de quem clicou.
      {:ok, forjada} =
        ctx.media
        |> Ecto.Changeset.change(content_type: "image/svg+xml")
        |> OGrupoDeEstudos.Repo.update()

      conn = get(log_in_user(build_conn(), ctx.aluna), ~p"/workshop-media/#{forjada.id}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["application/octet-stream"]
    end

    test "o arquivo NAO e servido pelo Plug.Static", ctx do
      # A pasta da midia fica fora da allowlist: se este caminho servisse, a
      # autorizacao do controller seria decorativa.
      conn = get(build_conn(), "/uploads/#{ctx.media.storage_key}")

      assert conn.status in [400, 404]
    end
  end

  describe "GET /workshop-media/:id/poster" do
    setup ctx do
      # Poster de verdade nao existe sem ffmpeg, entao a linha e escrita como o
      # transcode a deixaria e o arquivo vai para o disco na mao.
      chave = Path.join("workshop_media", "poster_teste.jpg")
      File.mkdir_p!(Path.join(ctx.dir, "workshop_media"))
      File.write!(Path.join(ctx.dir, chave), @png)

      {:ok, com_poster} =
        ctx.media
        |> Ecto.Changeset.change(poster_key: chave, kind: :video, content_type: "video/mp4")
        |> OGrupoDeEstudos.Repo.update()

      %{com_poster: com_poster}
    end

    test "quem se inscreveu recebe a capa como imagem", ctx do
      conn = get(log_in_user(build_conn(), ctx.aluna), ~p"/workshop-media/#{ctx.media.id}/poster")

      assert conn.status == 200
      # O poster e JPEG mesmo que o video seja mp4: o content_type da linha e
      # do video, e serviria imagem com tipo errado.
      assert get_resp_header(conn, "content-type") == ["image/jpeg"]
    end

    test "estranho logado NAO recebe a capa", ctx do
      # A capa e um quadro do video pago: vazar ela vaza o conteudo.
      conn =
        get(log_in_user(build_conn(), insert(:user)), ~p"/workshop-media/#{ctx.media.id}/poster")

      assert conn.status == 404
    end

    test "visitante sem conta NAO recebe a capa", ctx do
      conn = get(build_conn(), ~p"/workshop-media/#{ctx.media.id}/poster")

      assert conn.status == 404
    end

    test "midia sem poster devolve 404 em vez de estourar", ctx do
      {:ok, sem_poster} =
        ctx.com_poster |> Ecto.Changeset.change(poster_key: nil) |> OGrupoDeEstudos.Repo.update()

      conn =
        get(log_in_user(build_conn(), ctx.aluna), ~p"/workshop-media/#{sem_poster.id}/poster")

      assert conn.status == 404
    end

    test "capa nao vai para cache compartilhado", ctx do
      conn = get(log_in_user(build_conn(), ctx.aluna), ~p"/workshop-media/#{ctx.media.id}/poster")

      assert get_resp_header(conn, "cache-control") == ["private, no-store"]
    end

    test "midia apagada nao serve mais a capa", ctx do
      {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.aluna, ctx.media.id)

      conn = get(log_in_user(build_conn(), ctx.aluna), ~p"/workshop-media/#{ctx.media.id}/poster")

      assert conn.status == 404
    end
  end
end
