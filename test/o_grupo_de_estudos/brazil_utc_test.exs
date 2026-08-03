defmodule OGrupoDeEstudos.BrazilUtcTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Brazil

  # Curitiba é UTC-3 o ano inteiro (sem horário de verão desde 2019),
  # então meia-noite em Brasília é 03:00 UTC do mesmo dia.

  describe "to_utc/1" do
    test "converte horário de Brasília para UTC somando 3 horas" do
      local = ~U[2026-08-16 14:00:00Z]
      assert Brazil.to_utc(local) == ~U[2026-08-16 17:00:00Z]
    end

    test "vira o dia quando passa das 21h" do
      local = ~U[2026-08-16 21:30:00Z]
      assert Brazil.to_utc(local) == ~U[2026-08-17 00:30:00Z]
    end

    test "nil continua nil" do
      assert Brazil.to_utc(nil) == nil
    end

    test "é o inverso de to_local" do
      utc = ~U[2026-08-16 17:00:00Z]
      assert utc |> Brazil.to_local() |> Brazil.to_utc() == utc
    end
  end

  describe "day_start_utc/1 e day_end_utc/1" do
    test "início do dia em Brasília é 03:00 UTC do mesmo dia" do
      assert Brazil.day_start_utc(~D[2026-08-16]) == ~U[2026-08-16 03:00:00.000000Z]
    end

    test "fim do dia em Brasília é 02:59:59.999999 UTC do dia seguinte" do
      assert Brazil.day_end_utc(~D[2026-08-16]) == ~U[2026-08-17 02:59:59.999999Z]
    end

    test "um evento às 21h de sábado cai dentro do próprio sábado" do
      sabado = ~D[2026-08-15]
      evento_utc = Brazil.to_utc(~U[2026-08-15 21:00:00Z])

      assert DateTime.compare(evento_utc, Brazil.day_start_utc(sabado)) == :gt
      assert DateTime.compare(evento_utc, Brazil.day_end_utc(sabado)) == :lt
    end
  end

  describe "range_utc/2 — semana" do
    test "vai de segunda 00:00 a domingo 23:59:59 no horário de Brasília" do
      # 2026-08-12 é uma quarta-feira
      {from, to} = Brazil.range_utc(:week, ~D[2026-08-12])

      assert from == Brazil.day_start_utc(~D[2026-08-10])
      assert to == Brazil.day_end_utc(~D[2026-08-16])
    end

    test "domingo pertence à semana que começou na segunda anterior" do
      {from, _to} = Brazil.range_utc(:week, ~D[2026-08-16])
      assert from == Brazil.day_start_utc(~D[2026-08-10])
    end
  end

  describe "range_utc/2 — mês" do
    test "cobre do primeiro ao último dia do mês" do
      {from, to} = Brazil.range_utc(:month, ~D[2026-08-16])

      assert from == Brazil.day_start_utc(~D[2026-08-01])
      assert to == Brazil.day_end_utc(~D[2026-08-31])
    end

    test "fevereiro de ano bissexto termina no dia 29" do
      {_from, to} = Brazil.range_utc(:month, ~D[2028-02-10])
      assert to == Brazil.day_end_utc(~D[2028-02-29])
    end
  end

  describe "range_utc/2 — ano" do
    test "cobre de 1º de janeiro a 31 de dezembro" do
      {from, to} = Brazil.range_utc(:year, ~D[2026-08-16])

      assert from == Brazil.day_start_utc(~D[2026-01-01])
      assert to == Brazil.day_end_utc(~D[2026-12-31])
    end

    test "31 de dezembro às 22h ainda é do mesmo ano" do
      {_from, to} = Brazil.range_utc(:year, ~D[2026-12-31])
      evento = Brazil.to_utc(~U[2026-12-31 22:00:00Z])

      assert DateTime.compare(evento, to) == :lt
    end
  end
end
