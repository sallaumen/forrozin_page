defmodule OGrupoDeEstudos.Workshops.PackageSplit do
  @moduledoc """
  Splits what someone paid for a package across the workshops it covers.

  A package is one payment for a set of workshops, so no workshop received the
  whole amount and none received the workshop's own price. Each one gets the
  slice proportional to how much of the set it is worth: a package of R$ 120
  over workshops of R$ 50 and R$ 70 lands as R$ 50 and R$ 70. When the workshops
  cost the same, that is the plain division the organizer expects (R$ 90 over
  two workshops is R$ 45 each), and when no workshop carries a price there is
  nothing to weigh by, so the split is even.

  The slices always add up to exactly what was paid. Proportional division rarely
  lands on whole cents, so the leftover cents go to the largest remainders, and
  ties break by workshop id: without that, a reload could move a cent from one
  workshop to another and the totals would never sit still.

  Pure calculation: no `Repo`, no clock. Whoever reads the numbers assembles the
  list of workshops first.
  """

  @type workshop :: {id :: term(), price_cents :: non_neg_integer() | nil}

  @doc "Slice of `package_cents` belonging to each workshop, by id."
  @spec shares(non_neg_integer() | nil, [workshop()]) :: %{term() => non_neg_integer()}
  def shares(_package_cents, []), do: %{}
  def shares(nil, workshops), do: zeroed(workshops)
  def shares(0, workshops), do: zeroed(workshops)

  def shares(package_cents, workshops) do
    workshops
    |> weights()
    |> distribute(package_cents)
  end

  defp zeroed(workshops), do: Map.new(workshops, fn {id, _price} -> {id, 0} end)

  # With every price absent or zero there is nothing to weigh by, so every
  # workshop weighs the same and the split falls back to an even one.
  defp weights(workshops) do
    priced = Enum.map(workshops, fn {id, price} -> {id, price || 0} end)

    case Enum.sum(Enum.map(priced, &elem(&1, 1))) do
      0 -> Enum.map(priced, fn {id, _price} -> {id, 1} end)
      _total -> priced
    end
  end

  defp distribute(weights, package_cents) do
    total = weights |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    exact = Enum.map(weights, fn {id, weight} -> {id, package_cents * weight / total} end)
    floors = Enum.map(exact, fn {id, cents} -> {id, trunc(cents)} end)
    leftover = package_cents - (floors |> Enum.map(&elem(&1, 1)) |> Enum.sum())

    exact
    |> Enum.sort_by(fn {id, cents} -> {-remainder(cents), id} end)
    |> Enum.take(leftover)
    |> Enum.map(&elem(&1, 0))
    |> MapSet.new()
    |> add_cent_to(floors)
  end

  defp remainder(cents), do: cents - trunc(cents)

  defp add_cent_to(ids, floors) do
    Map.new(floors, fn {id, cents} ->
      {id, if(MapSet.member?(ids, id), do: cents + 1, else: cents)}
    end)
  end
end
