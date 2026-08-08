defmodule OGrupoDeEstudosWeb.Helpers.PluralTest do
  use ExUnit.Case, async: true

  import OGrupoDeEstudosWeb.Helpers.Plural

  describe "plural/3" do
    test "one takes the singular" do
      assert plural(1, "passo", "passos") == "1 passo"
    end

    test "zero takes the plural, as portuguese does" do
      assert plural(0, "passo", "passos") == "0 passos"
    end

    test "many take the plural" do
      assert plural(7, "resultado", "resultados") == "7 resultados"
    end

    test "whole phrases agree along" do
      assert plural(1, "passo sugerido por você", "passos sugeridos por você") ==
               "1 passo sugerido por você"

      assert plural(3, "passo sugerido por você", "passos sugeridos por você") ==
               "3 passos sugeridos por você"
    end
  end
end
