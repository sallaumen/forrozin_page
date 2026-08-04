defmodule OGrupoDeEstudos.Media.ObjectStorageTest do
  @moduledoc """
  The byte port: stores, serves and deletes objects by opaque key. It is the
  only layer that knows where the bytes live.
  """

  use ExUnit.Case, async: false

  import Mox

  alias OGrupoDeEstudos.Media.ObjectStorage
  alias OGrupoDeEstudos.Media.ObjectStorage.LocalDisk

  setup do
    dir = Path.join(System.tmp_dir!(), "object_storage_#{System.unique_integer([:positive])}")
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

    source = Path.join(dir, "origem.bin")
    File.write!(source, "conteudo de teste")

    %{dir: dir, source: source}
  end

  describe "LocalDisk.put/2" do
    test "writes the bytes at the key, creating the path folders", ctx do
      assert :ok = LocalDisk.put("avatars/u1_99.jpg", ctx.source)

      assert File.read!(Path.join(ctx.dir, "avatars/u1_99.jpg")) == "conteudo de teste"
    end

    test "missing source returns an error instead of raising", _ctx do
      assert {:error, _reason} = LocalDisk.put("avatars/x.jpg", "/nao/existe.bin")
    end
  end

  describe "LocalDisk.delete/1" do
    test "deletes the object", ctx do
      :ok = LocalDisk.put("flyers/a.jpg", ctx.source)

      assert :ok = LocalDisk.delete("flyers/a.jpg")
      refute File.exists?(Path.join(ctx.dir, "flyers/a.jpg"))
    end

    test "deleting what is already gone is silent", _ctx do
      assert :ok = LocalDisk.delete("flyers/sumiu.jpg")
    end
  end

  describe "LocalDisk.exists?/1 e list/1" do
    test "sees what it stored", ctx do
      :ok = LocalDisk.put("avatars/u1_1.jpg", ctx.source)
      :ok = LocalDisk.put("avatars/u1_2.jpg", ctx.source)
      :ok = LocalDisk.put("avatars/u2_1.jpg", ctx.source)

      assert LocalDisk.exists?("avatars/u1_1.jpg")
      refute LocalDisk.exists?("avatars/u9_9.jpg")

      assert Enum.sort(LocalDisk.list("avatars/u1_")) == ["avatars/u1_1.jpg", "avatars/u1_2.jpg"]
      assert LocalDisk.list("workshop_media/") == []
    end

    test "list walks subfolders and returns only files, like a bucket", ctx do
      :ok = LocalDisk.put("workshop_media/w1/a.mp4", ctx.source)
      :ok = LocalDisk.put("workshop_media/w2/b.mp4", ctx.source)

      assert Enum.sort(LocalDisk.list("workshop_media/")) ==
               ["workshop_media/w1/a.mp4", "workshop_media/w2/b.mp4"]

      assert LocalDisk.list("workshop_media/w1/") == ["workshop_media/w1/a.mp4"]
    end
  end

  describe "LocalDisk.public_url/1" do
    test "public URL is the path served by UploadsStatic" do
      assert LocalDisk.public_url("avatars/u1.jpg") == "/uploads/avatars/u1.jpg"
    end
  end

  describe "LocalDisk.serve/1" do
    test "local object is served as a file, for the controller send_file", ctx do
      :ok = LocalDisk.put("workshop_media/v.mp4", ctx.source)

      assert {:file, path} = LocalDisk.serve("workshop_media/v.mp4")
      assert File.read!(path) == "conteudo de teste"
    end

    test "key with no object returns not_found", _ctx do
      assert {:error, :not_found} = LocalDisk.serve("workshop_media/fantasma.mp4")
    end
  end

  describe "LocalDisk.with_local_file/2" do
    test "hands a readable path to whoever processes it (ffmpeg, Mogrify)", ctx do
      :ok = LocalDisk.put("workshop_media/v.mov", ctx.source)

      assert {:ok, "CONTEUDO DE TESTE"} =
               LocalDisk.with_local_file("workshop_media/v.mov", fn path ->
                 path |> File.read!() |> String.upcase()
               end)
    end

    test "key with no object returns not_found without running the function", _ctx do
      assert {:error, :not_found} =
               LocalDisk.with_local_file("workshop_media/nada.mov", fn _ ->
                 flunk("não era para rodar")
               end)
    end
  end

  describe "LocalDisk.free_bytes/0" do
    test "measures the free space of the uploads volume", _ctx do
      assert is_integer(LocalDisk.free_bytes()) and LocalDisk.free_bytes() > 0
    end
  end

  describe "facade delegates to the configured adapter" do
    setup :verify_on_exit!

    setup do
      Application.put_env(:o_grupo_de_estudos, ObjectStorage, adapter: ObjectStorage.Mock)
      on_exit(fn -> Application.delete_env(:o_grupo_de_estudos, ObjectStorage) end)
      :ok
    end

    test "put and serve go through the adapter with the return value intact" do
      expect(ObjectStorage.Mock, :put, fn "k/a.bin", "/tmp/a" -> :ok end)
      expect(ObjectStorage.Mock, :serve, fn "k/a.bin" -> {:redirect, "https://cdn/a.bin"} end)

      assert ObjectStorage.put("k/a.bin", "/tmp/a") == :ok
      assert ObjectStorage.serve("k/a.bin") == {:redirect, "https://cdn/a.bin"}
    end

    test "falls back to the local disk with no configuration at all" do
      Application.delete_env(:o_grupo_de_estudos, ObjectStorage)

      assert ObjectStorage.public_url("x/y.png") == "/uploads/x/y.png"
    end
  end
end
