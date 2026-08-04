defmodule OGrupoDeEstudos.WorkshopAddressTest do
  @moduledoc """
  Where the class happens, in parts instead of one free line.

  A single field turned into "Telhado do Tatá — R. Dr. Alexandre Gutierrez", which
  reads fine to whoever wrote it and tells nobody else the city, the number, or how
  to open it in a map. The parts are separate now, and the display puts them back
  together.
  """

  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Workshops.Workshop

  defp workshop(fields), do: struct(%Workshop{}, fields)

  describe "the line that says where it is" do
    test "the place and the city, which is what a card has room for" do
      place = workshop(%{location: "Telhado do Tatá", city: "Curitiba", state: "PR"})

      assert Workshop.place_line(place) == "Telhado do Tatá · Curitiba, PR"
    end

    test "no place name falls back to the city" do
      assert Workshop.place_line(workshop(%{city: "Curitiba", state: "PR"})) == "Curitiba, PR"
    end

    test "a city without a state does not trail a comma" do
      assert Workshop.place_line(workshop(%{location: "Sesc", city: "Curitiba"})) ==
               "Sesc · Curitiba"
    end

    test "written before the split, the old free text still shows" do
      old = workshop(%{location: "Telhado do Tatá — R. Dr. Alexandre Gutierrez"})

      assert Workshop.place_line(old) == "Telhado do Tatá — R. Dr. Alexandre Gutierrez"
    end

    test "nothing at all says nothing, instead of leftover punctuation" do
      assert Workshop.place_line(workshop(%{})) == nil
    end
  end

  describe "the full address, for whoever has to get there" do
    test "street, number and complement come on the first line" do
      full =
        workshop(%{
          street: "R. Dr. Alexandre Gutierrez",
          street_number: "480",
          complement: "casa 2",
          neighborhood: "Água Verde",
          city: "Curitiba",
          state: "PR",
          postal_code: "80240-090"
        })

      assert Workshop.address_line(full) ==
               "R. Dr. Alexandre Gutierrez, 480, casa 2 · Água Verde · Curitiba, PR · 80240-090"
    end

    test "the parts nobody filled simply do not show" do
      partial = workshop(%{street: "R. XV de Novembro", city: "Curitiba", state: "PR"})

      assert Workshop.address_line(partial) == "R. XV de Novembro · Curitiba, PR"
    end

    test "a street with no number does not trail a comma" do
      assert Workshop.address_line(workshop(%{street: "R. XV de Novembro"})) ==
               "R. XV de Novembro"
    end

    test "only the place name means there is no address to show" do
      assert Workshop.address_line(workshop(%{location: "Telhado do Tatá"})) == nil
    end
  end

  describe "what the changeset accepts" do
    defp changeset_for(fields) do
      Workshop.changeset(
        %Workshop{},
        Map.merge(
          %{
            title: "Workshop",
            description: "Conteúdo.",
            starts_at: DateTime.utc_now() |> DateTime.truncate(:second),
            organizer_id: Ecto.UUID.generate()
          },
          fields
        )
      )
    end

    test "the address fields go in" do
      changeset = changeset_for(%{street: "R. XV", street_number: "100", city: "Curitiba"})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :street) == "R. XV"
      assert Ecto.Changeset.get_change(changeset, :city) == "Curitiba"
    end

    test "spaces around what was typed are trimmed" do
      changeset = changeset_for(%{street: "  R. XV  ", city: " Curitiba "})

      assert Ecto.Changeset.get_change(changeset, :street) == "R. XV"
      assert Ecto.Changeset.get_change(changeset, :city) == "Curitiba"
    end

    test "the state is stored uppercase, however it was typed" do
      changeset = changeset_for(%{state: "pr"})

      assert Ecto.Changeset.get_change(changeset, :state) == "PR"
    end

    test "a state that is not a Brazilian one is refused" do
      refute changeset_for(%{state: "XX"}).valid?
    end

    test "an empty state is not an error, since the field is optional" do
      assert changeset_for(%{state: ""}).valid?
    end
  end
end
