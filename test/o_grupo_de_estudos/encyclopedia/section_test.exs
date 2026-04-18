defmodule OGrupoDeEstudos.Encyclopedia.SectionTest do
  use OGrupoDeEstudos.DataCase, async: false

  alias OGrupoDeEstudos.Encyclopedia.Section

  describe "changeset/2" do
    test "valid with required fields" do
      category = insert(:category)
      attrs = %{title: "Bases", position: 1, category_id: category.id}
      assert %{valid?: true} = Section.changeset(%Section{}, attrs)
    end

    test "valid without num and code (convention and concept sections)" do
      category = insert(:category)
      attrs = %{title: "Convenções", position: 0, category_id: category.id}
      assert %{valid?: true} = Section.changeset(%Section{}, attrs)
    end

    test "invalid without title" do
      category = insert(:category)
      attrs = %{position: 1, category_id: category.id}
      changeset = Section.changeset(%Section{}, attrs)
      assert "can't be blank" in errors_on(changeset).title
    end

    test "invalid without position" do
      category = insert(:category)
      attrs = %{title: "Bases", category_id: category.id}
      changeset = Section.changeset(%Section{}, attrs)
      assert "can't be blank" in errors_on(changeset).position
    end
  end
end
