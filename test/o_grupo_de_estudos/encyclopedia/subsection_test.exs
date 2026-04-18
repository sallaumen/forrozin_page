defmodule OGrupoDeEstudos.Encyclopedia.SubsectionTest do
  use OGrupoDeEstudos.DataCase, async: false

  alias OGrupoDeEstudos.Encyclopedia.Subsection

  describe "changeset/2" do
    test "valid with required fields" do
      section = insert(:section)
      attrs = %{title: "Entradas no GP", position: 0, section_id: section.id}
      assert %{valid?: true} = Subsection.changeset(%Subsection{}, attrs)
    end

    test "invalid without title" do
      section = insert(:section)
      attrs = %{position: 0, section_id: section.id}
      changeset = Subsection.changeset(%Subsection{}, attrs)
      assert "can't be blank" in errors_on(changeset).title
    end

    test "invalid without section_id" do
      attrs = %{title: "Entradas no GP", position: 0}
      changeset = Subsection.changeset(%Subsection{}, attrs)
      assert "can't be blank" in errors_on(changeset).section_id
    end
  end
end
