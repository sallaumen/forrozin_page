defmodule Forrozin.Encyclopedia.SubsectionTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Encyclopedia.Subsection

  describe "changeset/2" do
    test "válido com campos obrigatórios" do
      section = insert(:section)
      attrs = %{title: "Entradas no GP", position: 0, section_id: section.id}
      assert %{valid?: true} = Subsection.changeset(%Subsection{}, attrs)
    end

    test "inválido sem título" do
      section = insert(:section)
      attrs = %{position: 0, section_id: section.id}
      changeset = Subsection.changeset(%Subsection{}, attrs)
      assert "can't be blank" in errors_on(changeset).title
    end

    test "inválido sem section_id" do
      attrs = %{title: "Entradas no GP", position: 0}
      changeset = Subsection.changeset(%Subsection{}, attrs)
      assert "can't be blank" in errors_on(changeset).section_id
    end
  end
end
