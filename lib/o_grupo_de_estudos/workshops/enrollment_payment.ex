defmodule OGrupoDeEstudos.Workshops.EnrollmentPayment do
  @moduledoc """
  Turns the organizer's raw roster into the payment view of a workshop.

  An enrollment covered by a package carries no payment of its own: the state
  comes from the package, and the amount is only this workshop's slice of what
  was paid for the set. Deriving instead of copying is what stops one payment
  from being counted twice, and it settles on its own the case of someone marked
  paid on the workshop who later buys the package: the package answers, and the
  old flag stops counting.

  Pure calculation: the caller brings the rows and the workshops each package
  covers. See `PackageSplit` for how the amount is divided.
  """

  alias OGrupoDeEstudos.Workshops.PackageSplit

  @doc "Adds the effective payment state and the amount owed to this workshop."
  @spec enrich([map()], %{term() => [PackageSplit.workshop()]}, term()) :: [map()]
  def enrich(rows, covered_by_package, workshop_id) do
    Enum.map(rows, fn row ->
      covered = Map.get(covered_by_package, row.program_enrollment_id, [])

      row
      |> Map.put(:payment_status, status(row))
      |> Map.put(:covered_by_package?, covered?(row))
      |> Map.put(:package_share_cents, share(row, covered, workshop_id))
    end)
  end

  @doc "Ids of the packages behind the roster, to look up what each one covers."
  @spec package_ids([map()]) :: [term()]
  def package_ids(rows) do
    rows |> Enum.map(& &1.program_enrollment_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()
  end

  @doc """
  How many are enrolled, paid and waived, and how much actually came in.

  The money comes broken down by where it came from: `package_cents` is the sum
  of the slices of whoever bought the set, `individual_cents` is the full price
  of whoever paid this workshop alone. `revenue_cents` is the two together.
  """
  @spec summarize([map()], non_neg_integer() | nil) :: map()
  def summarize(rows, workshop_price_cents) do
    paid = Enum.filter(rows, &(&1.payment_status == :paid))
    {package, individual} = Enum.split_with(paid, & &1.covered_by_package?)
    package_cents = package |> Enum.map(& &1.package_share_cents) |> Enum.sum()
    individual_cents = length(individual) * (workshop_price_cents || 0)

    %{
      total: length(rows),
      paid: length(paid),
      waived: Enum.count(rows, &(&1.payment_status == :waived)),
      package_cents: package_cents,
      individual_cents: individual_cents,
      revenue_cents: package_cents + individual_cents
    }
  end

  defp covered?(%{program_enrollment_id: nil}), do: false
  defp covered?(_row), do: true

  defp status(%{program_enrollment_id: nil} = row), do: row.own_payment_status
  defp status(row), do: row.package_payment_status

  defp share(%{program_enrollment_id: nil}, _covered, _workshop_id), do: nil

  defp share(row, covered, workshop_id) do
    row.package_price_cents |> PackageSplit.shares(covered) |> Map.get(workshop_id, 0)
  end
end
