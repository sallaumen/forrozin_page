defmodule Forrozin.Encyclopedia.SectionQueryTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Encyclopedia.SectionQuery

  # ---------------------------------------------------------------------------
  # get_by/1
  # ---------------------------------------------------------------------------

  describe "get_by/1 with :id" do
    test "returns the section with the given id" do
      section = insert(:section, title: "Sacadas")

      assert %{title: "Sacadas"} = SectionQuery.get_by(id: section.id)
    end

    test "returns nil when id does not exist" do
      assert nil == SectionQuery.get_by(id: Ecto.UUID.generate())
    end
  end

  describe "get_by/1 with :preload" do
    test "preloads the requested associations" do
      cat = insert(:category)
      section = insert(:section, category: cat)

      result = SectionQuery.get_by(id: section.id, preload: [:category])

      assert result.category.id == cat.id
    end
  end

  # ---------------------------------------------------------------------------
  # list_by/1
  # ---------------------------------------------------------------------------

  describe "list_by/1 defaults" do
    test "returns all sections ordered by position" do
      insert(:section, title: "Sacadas", position: 3)
      insert(:section, title: "Bases", position: 1)
      insert(:section, title: "Giros", position: 2)

      titles = SectionQuery.list_by() |> Enum.map(& &1.title)

      assert titles == ["Bases", "Giros", "Sacadas"]
    end

    test "returns empty list when no sections" do
      assert SectionQuery.list_by() == []
    end
  end

  describe "list_by/1 with :order_by" do
    test "orders by the given field" do
      insert(:section, title: "Sacadas", position: 1)
      insert(:section, title: "Bases", position: 2)

      titles = SectionQuery.list_by(order_by: [asc: :title]) |> Enum.map(& &1.title)

      assert titles == ["Bases", "Sacadas"]
    end
  end

  describe "list_by/1 with :preload" do
    test "preloads the requested associations" do
      cat = insert(:category)
      insert(:section, category: cat)

      [result] = SectionQuery.list_by(preload: [:category])

      assert result.category.id == cat.id
    end
  end
end
