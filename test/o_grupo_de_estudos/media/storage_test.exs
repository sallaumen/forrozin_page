defmodule OGrupoDeEstudos.Media.StorageTest do
  # async: false — these tests toggle the global storage adapter via Application env.
  use ExUnit.Case, async: false

  import Mox

  alias OGrupoDeEstudos.Media.Storage

  # ── Default adapter (Local) — real, side-effect-free reads ─────────────

  describe "dir/1 (Local adapter)" do
    test "returns a path ending with the subdir" do
      path = Storage.dir("avatars")
      assert String.ends_with?(path, "/avatars")
    end
  end

  describe "avatar_exists?/2 (Local adapter)" do
    test "returns false for non-existent avatar" do
      refute Storage.avatar_exists?("non-existent-id", ".jpg")
    end
  end

  # ── Port dispatch — the facade delegates to the configured adapter ─────

  describe "adapter dispatch (port/adapter)" do
    setup :verify_on_exit!

    setup do
      Application.put_env(:o_grupo_de_estudos, Storage, adapter: Storage.Mock)
      on_exit(fn -> Application.delete_env(:o_grupo_de_estudos, Storage) end)
      :ok
    end

    test "save_avatar/3 delegates to the configured adapter and returns its url" do
      expect(Storage.Mock, :save_avatar, fn "u1", "/tmp/x.jpg", ".jpg" ->
        {:ok, "/uploads/avatars/u1_123.jpg"}
      end)

      assert Storage.save_avatar("u1", "/tmp/x.jpg", ".jpg") ==
               {:ok, "/uploads/avatars/u1_123.jpg"}
    end

    test "save_avatar/3 surfaces the adapter error tuple unchanged" do
      expect(Storage.Mock, :save_avatar, fn _, _, _ -> {:error, :processing_failed} end)

      assert Storage.save_avatar("u1", "/tmp/x.jpg", ".jpg") == {:error, :processing_failed}
    end

    test "delete_avatar/2 and avatar_exists?/2 delegate to the adapter" do
      expect(Storage.Mock, :delete_avatar, fn "u1", ".jpg" -> :ok end)
      expect(Storage.Mock, :avatar_exists?, fn "u1", ".jpg" -> true end)

      assert Storage.delete_avatar("u1", ".jpg") == :ok
      assert Storage.avatar_exists?("u1", ".jpg") == true
    end
  end
end
