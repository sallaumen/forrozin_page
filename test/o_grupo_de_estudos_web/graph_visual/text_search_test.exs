defmodule OGrupoDeEstudosWeb.GraphVisual.TextSearchTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.GraphVisual.TextSearch

  describe "normalize/1" do
    test "nil normalizes to empty string" do
      assert TextSearch.normalize(nil) == ""
    end

    test "empty string stays empty" do
      assert TextSearch.normalize("") == ""
    end

    test "strips diacritics via NFD decomposition and downcases" do
      assert TextSearch.normalize("Inversão") == "inversao"
    end

    test "downcases ASCII and preserves spacing" do
      assert TextSearch.normalize("BASE Fundamental") == "base fundamental"
    end

    test "strips multiple accent forms together" do
      assert TextSearch.normalize("Coração é Légàl ÇÃO") == "coracao e legal cao"
    end

    test "coerces non-string input via to_string" do
      assert TextSearch.normalize(42) == "42"
    end
  end
end
