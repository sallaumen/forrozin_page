defmodule OGrupoDeEstudos.BrazilUtcTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Brazil

  describe "to_utc/1" do
    test "converts local time to UTC by adding three hours" do
      local = ~U[2026-08-16 14:00:00Z]
      assert Brazil.to_utc(local) == ~U[2026-08-16 17:00:00Z]
    end

    test "rolls over to the next day past 21h" do
      local = ~U[2026-08-16 21:30:00Z]
      assert Brazil.to_utc(local) == ~U[2026-08-17 00:30:00Z]
    end

    test "nil continua nil" do
      assert Brazil.to_utc(nil) == nil
    end

    test "is the inverse of to_local" do
      utc = ~U[2026-08-16 17:00:00Z]
      assert utc |> Brazil.to_local() |> Brazil.to_utc() == utc
    end
  end

  describe "day_start_utc/1 e day_end_utc/1" do
    test "start of a local day is 03:00 UTC of the same day" do
      assert Brazil.day_start_utc(~D[2026-08-16]) == ~U[2026-08-16 03:00:00.000000Z]
    end

    test "end of a local day is 02:59:59.999999 UTC of the next day" do
      assert Brazil.day_end_utc(~D[2026-08-16]) == ~U[2026-08-17 02:59:59.999999Z]
    end

    test "event at 21h on a Saturday falls inside that same Saturday" do
      saturday = ~D[2026-08-15]
      event_utc = Brazil.to_utc(~U[2026-08-15 21:00:00Z])

      assert DateTime.compare(event_utc, Brazil.day_start_utc(saturday)) == :gt
      assert DateTime.compare(event_utc, Brazil.day_end_utc(saturday)) == :lt
    end
  end

  describe "range_utc/2 for a week" do
    test "spans local Monday 00:00 to Sunday 23:59:59" do
      {from, to} = Brazil.range_utc(:week, ~D[2026-08-12])

      assert from == Brazil.day_start_utc(~D[2026-08-10])
      assert to == Brazil.day_end_utc(~D[2026-08-16])
    end

    test "Sunday belongs to the week that started on the previous Monday" do
      {from, _to} = Brazil.range_utc(:week, ~D[2026-08-16])
      assert from == Brazil.day_start_utc(~D[2026-08-10])
    end
  end

  describe "range_utc/2 for a month" do
    test "covers the first to the last day of the month" do
      {from, to} = Brazil.range_utc(:month, ~D[2026-08-16])

      assert from == Brazil.day_start_utc(~D[2026-08-01])
      assert to == Brazil.day_end_utc(~D[2026-08-31])
    end

    test "February of a leap year ends on the 29th" do
      {_from, to} = Brazil.range_utc(:month, ~D[2028-02-10])
      assert to == Brazil.day_end_utc(~D[2028-02-29])
    end
  end

  describe "range_utc/2 for a year" do
    test "covers January 1st to December 31st" do
      {from, to} = Brazil.range_utc(:year, ~D[2026-08-16])

      assert from == Brazil.day_start_utc(~D[2026-01-01])
      assert to == Brazil.day_end_utc(~D[2026-12-31])
    end

    test "December 31st at 22h still belongs to the same year" do
      {_from, to} = Brazil.range_utc(:year, ~D[2026-12-31])
      event = Brazil.to_utc(~U[2026-12-31 22:00:00Z])

      assert DateTime.compare(event, to) == :lt
    end
  end
end
