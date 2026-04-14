defmodule Forrozin.Encyclopedia.SectionTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Encyclopedia.Section

  describe "changeset/2" do
    test "válido com campos obrigatórios" do
      category = insert(:category)
      attrs = %{title: "Bases", position: 1, category_id: category.id}
      assert %{valid?: true} = Section.changeset(%Section{}, attrs)
    end

    test "válido sem num e sem codigo (seções de convenções e conceitos)" do
      category = insert(:category)
      attrs = %{title: "Convenções", position: 0, category_id: category.id}
      assert %{valid?: true} = Section.changeset(%Section{}, attrs)
    end

    test "inválido sem título" do
      category = insert(:category)
      attrs = %{position: 1, category_id: category.id}
      changeset = Section.changeset(%Section{}, attrs)
      assert "can't be blank" in errors_on(changeset).title
    end

    test "inválido sem posição" do
      category = insert(:category)
      attrs = %{title: "Bases", category_id: category.id}
      changeset = Section.changeset(%Section{}, attrs)
      assert "can't be blank" in errors_on(changeset).position
    end
  end
end
