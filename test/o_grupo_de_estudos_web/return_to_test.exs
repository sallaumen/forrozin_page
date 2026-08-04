defmodule OGrupoDeEstudosWeb.ReturnToTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.ReturnTo

  describe "safe_path/1" do
    test "keeps an internal path" do
      assert ReturnTo.safe_path("/workshops/forro-em-curitiba") ==
               "/workshops/forro-em-curitiba"
    end

    test "keeps an internal path with a query string" do
      assert ReturnTo.safe_path("/workshops/forro?tab=fotos") == "/workshops/forro?tab=fotos"
    end

    test "rejects an absolute url" do
      assert ReturnTo.safe_path("https://evil.com/phishing") == nil
    end

    test "rejects a protocol-relative url" do
      assert ReturnTo.safe_path("//evil.com") == nil
    end

    test "rejects a backslash-escaped url" do
      assert ReturnTo.safe_path("/\\evil.com") == nil
    end

    test "rejects a path that does not start with a slash" do
      assert ReturnTo.safe_path("collection") == nil
    end

    test "rejects nil and blank values" do
      assert ReturnTo.safe_path(nil) == nil
      assert ReturnTo.safe_path("") == nil
      assert ReturnTo.safe_path("   ") == nil
    end
  end

  describe "safe_path/2" do
    test "falls back to the default when the value is unsafe" do
      assert ReturnTo.safe_path("https://evil.com", "/collection") == "/collection"
    end

    test "keeps the internal path over the default" do
      assert ReturnTo.safe_path("/workshops/forro", "/collection") == "/workshops/forro"
    end
  end
end
