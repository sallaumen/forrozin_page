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

    %{dono: dono, aluna: aluna, workshop: workshop, media: media}
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

    test "o arquivo NAO e servido pelo Plug.Static", ctx do
      # A pasta da midia fica fora da allowlist: se este caminho servisse, a
      # autorizacao do controller seria decorativa.
      conn = get(build_conn(), "/uploads/#{ctx.media.storage_key}")

      assert conn.status in [400, 404]
    end
  end
end
