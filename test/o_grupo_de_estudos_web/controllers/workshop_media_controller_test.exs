defmodule OGrupoDeEstudosWeb.WorkshopMediaControllerTest do
  use OGrupoDeEstudosWeb.ConnCase, async: false

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    dir = Path.join(System.tmp_dir!(), "media_ctrl_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    previous = Application.get_env(:o_grupo_de_estudos, :uploads_path)
    Application.put_env(:o_grupo_de_estudos, :uploads_path, dir)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:o_grupo_de_estudos, :uploads_path)
        value -> Application.put_env(:o_grupo_de_estudos, :uploads_path, value)
      end

      File.rm_rf!(dir)
    end)

    source = Path.join(dir, "origem.png")
    File.write!(source, @png)

    owner = insert(:user)
    student = insert(:user)
    workshop = insert(:workshop, organizer: owner)
    {:ok, _} = Workshops.enroll(workshop, student)

    {:ok, media} =
      Workshops.add_media(workshop, student, %{
        tmp_path: source,
        content_type: "image/png",
        byte_size: byte_size(@png)
      })

    %{dir: dir, owner: owner, student: student, workshop: workshop, media: media}
  end

  describe "GET /workshop-media/:id" do
    test "enrolled user receives the file", ctx do
      conn = get(log_in_user(build_conn(), ctx.student), ~p"/workshop-media/#{ctx.media.id}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/png"]
    end

    test "admin receives the file", ctx do
      conn = get(log_in_user(build_conn(), ctx.owner), ~p"/workshop-media/#{ctx.media.id}")

      assert conn.status == 200
    end

    test "estranho logado NAO recebe", ctx do
      conn = get(log_in_user(build_conn(), insert(:user)), ~p"/workshop-media/#{ctx.media.id}")

      assert conn.status == 404
    end

    test "anonymous visitor does not receive it, even with the exact URL", ctx do
      conn = get(build_conn(), ~p"/workshop-media/#{ctx.media.id}")

      assert conn.status == 404
    end

    test "does not go to a shared cache", ctx do
      conn = get(log_in_user(build_conn(), ctx.student), ~p"/workshop-media/#{ctx.media.id}")

      assert get_resp_header(conn, "cache-control") == ["private, no-store"]
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "deleted media is gone, even for who could see it", ctx do
      {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.student, ctx.media.id)

      conn = get(log_in_user(build_conn(), ctx.student), ~p"/workshop-media/#{ctx.media.id}")

      assert conn.status == 404
    end

    test "id inventado nao quebra", ctx do
      conn = get(log_in_user(build_conn(), ctx.student), ~p"/workshop-media/nao-e-uuid")

      assert conn.status == 404
    end

    test "content type outside the allowlist is served as a generic binary", ctx do
      {:ok, forged} =
        ctx.media
        |> Ecto.Changeset.change(content_type: "image/svg+xml")
        |> OGrupoDeEstudos.Repo.update()

      conn = get(log_in_user(build_conn(), ctx.student), ~p"/workshop-media/#{forged.id}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["application/octet-stream"]
    end

    test "file is not served by Plug.Static", ctx do
      conn = get(build_conn(), "/uploads/#{ctx.media.storage_key}")

      assert conn.status in [400, 404]
    end
  end

  describe "GET /workshop-media/:id/poster" do
    setup ctx do
      key = Path.join("workshop_media", "poster_teste.jpg")
      File.mkdir_p!(Path.join(ctx.dir, "workshop_media"))
      File.write!(Path.join(ctx.dir, key), @png)

      {:ok, with_poster} =
        ctx.media
        |> Ecto.Changeset.change(poster_key: key, kind: :video, content_type: "video/mp4")
        |> OGrupoDeEstudos.Repo.update()

      %{with_poster: with_poster}
    end

    test "enrolled user receives the poster as an image", ctx do
      conn =
        get(log_in_user(build_conn(), ctx.student), ~p"/workshop-media/#{ctx.media.id}/poster")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/jpeg"]
    end

    test "logged-in outsider does not receive the poster", ctx do
      conn =
        get(log_in_user(build_conn(), insert(:user)), ~p"/workshop-media/#{ctx.media.id}/poster")

      assert conn.status == 404
    end

    test "anonymous visitor does not receive the poster", ctx do
      conn = get(build_conn(), ~p"/workshop-media/#{ctx.media.id}/poster")

      assert conn.status == 404
    end

    test "media without a poster returns 404 instead of raising", ctx do
      {:ok, without_poster} =
        ctx.with_poster |> Ecto.Changeset.change(poster_key: nil) |> OGrupoDeEstudos.Repo.update()

      conn =
        get(
          log_in_user(build_conn(), ctx.student),
          ~p"/workshop-media/#{without_poster.id}/poster"
        )

      assert conn.status == 404
    end

    test "poster does not go to a shared cache", ctx do
      conn =
        get(log_in_user(build_conn(), ctx.student), ~p"/workshop-media/#{ctx.media.id}/poster")

      assert get_resp_header(conn, "cache-control") == ["private, no-store"]
    end

    test "deleted media no longer serves the poster", ctx do
      {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.student, ctx.media.id)

      conn =
        get(log_in_user(build_conn(), ctx.student), ~p"/workshop-media/#{ctx.media.id}/poster")

      assert conn.status == 404
    end
  end
end
