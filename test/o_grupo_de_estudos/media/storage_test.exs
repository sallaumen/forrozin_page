defmodule OGrupoDeEstudos.Media.StorageTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Media.Storage

  describe "dir/1" do
    test "returns a path ending with the subdir" do
      path = Storage.dir("avatars")
      assert String.ends_with?(path, "/avatars")
    end
  end

  describe "avatar_exists?/2" do
    test "returns false for non-existent avatar" do
      refute Storage.avatar_exists?("non-existent-id", ".jpg")
    end
  end
end
