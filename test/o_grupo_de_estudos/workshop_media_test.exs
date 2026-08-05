defmodule OGrupoDeEstudos.WorkshopMediaTest do
  use OGrupoDeEstudos.DataCase, async: false

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    dir = Path.join(System.tmp_dir!(), "media_test_#{System.unique_integer([:positive])}")
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

    %{dir: dir, source: source, owner: owner, student: student, workshop: workshop}
  end

  defp photo(ctx),
    do: %{tmp_path: ctx.source, content_type: "image/png", byte_size: byte_size(@png)}

  defp video_upload(ctx),
    do: %{tmp_path: ctx.source, content_type: "video/mp4", byte_size: 5_000_000}

  describe "who can see the gallery" do
    test "enrolled user sees it", ctx do
      assert Workshops.can_see_media?(ctx.workshop, ctx.student)
    end

    test "admin sees it even without being enrolled", ctx do
      assert Workshops.can_see_media?(ctx.workshop, ctx.owner)

      partner = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.owner, partner.id)
      assert Workshops.can_see_media?(ctx.workshop, partner)
    end

    test "logged-in outsider does not see it", ctx do
      refute Workshops.can_see_media?(ctx.workshop, insert(:user))
    end

    test "anonymous visitor does not see it", ctx do
      refute Workshops.can_see_media?(ctx.workshop, nil)
    end
  end

  describe "add_media/3" do
    test "enrolled user uploads a photo and it is not official", ctx do
      assert {:ok, media} = Workshops.add_media(ctx.workshop, ctx.student, photo(ctx))

      assert media.kind == :photo
      refute media.official
      assert {:file, _path} = Workshops.serve_media(media)
    end

    test "admin uploads official media", ctx do
      assert {:ok, media} = Workshops.add_media(ctx.workshop, ctx.owner, photo(ctx))

      assert media.official
    end

    test "video is stored as video", ctx do
      assert {:ok, media} = Workshops.add_media(ctx.workshop, ctx.student, video_upload(ctx))

      assert media.kind == :video
    end

    test "file stays out of the public folder and lives in the workshop folder", ctx do
      {:ok, media} = Workshops.add_media(ctx.workshop, ctx.student, photo(ctx))

      refute media.storage_key =~ "avatars"
      refute media.storage_key =~ "flyers"
      assert media.storage_key =~ ~r{^workshop_media/#{ctx.workshop.id}/[A-Za-z0-9]+\.png$}
    end

    test "outsider does not upload media", ctx do
      assert {:error, :unauthorized} =
               Workshops.add_media(ctx.workshop, insert(:user), photo(ctx))
    end

    test "content type that is neither image nor video is rejected", ctx do
      attrs = %{tmp_path: ctx.source, content_type: "application/pdf", byte_size: 100}

      assert {:error, :unsupported_type} = Workshops.add_media(ctx.workshop, ctx.student, attrs)
    end
  end

  describe "list_media/1" do
    test "official media comes first, then the community ones", ctx do
      {:ok, _student_media} = Workshops.add_media(ctx.workshop, ctx.student, photo(ctx))
      {:ok, teacher_media} = Workshops.add_media(ctx.workshop, ctx.owner, photo(ctx))

      assert [first, monday] = Workshops.list_media(ctx.workshop.id)
      assert first.id == teacher_media.id
      assert first.official
      refute monday.official
    end

    test "deleted media disappears from the list", ctx do
      {:ok, media} = Workshops.add_media(ctx.workshop, ctx.student, photo(ctx))
      {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.student, media.id)

      assert Workshops.list_media(ctx.workshop.id) == []
    end
  end

  describe "remove_media/3" do
    test "uploader removes their own media and the file goes with it", ctx do
      {:ok, media} = Workshops.add_media(ctx.workshop, ctx.student, photo(ctx))
      {:file, path} = Workshops.serve_media(media)

      assert {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.student, media.id)
      refute File.exists?(path)
    end

    test "admin removes anyone's media", ctx do
      {:ok, media} = Workshops.add_media(ctx.workshop, ctx.student, photo(ctx))

      assert {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.owner, media.id)
    end

    test "co-organizer removes anyone's media too", ctx do
      partner = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.owner, partner.id)
      {:ok, media} = Workshops.add_media(ctx.workshop, ctx.student, photo(ctx))

      assert {:ok, _} = Workshops.remove_media(ctx.workshop, partner, media.id)
    end

    test "enrolled user does not remove another user's media", ctx do
      {:ok, media} = Workshops.add_media(ctx.workshop, ctx.student, photo(ctx))
      other = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, other)

      assert {:error, :unauthorized} = Workshops.remove_media(ctx.workshop, other, media.id)
    end

    test "media id from another workshop finds nothing", ctx do
      alheio = insert(:workshop, organizer: ctx.owner)
      {:ok, _} = Workshops.enroll(alheio, ctx.student)
      {:ok, de_la} = Workshops.add_media(alheio, ctx.student, photo(ctx))

      assert {:error, :not_found} = Workshops.remove_media(ctx.workshop, ctx.student, de_la.id)
    end

    test "made-up id does not crash", ctx do
      assert {:error, :not_found} =
               Workshops.remove_media(ctx.workshop, ctx.student, "nao-e-uuid")
    end
  end

  describe "quota per workshop" do
    @quota 2_147_483_648

    test "workshop at the limit rejects the next file with its own reason", ctx do
      {:ok, _quase_cheio} =
        Workshops.add_media(ctx.workshop, ctx.student, %{
          tmp_path: ctx.source,
          content_type: "image/png",
          byte_size: @quota - 100
        })

      assert {:error, :media_quota} =
               Workshops.add_media(ctx.workshop, ctx.student, %{
                 tmp_path: ctx.source,
                 content_type: "image/png",
                 byte_size: 200
               })
    end

    test "file that fits the quota exactly still goes in", ctx do
      {:ok, _} =
        Workshops.add_media(ctx.workshop, ctx.student, %{
          tmp_path: ctx.source,
          content_type: "image/png",
          byte_size: @quota - 100
        })

      assert {:ok, _} =
               Workshops.add_media(ctx.workshop, ctx.student, %{
                 tmp_path: ctx.source,
                 content_type: "image/png",
                 byte_size: 100
               })
    end

    test "quota is per workshop, not global", ctx do
      {:ok, _} =
        Workshops.add_media(ctx.workshop, ctx.student, %{
          tmp_path: ctx.source,
          content_type: "image/png",
          byte_size: @quota - 100
        })

      other = insert(:workshop, organizer: ctx.owner)
      {:ok, _} = Workshops.enroll(other, ctx.student)

      assert {:ok, _} = Workshops.add_media(other, ctx.student, photo(ctx))
    end

    test "deleted media gives the quota space back", ctx do
      {:ok, grande} =
        Workshops.add_media(ctx.workshop, ctx.student, %{
          tmp_path: ctx.source,
          content_type: "image/png",
          byte_size: @quota - 100
        })

      {:ok, _} = Workshops.remove_media(ctx.workshop, ctx.student, grande.id)

      assert {:ok, _} =
               Workshops.add_media(ctx.workshop, ctx.student, %{
                 tmp_path: ctx.source,
                 content_type: "image/png",
                 byte_size: 200
               })
    end
  end

  describe "media_usage/1" do
    test "conta arquivos e bytes", ctx do
      {:ok, _} = Workshops.add_media(ctx.workshop, ctx.student, photo(ctx))
      {:ok, _} = Workshops.add_media(ctx.workshop, ctx.owner, video_upload(ctx))

      uso = Workshops.media_usage(ctx.workshop.id)

      assert uso.count == 2
      assert uso.bytes > 5_000_000
    end

    test "workshop with no media reports zero", ctx do
      assert %{count: 0, bytes: 0} = Workshops.media_usage(ctx.workshop.id)
    end
  end
end
