defmodule OGrupoDeEstudosWeb.WorkshopMobileTest do
  @moduledoc """
  On a 375px screen the desktop columns become one stack and DOM order becomes
  reading order. These tests pin price before content and keep native browser
  controls out of a page written in Portuguese.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Brazil, Workshops}

  defp at_day(days, hour \\ 14) do
    Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(Time.new!(hour, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp published(organizer, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          title: "Workshop de sacadas",
          description: "Conteúdo do workshop.",
          location: "Curitiba",
          starts_at: at_day(7),
          price_cents: 18_000
        },
        overrides
      )

    {:ok, w} = Workshops.create_workshop(organizer, attrs)
    {:ok, w} = Workshops.publish_workshop(organizer, w)
    w
  end

  describe "reading order on mobile" do
    test "price and enrollment come before the content", %{conn: conn} do
      owner = insert(:user)
      workshop = published(owner)
      {:ok, _} = Workshops.enroll(workshop, insert(:user))

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      assert position(html, "R$ 180") < position(html, "Conversa")
      assert position(html, "Fazer inscrição") < position(html, "Conversa")
    end

    test "on desktop the box goes back to the right column", %{conn: conn} do
      owner = insert(:user)
      workshop = published(owner)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      assert html =~ "lg:order-2"
      assert html =~ "lg:order-1"
    end
  end

  describe "localized controls" do
    test "gallery does not show the native browser button", %{conn: conn} do
      owner = insert(:user)
      workshop = published(owner)
      student = insert(:user)
      {:ok, _} = Workshops.enroll(workshop, student)

      {:ok, _lv, html} = live(log_in_user(conn, student), ~p"/workshops/#{workshop.slug}")

      assert html =~ "Escolher foto ou vídeo"
      assert html =~ "sr-only"
    end

    test "flyer also has its own label", %{conn: conn} do
      owner = insert(:user)
      workshop = published(owner)

      {:ok, _lv, html} =
        live(log_in_user(conn, owner), ~p"/study/workshops/#{workshop.slug}/editar")

      assert html =~ "Escolher imagem"
    end
  end

  describe "enrolled row in the panel" do
    test "identity and actions sit on separate rows on mobile", %{conn: conn} do
      owner = insert(:user)
      workshop = published(owner)
      {:ok, _} = Workshops.enroll(workshop, insert(:user, name: "Maria Aluna"))

      {:ok, _lv, html} = live(log_in_user(conn, owner), ~p"/workshops/#{workshop.slug}/gerenciar")

      assert html =~ "basis-full"
      assert html =~ "Maria Aluna"
    end
  end

  defp position(html, trecho) do
    case :binary.match(html, trecho) do
      {inicio, _} -> inicio
      :nomatch -> flunk("não achei #{inspect(trecho)} no HTML")
    end
  end
end
