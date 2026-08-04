defmodule OGrupoDeEstudos.WorkshopDurationTest do
  @moduledoc """
  How long the class runs, instead of when it ends.

  Typing the date twice to say a two-hour workshop is busywork: the second date is
  almost always the same day as the first. The form asks for the duration and the
  schema turns it into the `ends_at` that queries and the page already read.
  """

  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Workshops
  alias OGrupoDeEstudos.Workshops.Workshop

  defp at(hour, minute \\ 0) do
    ~D[2026-09-12]
    |> DateTime.new!(Time.new!(hour, minute, 0), "Etc/UTC")
    |> DateTime.truncate(:second)
  end

  defp attrs(overrides) do
    Map.merge(
      %{
        title: "Workshop de sacadas",
        description: "Conteúdo.",
        starts_at: at(19),
        organizer_id: Ecto.UUID.generate()
      },
      overrides
    )
  end

  defp changeset_for(overrides), do: Workshop.changeset(%Workshop{}, attrs(overrides))

  describe "turning a duration into an end" do
    test "two hours after a 19h start ends at 21h" do
      changeset = changeset_for(%{duration_minutes: 120})

      assert Ecto.Changeset.get_change(changeset, :ends_at) == at(21)
    end

    test "ninety minutes lands on the half hour" do
      changeset = changeset_for(%{duration_minutes: 90})

      assert Ecto.Changeset.get_change(changeset, :ends_at) == at(20, 30)
    end

    test "a string from the form counts the same as an integer" do
      changeset = changeset_for(%{duration_minutes: "120"})

      assert Ecto.Changeset.get_change(changeset, :ends_at) == at(21)
    end

    test "no duration leaves the end open, as it already did" do
      changeset = changeset_for(%{})

      assert Ecto.Changeset.get_change(changeset, :ends_at) == nil
      assert changeset.valid?
    end

    test "a duration of zero is refused, since it says nothing" do
      changeset = changeset_for(%{duration_minutes: 0})

      refute changeset.valid?
    end

    test "a negative duration is refused" do
      changeset = changeset_for(%{duration_minutes: -60})

      refute changeset.valid?
    end

    test "junk in the duration is refused instead of silently becoming no end" do
      changeset = changeset_for(%{duration_minutes: "duas horas"})

      refute changeset.valid?
    end
  end

  describe "what still goes through the end date" do
    test "an event across days keeps saying when it ends" do
      changeset = changeset_for(%{ends_at: at(23) |> DateTime.add(2, :day)})

      assert changeset.valid?
    end

    test "the duration wins when both arrive, because it is what the form asked" do
      changeset = changeset_for(%{duration_minutes: 120, ends_at: at(23)})

      assert Ecto.Changeset.get_change(changeset, :ends_at) == at(21)
    end

    test "an end before the start is still refused" do
      changeset = changeset_for(%{ends_at: at(18)})

      refute changeset.valid?
    end
  end

  describe "through the context" do
    test "creating with a duration stores the end" do
      organizer = insert(:user, is_teacher: true)

      {:ok, workshop} =
        Workshops.create_workshop(organizer, %{
          title: "Aulão",
          description: "Vamos dançar.",
          starts_at: at(19),
          duration_minutes: 180
        })

      assert workshop.ends_at == at(22)
    end

    test "editing the start with the duration kept moves the end along" do
      organizer = insert(:user, is_teacher: true)

      {:ok, workshop} =
        Workshops.create_workshop(organizer, %{
          title: "Aulão",
          description: "Vamos dançar.",
          starts_at: at(19),
          duration_minutes: 120
        })

      {:ok, moved} =
        Workshops.update_workshop(organizer, workshop, %{
          starts_at: at(20),
          duration_minutes: 120
        })

      assert moved.ends_at == at(22)
    end
  end
end
