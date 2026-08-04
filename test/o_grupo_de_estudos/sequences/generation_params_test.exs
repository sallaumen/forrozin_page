defmodule OGrupoDeEstudos.Sequences.GenerationParamsTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Sequences.GenerationParams

  describe "from_raw/3" do
    test "defaults to no loops, length 10, 3 options and 3 visits to the BF" do
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

    test "light loop_mode allows repeats, 2 loops per pair and a minimum of 8" do
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

    test "allow_repeats checkbox enables repeats even without loop_mode" do
      params = GenerationParams.from_raw("BF", [], %{"allow_repeats" => "on", "length" => "5"})

      assert params.allow_repeats == true
      assert params.length == 8
    end

    test "minimum length is 4 without repeats" do
      params = GenerationParams.from_raw("BF", [], %{"length" => "2"})

      assert params.length == 4
    end

    test "invalid integers fall back to the defaults" do
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

    test "propagates cyclic and required_codes" do
      params = GenerationParams.from_raw("BF", ["SC", "IV"], %{"cyclic" => "true"})

      assert params.cyclic == true
      assert params.required_codes == ["SC", "IV"]
    end
  end
end
