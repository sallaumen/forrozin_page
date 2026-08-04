defmodule OGrupoDeEstudos.WorkshopFlyerTest do
  use OGrupoDeEstudos.DataCase, async: false

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    dir = Path.join(System.tmp_dir!(), "flyer_test_#{System.unique_integer([:positive])}")
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
    %{dir: dir, source: source, owner: owner, workshop: insert(:workshop, organizer: owner)}
  end

  defp disk_path(dir, "/uploads/" <> relativo), do: Path.join(dir, relativo)

  describe "put_workshop_flyer/4" do
    test "stores the file and points the column at it", ctx do
      assert {:ok, updated} =
               Workshops.put_workshop_flyer(ctx.workshop, ctx.owner, ctx.source, ".png")

      assert updated.flyer_path =~
               ~r{^/uploads/flyers/workshops/#{ctx.workshop.id}/[A-Za-z0-9]+\.png$}

      assert File.exists?(disk_path(ctx.dir, updated.flyer_path))
    end

    test "folder is scoped by workshop and the file name stays unguessable", ctx do
      {:ok, updated} = Workshops.put_workshop_flyer(ctx.workshop, ctx.owner, ctx.source, ".png")

      assert updated.flyer_path =~ "flyers/workshops/#{ctx.workshop.id}/"
      refute updated.flyer_path =~ ctx.owner.id
    end

    test "replacing the flyer deletes the previous file instead of piling up", ctx do
      {:ok, with_first} =
        Workshops.put_workshop_flyer(ctx.workshop, ctx.owner, ctx.source, ".png")

      first = disk_path(ctx.dir, with_first.flyer_path)

      {:ok, with_second} =
        Workshops.put_workshop_flyer(with_first, ctx.owner, ctx.source, ".png")

      refute File.exists?(first)
      assert File.exists?(disk_path(ctx.dir, with_second.flyer_path))
    end

    test "co-organizer also uploads a flyer", ctx do
      partner = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.owner, partner.id)

      assert {:ok, _} = Workshops.put_workshop_flyer(ctx.workshop, partner, ctx.source, ".png")
    end

    test "outsider does not upload a flyer to someone else's workshop", ctx do
      assert {:error, :unauthorized} =
               Workshops.put_workshop_flyer(ctx.workshop, insert(:user), ctx.source, ".png")
    end
  end

  describe "remove_workshop_flyer/2" do
    test "drops the reference and deletes the file", ctx do
      {:ok, with_flyer} =
        Workshops.put_workshop_flyer(ctx.workshop, ctx.owner, ctx.source, ".png")

      file = disk_path(ctx.dir, with_flyer.flyer_path)

      assert {:ok, without_flyer} = Workshops.remove_workshop_flyer(with_flyer, ctx.owner)

      assert is_nil(without_flyer.flyer_path)
      refute File.exists?(file)
    end

    test "removing a flyer that does not exist does not crash", ctx do
      assert {:ok, %{flyer_path: nil}} =
               Workshops.remove_workshop_flyer(ctx.workshop, ctx.owner)
    end

    test "outsider does not remove someone else's flyer", ctx do
      {:ok, with_flyer} =
        Workshops.put_workshop_flyer(ctx.workshop, ctx.owner, ctx.source, ".png")

      assert {:error, :unauthorized} =
               Workshops.remove_workshop_flyer(with_flyer, insert(:user))
    end
  end

  describe "program flyer" do
    setup %{owner: owner} do
      {:ok, program} = Workshops.create_program(owner, %{title: "Festival com cartaz"})
      %{program: program}
    end

    test "owner uploads and removes it", ctx do
      assert {:ok, with_flyer} =
               Workshops.put_program_flyer(ctx.program, ctx.owner, ctx.source, ".png")

      assert with_flyer.flyer_path =~ "/uploads/flyers/programas/#{ctx.program.id}/"
      file = disk_path(ctx.dir, with_flyer.flyer_path)
      assert File.exists?(file)

      assert {:ok, %{flyer_path: nil}} = Workshops.remove_program_flyer(with_flyer, ctx.owner)
      refute File.exists?(file)
    end

    test "outsider does not touch it", ctx do
      assert {:error, :unauthorized} =
               Workshops.put_program_flyer(ctx.program, insert(:user), ctx.source, ".png")
    end
  end
end
