defmodule OGrupoDeEstudosWeb.PackageConversionPanelTest do
  @moduledoc """
  The backstage section that spots hand-made packages.

  Whoever enrolled workshop by workshop in a program that sells a package shows
  up to the organizer as full-price daily enrollments. This section lists them
  and converts each with one button, so the books charge the discounted set.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Workshops

  defp at_day(days) do
    OGrupoDeEstudos.Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(~T[19:00:00], "Etc/UTC")
    |> OGrupoDeEstudos.Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  setup do
    owner = insert(:user)

    {:ok, program} =
      Workshops.create_program(owner, %{title: "Festival", price_cents: 9000})

    workshops =
      for day <- [7, 8] do
        insert(:workshop, organizer: owner, starts_at: at_day(day), price_cents: 5000)
      end

    for w <- workshops, do: Workshops.attach_workshop(program, owner, w.id)
    {:ok, program} = Workshops.publish_program(owner, program)

    %{conn: build_conn(), owner: owner, program: program, workshops: workshops}
  end

  defp enroll_in_all(ctx, user) do
    for w <- ctx.workshops, do: {:ok, _} = Workshops.enroll(w, user)
    user
  end

  defp manage(ctx) do
    live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}/manage")
  end

  describe "spotting who built the package by hand" do
    test "lists whoever is in every workshop without the package", ctx do
      enroll_in_all(ctx, insert(:user, name: "Maria Completa"))

      {:ok, _lv, html} = manage(ctx)

      assert html =~ "Inscritos por fora do pacote"
      assert html =~ "Maria Completa"
    end

    test "stays quiet when nobody did it", ctx do
      partial = insert(:user, name: "Ana Parcial")
      {:ok, _} = Workshops.enroll(hd(ctx.workshops), partial)

      {:ok, _lv, html} = manage(ctx)

      refute html =~ "Inscritos por fora do pacote"
      refute html =~ "Ana Parcial"
    end

    test "stays quiet when the program sells no package", ctx do
      {:ok, avulso} = Workshops.create_program(ctx.owner, %{title: "Sem pacote"})
      w = insert(:workshop, organizer: ctx.owner, starts_at: at_day(9), price_cents: 5000)
      {:ok, _} = Workshops.attach_workshop(avulso, ctx.owner, w.id)
      {:ok, avulso} = Workshops.publish_program(ctx.owner, avulso)
      {:ok, _} = Workshops.enroll(w, insert(:user, name: "Solo Total"))

      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{avulso.slug}/manage")

      refute html =~ "Inscritos por fora do pacote"
    end
  end

  describe "the convert button" do
    test "moves the person into the package list, pending payment", ctx do
      student = enroll_in_all(ctx, insert(:user, name: "Maria Completa"))

      {:ok, lv, _html} = manage(ctx)

      html = render_click(lv, "convert_to_package", %{"user-id" => student.id})

      refute html =~ "Inscritos por fora do pacote"
      assert {:ok, [pacote]} = Workshops.list_package_enrollments(ctx.program, ctx.owner)
      assert pacote.user_id == student.id
      assert pacote.payment_status == :pending
      assert html =~ "virou pacote"
    end

    test "a stale click on someone no longer eligible explains itself", ctx do
      student = enroll_in_all(ctx, insert(:user))
      {:ok, lv, _html} = manage(ctx)

      {:ok, _} = Workshops.cancel_enrollment(hd(ctx.workshops), student)

      html = render_click(lv, "convert_to_package", %{"user-id" => student.id})

      assert html =~ "não está mais em todos os workshops"
      assert {:ok, []} = Workshops.list_package_enrollments(ctx.program, ctx.owner)
    end
  end
end
