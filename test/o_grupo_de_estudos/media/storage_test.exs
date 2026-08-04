defmodule OGrupoDeEstudos.Media.StorageTest do
  @moduledoc """
  The media service: naming policy plus image processing. The bytes live
  behind `Media.ObjectStorage`; what stays here is what does not change when
  the provider changes.
  """

  # async: false because the test swaps :uploads_path in the global app env.
  use ExUnit.Case, async: false

  alias OGrupoDeEstudos.Media.ObjectStorage
  alias OGrupoDeEstudos.Media.Storage

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    dir = Path.join(System.tmp_dir!(), "storage_svc_#{System.unique_integer([:positive])}")
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

    %{dir: dir, source: source}
  end

  describe "save_avatar/3" do
    test "each user has their own folder, with a timestamp in the name to bust caches", ctx do
      assert {:ok, url} = Storage.save_avatar("u1", ctx.source, ".png")

      assert url =~ ~r|^/uploads/avatars/u1/\d+\.png$|
      assert ObjectStorage.exists?(String.replace_prefix(url, "/uploads/", ""))
    end

    test "replacing the avatar deletes the previous version", ctx do
      {:ok, url1} = Storage.save_avatar("u1", ctx.source, ".png")
      Process.sleep(1100)
      File.write!(ctx.source, @png)
      {:ok, url2} = Storage.save_avatar("u1", ctx.source, ".png")

      assert url1 != url2
      refute ObjectStorage.exists?(String.replace_prefix(url1, "/uploads/", ""))
      assert ObjectStorage.exists?(String.replace_prefix(url2, "/uploads/", ""))
    end

    test "leaves the avatars of other users alone", ctx do
      {:ok, other_user_avatar} = Storage.save_avatar("u2", ctx.source, ".png")
      File.write!(ctx.source, @png)
      {:ok, _} = Storage.save_avatar("u1", ctx.source, ".png")

      assert ObjectStorage.exists?(String.replace_prefix(other_user_avatar, "/uploads/", ""))
    end
  end

  describe "save_image/3" do
    test "folder belongs to the caller and the file name is random", ctx do
      assert {:ok, url} = Storage.save_image("flyers/workshops/w1", ctx.source, ".png")

      assert url =~ ~r|^/uploads/flyers/workshops/w1/[A-Za-z0-9]+\.png$|
      refute url =~ "origem"
    end

    test "delete_image/1 deletes by public URL", ctx do
      {:ok, url} = Storage.save_image("flyers", ctx.source, ".png")

      assert :ok = Storage.delete_image(url)
      refute ObjectStorage.exists?(String.replace_prefix(url, "/uploads/", ""))
    end

    test "delete_image/1 does nothing for an external URL", _ctx do
      assert :ok = Storage.delete_image("https://outro-site.com/x.png")
    end
  end

  describe "arquivos privados" do
    test "put_private/3 returns an opaque key, never a URL", ctx do
      assert {:ok, key} = Storage.put_private("workshop_media", ctx.source, ".mp4")

      assert key =~ ~r|^workshop_media/[A-Za-z0-9]+\.mp4$|
      assert ObjectStorage.exists?(key)
    end

    test "serve_private/1 hands the file to the controller send_file", ctx do
      {:ok, key} = Storage.put_private("workshop_media", ctx.source, ".mp4")

      assert {:file, path} = Storage.serve_private(key)
      assert File.read!(path) == @png
    end

    test "serve_private/1 returns not_found for a key with no object", _ctx do
      assert {:error, :not_found} = Storage.serve_private("workshop_media/sumiu.mp4")
    end

    test "with_private_file/2 gives a local path for ffmpeg to read", ctx do
      {:ok, key} = Storage.put_private("workshop_media", ctx.source, ".mov")

      assert {:ok, size} = Storage.with_private_file(key, fn c -> File.stat!(c).size end)
      assert size == byte_size(@png)
    end

    test "delete_private/1 deletes and stays silent the second time", ctx do
      {:ok, key} = Storage.put_private("workshop_media", ctx.source, ".mp4")

      assert :ok = Storage.delete_private(key)
      assert :ok = Storage.delete_private(key)
      refute ObjectStorage.exists?(key)
    end
  end

  describe "free_bytes/0" do
    test "returns a number or :unknown, never raises" do
      assert is_integer(Storage.free_bytes()) or Storage.free_bytes() == :unknown
    end
  end
end
