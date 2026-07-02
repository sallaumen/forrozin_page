defmodule OGrupoDeEstudos.Suggestions.SuggestionTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Suggestions.Suggestion

  describe "suggestible_fields/0" do
    test "exposes exactly the fields users can suggest edits for" do
      assert Suggestion.suggestible_fields() == ~w(name note category_id)
    end
  end

  describe "field_atom/1" do
    test "converts every suggestible field to its atom" do
      for field <- Suggestion.suggestible_fields() do
        assert {:ok, atom} = Suggestion.field_atom(field)
        assert Atom.to_string(atom) == field
      end
    end

    test "returns :error for any field outside the whitelist" do
      for field <- ~w(password_hash id wip deleted_at inserted_at bogus) ++ [""] do
        assert :error = Suggestion.field_atom(field)
      end
    end
  end
end
