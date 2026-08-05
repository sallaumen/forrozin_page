defmodule OGrupoDeEstudosWeb.WorkshopComponentsTest do
  use ExUnit.Case, async: true

  import OGrupoDeEstudosWeb.WorkshopComponents
  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Workshops.Workshop

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

  describe "media_gallery/1 on a phone" do
    test "the trash of whoever uploaded shows up without depending on hover" do
      html = gallery([item([])], autora())

      assert html =~ "remove_media"
      refute html =~ "opacity-0"
    end

    test "whoever runs the workshop sees the trash on media from anyone" do
      html = gallery([item([])], outra(), true)

      assert html =~ "remove_media"
    end

    test "whoever neither uploaded nor runs the workshop sees no trash" do
      html = gallery([item([])], outra())

      refute html =~ "remove_media"
    end
  end

  describe "rail_hours/1" do
    test "stacks the start over the end, the way a printed programme prints it" do
      assert rail_hours(workshop(~U[2026-09-12 17:00:00Z], ~U[2026-09-12 21:00:00Z])) ==
               {"14h", "18h"}
    end

    test "without an end hour only the start goes on the rail" do
      assert rail_hours(workshop(~U[2026-09-12 17:00:00Z])) == {"14h", nil}
    end

    test "a class that runs into the next day drops the end hour" do
      assert rail_hours(workshop(~U[2026-09-12 17:00:00Z], ~U[2026-09-13 21:00:00Z])) ==
               {"14h", nil}
    end
  end

  describe "agenda_row/1" do
    test "the day heading owns the date, so the row prints only the hour" do
      html = row()

      assert html =~ "19h"
      refute html =~ "de agosto"
    end

    test "the price reads as a price, not as one more badge" do
      html = row()

      assert html =~ "R$ 50"
      refute html =~ "uppercase"
    end

    test "seats left say how full it is, and a full class says so once" do
      assert row(enrolled_count: 4) =~ "4 de 20 vagas"

      full = row(enrolled_count: 20)
      assert full =~ "Esgotado"
      assert full =~ "20 de 20 vagas"
    end

    test "being enrolled is one discreet mark, not a coloured badge" do
      html = row(enrolled?: true)

      assert html =~ "Você está inscrito"
      refute html =~ "checkbox"
    end

    test "whoever may pick the day gets a checkbox, and it is not the link" do
      html = row(selectable?: true)

      assert html =~ "toggle_selection"
      assert html =~ ~s|href="/workshops/caminho-do-roots|
    end

    test "a draft says so to whoever organizes" do
      assert row(workshop: build_workshop(status: :draft)) =~ "Rascunho"
    end

    test "a private class carries the lock next to the title" do
      assert row(workshop: build_workshop(visibility: :private)) =~ "hero-lock-closed"
    end
  end

  defp row(overrides \\ []) do
    assigns =
      Enum.into(overrides, %{
        workshop: build_workshop([]),
        enrolled_count: 4,
        enrolled?: false,
        selectable?: false,
        selected?: false
      })

    render_component(&agenda_row/1, assigns)
  end

  defp build_workshop(attrs) do
    struct!(
      %Workshop{
        id: @id,
        slug: "caminho-do-roots-iniciante-9xfwjg",
        title: "Caminho do Roots, iniciante e intermediário",
        starts_at: ~U[2026-08-20 22:00:00Z],
        ends_at: ~U[2026-08-20 23:30:00Z],
        price_cents: 5000,
        capacity: 20,
        status: :published,
        visibility: :public,
        location: "Telhado do Tatá",
        organizer: %{name: "Tavano", username: "tavano", avatar_path: nil}
      },
      attrs
    )
  end

  describe "workshop_card/1 na agenda" do
    test "the date is the rail, and the poster stops being a 54px smudge" do
      html = card()

      assert html =~ "AGO" or html =~ "ago"
      refute html =~ "loading=\"lazy\""
    end

    test "price and seats read as text, not as a row of badges" do
      html = card()

      assert html =~ "R$ 50"
      assert html =~ "4 de 20 vagas"
      refute html =~ "rounded-full px-2.5 py-0.5"
    end

    test "organising it is said once, quietly" do
      html = card(organizer?: true)

      assert html =~ "Você organiza"
      assert html =~ "Gerenciar"
    end

    test "a free class says free instead of wearing a blue badge" do
      html = card(workshop: build_workshop(price_cents: nil))

      assert html =~ "Gratuito"
      refute html =~ "accent-blue"
    end
  end

  defp card(overrides \\ []) do
    assigns =
      Enum.into(overrides, %{
        workshop: build_workshop([]),
        enrolled_count: 4,
        enrolled?: false,
        organizer?: false,
        id_prefix: "agenda"
      })

    render_component(&workshop_card/1, assigns)
  end

  defp autora, do: %{id: @autora_id}

  defp outra, do: %{id: "33333333-3333-3333-3333-333333333333"}

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

  defp gallery(media, current_user \\ nil, can_delete_any \\ false) do
    assigns = %{media: media, current_user: current_user, can_delete_any: can_delete_any}

    render_component(&media_gallery/1, assigns)
  end
end
