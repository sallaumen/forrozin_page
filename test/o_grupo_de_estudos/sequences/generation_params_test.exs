defmodule OGrupoDeEstudos.Sequences.GenerationParamsTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Sequences.GenerationParams

  describe "from_raw/3" do
    test "defaults: sem loops, comprimento 10, 3 opções, 3 visitas ao BF" do
      params = GenerationParams.from_raw("BF", [], %{})

      assert params.start_code == "BF"
      assert params.required_codes == []
      assert params.allow_repeats == false
      assert params.cyclic == false
      assert params.length == 10
      assert params.count == 3
      assert params.max_bf_visits == 3
      assert params.max_same_pair_loops == 1
    end

    test "loop_mode light permite repetição, 2 loops por par e mínimo 8" do
      params = GenerationParams.from_raw("BF", [], %{"loop_mode" => "light", "length" => "5"})

      assert params.allow_repeats == true
      assert params.max_same_pair_loops == 2
      assert params.length == 8
    end

    test "loop_mode free usa 3 loops por par" do
      params = GenerationParams.from_raw("BF", [], %{"loop_mode" => "free"})

      assert params.max_same_pair_loops == 3
      assert params.allow_repeats == true
    end

    test "checkbox allow_repeats liga repetição mesmo sem loop_mode" do
      params = GenerationParams.from_raw("BF", [], %{"allow_repeats" => "on", "length" => "5"})

      assert params.allow_repeats == true
      assert params.length == 8
    end

    test "sem repetição o comprimento mínimo é 4" do
      params = GenerationParams.from_raw("BF", [], %{"length" => "2"})

      assert params.length == 4
    end

    test "inteiros inválidos caem nos defaults" do
      params =
        GenerationParams.from_raw("BF", [], %{
          "length" => "abc",
          "count" => "",
          "max_bf_visits" => "x"
        })

      assert params.length == 10
      assert params.count == 3
      assert params.max_bf_visits == 3
    end

    test "cyclic e required_codes são propagados" do
      params = GenerationParams.from_raw("BF", ["SC", "IV"], %{"cyclic" => "true"})

      assert params.cyclic == true
      assert params.required_codes == ["SC", "IV"]
    end
  end
end
