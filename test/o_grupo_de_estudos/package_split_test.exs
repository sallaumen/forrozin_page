defmodule OGrupoDeEstudos.PackageSplitTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Workshops.PackageSplit

  describe "shares/2" do
    test "splits the package evenly when the workshops cost the same" do
      shares = PackageSplit.shares(9000, [{"a", 5000}, {"b", 5000}])

      assert shares == %{"a" => 4500, "b" => 4500}
    end

    test "gives the pricier workshop the bigger slice" do
      shares = PackageSplit.shares(12_000, [{"a", 5000}, {"b", 7000}])

      assert shares == %{"a" => 5000, "b" => 7000}
    end

    test "the slices always add up to exactly what was paid" do
      shares = PackageSplit.shares(10_000, [{"a", 5000}, {"b", 5000}, {"c", 5000}])

      assert shares |> Map.values() |> Enum.sum() == 10_000
      assert Enum.sort(Map.values(shares)) == [3333, 3333, 3334]
    end

    test "the leftover cent goes to the same workshop every time" do
      workshops = [{"a", 5000}, {"b", 5000}, {"c", 5000}]

      assert PackageSplit.shares(10_000, workshops) ==
               PackageSplit.shares(10_000, Enum.reverse(workshops))
    end

    test "splits evenly when no workshop has a price" do
      shares = PackageSplit.shares(9000, [{"a", nil}, {"b", 0}])

      assert shares == %{"a" => 4500, "b" => 4500}
    end

    test "a free package attributes nothing" do
      assert PackageSplit.shares(0, [{"a", 5000}]) == %{"a" => 0}
      assert PackageSplit.shares(nil, [{"a", 5000}]) == %{"a" => 0}
    end

    test "no workshops, nothing to split" do
      assert PackageSplit.shares(9000, []) == %{}
    end

    test "the whole package lands on the single workshop it covers" do
      assert PackageSplit.shares(9000, [{"a", 5000}]) == %{"a" => 9000}
    end
  end
end
