defmodule OGrupoDeEstudosWeb.LinkPreviewTest do
  @moduledoc """
  What WhatsApp shows when a workshop link lands in a group.

  The share IS the marketing: the link goes to a group and the preview decides
  whether anyone taps. Without tags of its own, the page fell back to the site-wide
  giant logo, saying nothing about the class.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  alias OGrupoDeEstudos.{Brazil, Workshops}

  @png_1x1 Base.decode64!(
             "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
           )

  defp at_day(days) do
    Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(Time.new!(20, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp published_workshop(organizer, overrides \\ %{}) do
    {:ok, workshop} =
      Workshops.create_workshop(
        organizer,
        Map.merge(
          %{
            title: "Caminho do Roots — Avançado",
            description: "Sacadas e pêndulos.\nPara quem já dança.",
            starts_at: at_day(7)
          },
          overrides
        )
      )

    {:ok, workshop} = Workshops.publish_workshop(organizer, workshop)
    workshop
  end

  defp with_flyer(workshop, organizer) do
    tmp = Path.join(System.tmp_dir!(), "flyer_#{System.unique_integer([:positive])}.png")
    File.write!(tmp, @png_1x1)
    {:ok, updated} = Workshops.put_workshop_flyer(workshop, organizer, tmp, ".png")
    File.rm(tmp)
    updated
  end

  describe "the workshop page, as the crawler reads it" do
    setup do
      organizer = insert(:user, is_teacher: true)
      %{organizer: organizer, workshop: published_workshop(organizer)}
    end

    test "the title of the class is the title of the preview", %{conn: conn} = ctx do
      html = conn |> get(~p"/workshops/#{ctx.workshop.slug}") |> html_response(200)

      assert html =~ ~s(property="og:title" content="Caminho do Roots — Avançado)
    end

    test "the description comes along, in one line", %{conn: conn} = ctx do
      html = conn |> get(~p"/workshops/#{ctx.workshop.slug}") |> html_response(200)

      assert html =~ "Sacadas e pêndulos. Para quem já dança."
      refute html =~ ~s(og:description" content="Sacadas e pêndulos.\n)
    end

    test "a long description is cut for the card, not dumped whole", %{conn: conn} = ctx do
      organizer = ctx.organizer
      long = String.duplicate("Muito conteúdo de sacada. ", 30)
      workshop = published_workshop(organizer, %{title: "Longo", description: long})

      html = conn |> get(~p"/workshops/#{workshop.slug}") |> html_response(200)

      [description] =
        Regex.run(~r/property="og:description" content="([^"]*)"/, html, capture: :all_but_first)

      assert String.length(description) <= 160
      assert String.ends_with?(description, "…")
    end

    test "with a flyer, the image of the preview is the flyer, square", %{conn: conn} = ctx do
      workshop = with_flyer(ctx.workshop, ctx.organizer)

      html = conn |> get(~p"/workshops/#{workshop.slug}") |> html_response(200)

      assert html =~ ~s(property="og:image" content="http)
      assert html =~ "/workshops/#{workshop.slug}/og-image"
      assert html =~ ~s(property="og:image:width" content="1200")
    end

    test "without a flyer, the logo answers, in its own size", %{conn: conn} = ctx do
      html = conn |> get(~p"/workshops/#{ctx.workshop.slug}") |> html_response(200)

      assert html =~
               ~s(property="og:image" content="https://ogrupodeestudos.com.br/icons/icon-512.png")

      assert html =~ ~s(property="og:image:width" content="512")
    end

    test "the address of the card is the address of the page", %{conn: conn} = ctx do
      html = conn |> get(~p"/workshops/#{ctx.workshop.slug}") |> html_response(200)

      assert html =~ ~s(property="og:url" content="http)
      assert html =~ "/workshops/#{ctx.workshop.slug}"
    end
  end

  describe "the program page, which is the link that circulates the most" do
    setup do
      organizer = insert(:user, is_teacher: true)

      {:ok, program} =
        Workshops.create_program(organizer, %{
          title: "Caminho do Roots em Curitiba",
          description: "Dois dias de forró roots, do básico ao avançado."
        })

      {:ok, program} = Workshops.publish_program(organizer, program)
      %{organizer: organizer, program: program}
    end

    test "title and description are the program's own", %{conn: conn} = ctx do
      html = conn |> get(~p"/programs/#{ctx.program.slug}") |> html_response(200)

      assert html =~ ~s(property="og:title" content="Caminho do Roots em Curitiba)
      assert html =~ "Dois dias de forró roots"
    end

    test "with a flyer, the image points at the program's og image", %{conn: conn} = ctx do
      tmp = Path.join(System.tmp_dir!(), "flyer_#{System.unique_integer([:positive])}.png")
      File.write!(tmp, @png_1x1)
      {:ok, program} = Workshops.put_program_flyer(ctx.program, ctx.organizer, tmp, ".png")
      File.rm(tmp)

      html = conn |> get(~p"/programs/#{program.slug}") |> html_response(200)

      assert html =~ "/programs/#{program.slug}/og-image"
    end
  end

  describe "the square image the preview points at" do
    setup do
      organizer = insert(:user, is_teacher: true)
      %{organizer: organizer, workshop: published_workshop(organizer)}
    end

    test "serves the flyer derivative with an image content type", %{conn: conn} = ctx do
      workshop = with_flyer(ctx.workshop, ctx.organizer)

      response = get(conn, ~p"/workshops/#{workshop.slug}/og-image")

      assert response.status == 200
      assert response.resp_body != ""

      assert ["image/" <> _] =
               get_resp_header(response, "content-type") |> Enum.map(&hd(String.split(&1, ";")))
    end

    test "asking twice serves the cached derivative, not a second crop", %{conn: conn} = ctx do
      workshop = with_flyer(ctx.workshop, ctx.organizer)

      first = get(conn, ~p"/workshops/#{workshop.slug}/og-image")
      second = get(conn, ~p"/workshops/#{workshop.slug}/og-image")

      assert first.resp_body == second.resp_body
    end

    test "without a flyer, the logo answers instead of a broken image", %{conn: conn} = ctx do
      response = get(conn, ~p"/workshops/#{ctx.workshop.slug}/og-image")

      assert redirected_to(response) == "/icons/icon-512.png"
    end

    test "a slug that does not exist is not found", %{conn: conn} do
      assert get(conn, ~p"/workshops/nao-existe/og-image").status == 404
    end

    test "the program has the same door", %{conn: conn} = ctx do
      {:ok, program} = Workshops.create_program(ctx.organizer, %{title: "Fim de semana"})

      tmp = Path.join(System.tmp_dir!(), "flyer_#{System.unique_integer([:positive])}.png")
      File.write!(tmp, @png_1x1)
      {:ok, program} = Workshops.put_program_flyer(program, ctx.organizer, tmp, ".png")
      File.rm(tmp)

      assert get(conn, ~p"/programs/#{program.slug}/og-image").status == 200
    end
  end
end
