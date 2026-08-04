defmodule OGrupoDeEstudosWeb.WorkshopComponentsTest do
  use ExUnit.Case, async: true

  import OGrupoDeEstudosWeb.WorkshopComponents
  import Phoenix.LiveViewTest

  @id "11111111-1111-1111-1111-111111111111"
  @autora_id "22222222-2222-2222-2222-222222222222"

  defp workshop(starts_at, ends_at \\ nil) do
    %{starts_at: starts_at, ends_at: ends_at}
  end

  describe "schedule_label/1 on a single day" do
    test "shows the weekday spelled out and the time range" do
      label = schedule_label(workshop(~U[2026-09-12 17:00:00Z], ~U[2026-09-12 21:00:00Z]))

      assert label == "sábado, 12 de setembro · 14h às 18h"
    end

    test "shows only the start when there is no end time" do
      assert schedule_label(workshop(~U[2026-09-12 17:00:00Z])) == "sábado, 12 de setembro · 14h"
    end

    test "the local day decides, not the UTC one" do
      label = schedule_label(workshop(~U[2026-09-12 23:00:00Z], ~U[2026-09-13 02:00:00Z]))

      assert label == "sábado, 12 de setembro · 20h às 23h"
    end
  end

  describe "schedule_label/1 atravessando dias" do
    test "names both days, not only the first" do
      label = schedule_label(workshop(~U[2026-09-12 17:00:00Z], ~U[2026-09-13 21:00:00Z]))

      assert label == "12 a 13 de setembro · começa 14h"
      refute label =~ "às 18h"
    end

    test "different months name both months" do
      label = schedule_label(workshop(~U[2026-01-30 17:00:00Z], ~U[2026-02-02 21:00:00Z]))

      assert label == "30 de janeiro a 02 de fevereiro · começa 14h"
    end
  end

  describe "price_label/1" do
    test "no price means free" do
      assert price_label(%{price_cents: nil}) == "Gratuito"
      assert price_label(%{price_cents: 0}) == "Gratuito"
    end

    test "cents show up only when they exist" do
      assert price_label(%{price_cents: 18_000}) == "R$ 180"
      assert price_label(%{price_cents: 18_050}) == "R$ 180,50"
      assert price_label(%{price_cents: 18_005}) == "R$ 180,05"
    end
  end

  describe "program_span/2" do
    defp days(dates), do: Enum.map(dates, &{&1, []})

    test "two consecutive days in the same month" do
      span = program_span(days([~D[2026-08-07], ~D[2026-08-08]]), 2)

      assert span == "2 workshops · 07 e 08 de agosto"
    end

    test "intervalo maior usa 'a'" do
      span = program_span(days([~D[2026-02-12], ~D[2026-02-18]]), 15)

      assert span == "15 workshops · 12 a 18 de fevereiro"
    end

    test "different months name both" do
      span = program_span(days([~D[2026-01-30], ~D[2026-02-02]]), 4)

      assert span == "4 workshops · 30 de janeiro a 02 de fevereiro"
    end

    test "a single day does not repeat the date" do
      span = program_span(days([~D[2026-08-07]]), 1)

      assert span == "1 workshop · 07 de agosto"
    end

    test "empty program says so" do
      assert program_span([], 0) == "Nenhum workshop ainda"
    end
  end

  describe "money_label/1" do
    test "zero is a price, not free" do
      assert money_label(0) == "R$ 0"
      assert money_label(36_000) == "R$ 360"
      assert money_label(18_050) == "R$ 180,50"
    end
  end

  describe "media_gallery/1 with a video being transcoded" do
    test "processing video warns and offers no broken player" do
      html = gallery([item(kind: :video, status: :processing)])

      assert html =~ "Processando"
      refute html =~ "<video"
    end

    test "ready video becomes a player" do
      html = gallery([item(kind: :video, status: :ready)])

      assert html =~ "<video"
      refute html =~ "Processando"
    end

    test "ready video uses the poster as cover" do
      html = gallery([item(kind: :video, status: :ready, poster_key: "workshop_media/abc.jpg")])

      assert html =~ ~s|poster="/workshop-media/#{@id}/poster"|
    end

    test "player gets no empty attribute without a poster" do
      html = gallery([item(kind: :video, status: :ready, poster_key: nil)])

      assert html =~ "<video"
      refute html =~ "poster="
    end

    test "photo goes through no transcode and shows up directly" do
      html = gallery([item(kind: :photo, status: :ready)])

      assert html =~ "<img"
      refute html =~ "Processando"
    end

    test "media can be removed from the gallery even while processing" do
      html = gallery([item(kind: :video, status: :processing)], autora())

      assert html =~ "remove_media"
    end
  end

  defp autora, do: %{id: @autora_id}

  defp item(attrs) do
    defaults = %{
      id: @id,
      kind: :photo,
      status: :ready,
      poster_key: nil,
      official: false,
      caption: nil,
      uploaded_by_id: @autora_id,
      uploaded_by: %{name: "Aluna", username: "aluna"}
    }

    Enum.into(attrs, defaults)
  end

  defp gallery(media, current_user \\ nil) do
    assigns = %{media: media, current_user: current_user, can_delete_any: false}

    render_component(&media_gallery/1, assigns)
  end
end
