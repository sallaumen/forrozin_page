defmodule OGrupoDeEstudosWeb.WorkshopComponentsTest do
  use ExUnit.Case, async: true

  import OGrupoDeEstudosWeb.WorkshopComponents

  # Horários em UTC; o rótulo sai no fuso de Brasília (UTC-3).
  defp workshop(starts_at, ends_at \\ nil) do
    %{starts_at: starts_at, ends_at: ends_at}
  end

  describe "schedule_label/1 em um único dia" do
    test "mostra o dia por extenso e a faixa de horário" do
      label = schedule_label(workshop(~U[2026-09-12 17:00:00Z], ~U[2026-09-12 21:00:00Z]))

      assert label == "sábado, 12 de setembro · 14h às 18h"
    end

    test "sem horário de fim mostra só o início" do
      assert schedule_label(workshop(~U[2026-09-12 17:00:00Z])) == "sábado, 12 de setembro · 14h"
    end

    test "o que decide é o dia local, não o UTC" do
      # 20h às 23h em Brasília no dia 12 é 23h e 02h UTC: o fim cruza a meia-noite
      # em UTC, mas para quem vai ao workshop é uma noite só.
      label = schedule_label(workshop(~U[2026-09-12 23:00:00Z], ~U[2026-09-13 02:00:00Z]))

      assert label == "sábado, 12 de setembro · 20h às 23h"
    end
  end

  describe "schedule_label/1 atravessando dias" do
    test "diz os dois dias, não só o primeiro" do
      label = schedule_label(workshop(~U[2026-09-12 17:00:00Z], ~U[2026-09-13 21:00:00Z]))

      assert label == "12 a 13 de setembro · começa 14h"
      refute label =~ "às 18h"
    end

    test "meses diferentes nomeiam os dois meses" do
      label = schedule_label(workshop(~U[2026-01-30 17:00:00Z], ~U[2026-02-02 21:00:00Z]))

      assert label == "30 de janeiro a 02 de fevereiro · começa 14h"
    end
  end

  describe "price_label/1" do
    test "sem preço é gratuito" do
      assert price_label(%{price_cents: nil}) == "Gratuito"
      assert price_label(%{price_cents: 0}) == "Gratuito"
    end

    test "centavos aparecem só quando existem" do
      assert price_label(%{price_cents: 18_000}) == "R$ 180"
      assert price_label(%{price_cents: 18_050}) == "R$ 180,50"
      assert price_label(%{price_cents: 18_005}) == "R$ 180,05"
    end
  end

  describe "money_label/1" do
    test "zero é um valor, não é gratuito" do
      # No painel do organizador, R$ 0 recebido é informação; "Gratuito" seria mentira.
      assert money_label(0) == "R$ 0"
      assert money_label(36_000) == "R$ 360"
      assert money_label(18_050) == "R$ 180,50"
    end
  end
end
