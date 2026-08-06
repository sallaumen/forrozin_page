defmodule OGrupoDeEstudosWeb.WorkshopProgramManageTest do
  @moduledoc """
  The backstage of a program moved to its own page.

  The program page is the link that goes to WhatsApp: it should stay the thing
  a student reads. The money, the packages and the assembly live behind
  `/programs/:slug/manage`, which is also where the crew is invited.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import OGrupoDeEstudos.Factory
  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Workshops

  setup %{conn: conn} do
    owner = insert(:user)

    {:ok, program} =
      Workshops.create_program(owner, %{title: "Festival", price_cents: 9000})

    starts = DateTime.utc_now() |> DateTime.add(7 * 86_400, :second) |> DateTime.truncate(:second)
    workshop = insert(:workshop, organizer: owner, starts_at: starts, price_cents: 5000)
    {:ok, _} = Workshops.attach_workshop(program, owner, workshop.id)
    {:ok, program} = Workshops.publish_program(owner, program)

    %{conn: conn, owner: owner, program: program, workshop: workshop, teacher: insert(:user)}
  end

  describe "the backstage left the public page" do
    test "the program page no longer carries the balance nor the assembly", ctx do
      {:ok, _lv, html} = live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}")

      refute html =~ "Balanço da programação"
      refute html =~ "Quem levou a programação toda"
      refute html =~ "Montar a programação"
    end

    test "it offers whoever administers the way in", ctx do
      {:ok, _lv, html} = live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}")

      assert html =~ "/programs/#{ctx.program.slug}/manage"
    end

    test "a student sees no way in", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, insert(:user)), ~p"/programs/#{ctx.program.slug}")

      refute html =~ "/programs/#{ctx.program.slug}/manage"
    end
  end

  describe "the manage page" do
    test "the creator sees the money, the packages and the assembly", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}/manage")

      assert html =~ "Balanço da programação"
      assert html =~ "Quem levou a programação toda"
      assert html =~ "Montar a programação"
    end

    test "an invited co-organizer sees the money too", ctx do
      {:ok, _} = Workshops.add_program_admin(ctx.program, ctx.owner, ctx.teacher.id)

      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.teacher), ~p"/programs/#{ctx.program.slug}/manage")

      assert html =~ "Balanço da programação"
    end

    test "anyone else is turned away", ctx do
      assert {:error, {:redirect, %{to: "/study/workshops"}}} =
               live(
                 log_in_user(ctx.conn, insert(:user)),
                 ~p"/programs/#{ctx.program.slug}/manage"
               )
    end

    test "an unknown program does not open a page", ctx do
      assert {:error, {:redirect, %{to: "/study/workshops"}}} =
               live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/nao-existe/manage")
    end
  end

  describe "inviting the crew" do
    test "the creator promotes someone by username", ctx do
      {:ok, lv, _html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}/manage")

      html = render_submit(lv, "add_program_admin", %{"username" => ctx.teacher.username})

      assert html =~ ctx.teacher.name
      assert Workshops.program_admin?(ctx.program, ctx.teacher)
    end

    test "an unknown username says so instead of failing silently", ctx do
      {:ok, lv, _html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}/manage")

      html = render_submit(lv, "add_program_admin", %{"username" => "ninguem_aqui"})

      assert html =~ "Não encontrei esse usuário"
    end

    test "the creator removes whoever they promoted", ctx do
      {:ok, _} = Workshops.add_program_admin(ctx.program, ctx.owner, ctx.teacher.id)

      {:ok, lv, _html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}/manage")

      render_click(lv, "remove_program_admin", %{"id" => ctx.teacher.id})

      refute Workshops.program_admin?(ctx.program, ctx.teacher)
    end

    test "a co-organizer does not get the door to invite others", ctx do
      {:ok, _} = Workshops.add_program_admin(ctx.program, ctx.owner, ctx.teacher.id)

      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.teacher), ~p"/programs/#{ctx.program.slug}/manage")

      refute html =~ "add_program_admin"
    end
  end

  describe "building the program from the backstage" do
    test "attaches a loose workshop on the spot", ctx do
      improvised = insert(:workshop, organizer: ctx.owner, title: "Roda improvisada")

      {:ok, lv, html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}/manage")

      assert html =~ "Roda improvisada"

      render_click(lv, "attach_workshop", %{"id" => improvised.id})

      ids = ctx.program |> Workshops.list_program_workshops() |> Enum.map(& &1.id)
      assert improvised.id in ids
    end

    test "detaches one on the spot, and the workshop keeps existing loose", ctx do
      {:ok, lv, _html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}/manage")

      render_click(lv, "detach_workshop", %{"id" => ctx.workshop.id})

      assert Workshops.list_program_workshops(ctx.program) == []
      assert Workshops.get_workshop(ctx.workshop.id)
    end

    test "only offers workshops that are not inside yet", ctx do
      fora = insert(:workshop, organizer: ctx.owner, title: "Ainda fora da programação")

      {:ok, lv, html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}/manage")

      assert html =~ "Ainda fora da programação"

      html = render_click(lv, "attach_workshop", %{"id" => fora.id})

      assert html =~ "Tirar"
    end

    test "a made-up id breaks nothing", ctx do
      {:ok, lv, _html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}/manage")

      render_click(lv, "attach_workshop", %{"id" => "nao-e-uuid"})

      assert render(lv) =~ ctx.program.title
      assert length(Workshops.list_program_workshops(ctx.program)) == 1
    end
  end
end
