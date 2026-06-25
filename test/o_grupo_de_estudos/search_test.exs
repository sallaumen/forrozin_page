defmodule OGrupoDeEstudos.SearchTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Search

  describe "escape_like/1" do
    test "escapes percent wildcard" do
      assert Search.escape_like("a%b") == "a\\%b"
    end

    test "escapes underscore wildcard" do
      assert Search.escape_like("a_b") == "a\\_b"
    end

    test "escapes backslash first (so other escapes are not doubled)" do
      assert Search.escape_like("a\\b") == "a\\\\b"
    end

    test "leaves normal text unchanged" do
      assert Search.escape_like("forro roots") == "forro roots"
    end
  end
end
