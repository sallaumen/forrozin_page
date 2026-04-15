defmodule OGrupoDeEstudos.Encyclopedia.StepQueryTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Encyclopedia.StepQuery

  # ---------------------------------------------------------------------------
  # get_by/1
  # ---------------------------------------------------------------------------

  describe "get_by/1 with :code" do
    test "returns the step with the given code" do
      insert(:step, code: "BF", name: "Base frontal")

      assert %{code: "BF"} = StepQuery.get_by(code: "BF")
    end

    test "returns nil when code does not exist" do
      assert nil == StepQuery.get_by(code: "INEXISTENTE")
    end
  end

  describe "get_by/1 with :public_only" do
    test "returns nil for wip steps" do
      insert(:step, code: "HF-SRS", name: "Sacada Rotativa Suspensa", wip: true)

      assert nil == StepQuery.get_by(code: "HF-SRS", public_only: true)
    end

    test "returns nil for draft steps" do
      insert(:step, code: "BQ", name: "Base quadrada", status: "draft")

      assert nil == StepQuery.get_by(code: "BQ", public_only: true)
    end

    test "returns step when public" do
      insert(:step, code: "BF", name: "Base frontal", wip: false, status: "published")

      assert %{code: "BF"} = StepQuery.get_by(code: "BF", public_only: true)
    end
  end

  describe "get_by/1 with :preload" do
    test "preloads the requested associations" do
      cat = insert(:category)
      insert(:step, code: "BF", name: "Base frontal", category: cat)

      result = StepQuery.get_by(code: "BF", preload: [:category])

      assert result.category.id == cat.id
    end
  end

  # ---------------------------------------------------------------------------
  # list_by/1
  # ---------------------------------------------------------------------------

  describe "list_by/1 defaults" do
    test "returns steps ordered by name by default" do
      insert(:step, code: "SC-TEST", name: "Zzz sacada teste")
      insert(:step, code: "BF-TEST", name: "Aaa base teste")

      results = StepQuery.list_by()
      names = Enum.map(results, & &1.name)

      aaa_pos = Enum.find_index(names, &(&1 == "Aaa base teste"))
      zzz_pos = Enum.find_index(names, &(&1 == "Zzz sacada teste"))

      assert aaa_pos < zzz_pos
    end
  end

  describe "list_by/1 with :status" do
    test "filters by status" do
      insert(:step, code: "BF", name: "Base frontal", status: "published")
      insert(:step, code: "BQ", name: "Base quadrada", status: "draft")

      results = StepQuery.list_by(status: "published")
      codes = Enum.map(results, & &1.code)

      assert "BF" in codes
      refute "BQ" in codes
    end
  end

  describe "list_by/1 with :wip" do
    test "filters to only wip steps" do
      insert(:step, code: "BF", name: "Base frontal", wip: false)
      insert(:step, code: "HF-SRS", name: "Sacada Rotativa Suspensa", wip: true)

      results = StepQuery.list_by(wip: true)
      codes = Enum.map(results, & &1.code)

      refute "BF" in codes
      assert "HF-SRS" in codes
    end

    test "filters to only non-wip steps" do
      insert(:step, code: "BF", name: "Base frontal", wip: false)
      insert(:step, code: "HF-SRS", name: "Sacada Rotativa Suspensa", wip: true)

      results = StepQuery.list_by(wip: false)
      codes = Enum.map(results, & &1.code)

      assert "BF" in codes
      refute "HF-SRS" in codes
    end
  end

  describe "list_by/1 with :public_only" do
    test "excludes wip and draft steps" do
      insert(:step, code: "BF", name: "Base frontal", wip: false, status: "published")

      insert(:step,
        code: "HF-SRS",
        name: "Sacada Rotativa Suspensa",
        wip: true,
        status: "published"
      )

      insert(:step, code: "BQ", name: "Base quadrada", wip: false, status: "draft")

      results = StepQuery.list_by(public_only: true)
      codes = Enum.map(results, & &1.code)

      assert "BF" in codes
      refute "HF-SRS" in codes
      refute "BQ" in codes
    end
  end

  describe "list_by/1 with :search" do
    test "finds steps by partial code match (case-insensitive)" do
      insert(:step, code: "BF", name: "Base frontal")
      insert(:step, code: "SC", name: "Sacada simples")

      results = StepQuery.list_by(search: "bf")
      codes = Enum.map(results, & &1.code)

      assert "BF" in codes
      refute "SC" in codes
    end

    test "finds steps by partial name match (case-insensitive)" do
      insert(:step, code: "BF", name: "Base frontal")
      insert(:step, code: "BQ", name: "Base quadrada")
      insert(:step, code: "SC", name: "Sacada simples")

      results = StepQuery.list_by(search: "BASE")
      codes = Enum.map(results, & &1.code)

      assert "BF" in codes
      assert "BQ" in codes
      refute "SC" in codes
    end

    test "returns empty list when no match" do
      insert(:step, code: "BF", name: "Base frontal")

      assert StepQuery.list_by(search: "xyzzyqwerty") == []
    end
  end

  describe "list_by/1 with :suggested_by_id" do
    test "returns only steps suggested by the given user" do
      user = insert(:user)
      insert(:step, code: "BF", name: "Base frontal", suggested_by: user)
      insert(:step, code: "SC", name: "Sacada simples")

      results = StepQuery.list_by(suggested_by_id: user.id)
      codes = Enum.map(results, & &1.code)

      assert "BF" in codes
      refute "SC" in codes
    end
  end

  describe "list_by/1 with :has_suggestions" do
    test "returns only steps that have a suggested_by_id" do
      user = insert(:user)
      insert(:step, code: "BF", name: "Base frontal", suggested_by: user)
      insert(:step, code: "SC", name: "Sacada simples")

      results = StepQuery.list_by(has_suggestions: true)
      codes = Enum.map(results, & &1.code)

      assert "BF" in codes
      refute "SC" in codes
    end
  end

  describe "list_by/1 with :limit" do
    test "limits the number of results" do
      for i <- 1..5, do: insert(:step, code: "P#{i}", name: "Passo #{i}")

      results = StepQuery.list_by(limit: 3)

      assert [_, _, _] = results
    end
  end

  describe "list_by/1 with :order_by" do
    test "orders by the given field descending" do
      insert(:step, code: "SC-TEST2", name: "Zzz sacada teste2")
      insert(:step, code: "BF-TEST2", name: "Aaa base teste2")

      results = StepQuery.list_by(order_by: [desc: :name])
      names = Enum.map(results, & &1.name)

      zzz_pos = Enum.find_index(names, &(&1 == "Zzz sacada teste2"))
      aaa_pos = Enum.find_index(names, &(&1 == "Aaa base teste2"))

      assert zzz_pos < aaa_pos
    end
  end

  describe "list_by/1 with :preload" do
    test "preloads the requested associations" do
      cat = insert(:category)
      insert(:step, code: "BF", name: "Base frontal", category: cat)

      [result] = StepQuery.list_by(code: "BF", preload: [:category])

      assert result.category.id == cat.id
    end
  end

  # ---------------------------------------------------------------------------
  # count_by/1
  # ---------------------------------------------------------------------------

  describe "count_by/1" do
    test "counts at least the steps we just inserted" do
      initial = StepQuery.count_by()
      insert(:step, code: "BF-CNT1")
      insert(:step, code: "SC-CNT1")

      assert StepQuery.count_by() == initial + 2
    end

    test "counts only public steps with :public_only" do
      initial = StepQuery.count_by(public_only: true)
      insert(:step, code: "BF-CNT2", wip: false, status: "published")
      insert(:step, code: "HF-CNT2", wip: true, status: "published")

      assert StepQuery.count_by(public_only: true) == initial + 1
    end
  end
end
