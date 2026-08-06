defmodule OGrupoDeEstudosWeb.PackagePaymentPanelTest do
  @moduledoc """
  What the organizer sees when a payment came from the program.

  The panel has to say where the money came from and how much of it belongs to
  this workshop, and it must not offer a button that would charge it again.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import OGrupoDeEstudos.Factory
  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Workshops

  setup %{conn: conn} do
    owner = insert(:user)

    {:ok, program} =
      Workshops.create_program(owner, %{title: "Fim de semana", price_cents: 9000})

    workshops =
      for day <- [7, 8] do
        starts =
          DateTime.utc_now() |> DateTime.add(day * 86_400, :second) |> DateTime.truncate(:second)

        insert(:workshop,
          organizer: owner,
          starts_at: starts,
          price_cents: 5000,
          status: :published
        )
      end

    for w <- workshops, do: Workshops.attach_workshop(program, owner, w.id)
    {:ok, program} = Workshops.publish_program(owner, program)

    student = insert(:user, name: "Maria Silva")
    {:ok, membership} = Workshops.enroll_in_package(program, student)

    %{
      conn: conn,
      owner: owner,
      program: program,
      workshop: hd(workshops),
      student: student,
      membership: membership
    }
  end

  defp manage(ctx) do
    {:ok, _lv, html} =
      live(log_in_user(ctx.conn, ctx.owner), ~p"/workshops/#{ctx.workshop.slug}/manage")

    html
  end

  describe "an enrollment covered by the package" do
    test "is tagged as coming from the program, with its slice", ctx do
      {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, ctx.membership.id, :paid)

      html = manage(ctx)

      assert html =~ "Pago na programação"
      assert html =~ "R$ 45"
    end

    test "does not claim payment while the package is still pending", ctx do
      html = manage(ctx)

      assert html =~ "Aguardando na programação"
      refute html =~ "Pago na programação"
    end

    test "offers no button that would charge the same money again", ctx do
      {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, ctx.membership.id, :paid)

      html = manage(ctx)

      refute html =~ "Marcar pago"
      refute html =~ "Isentar"
    end

    test "refuses the payment event even when it arrives forged", ctx do
      {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, ctx.membership.id, :paid)

      {:ok, lv, _html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/workshops/#{ctx.workshop.slug}/manage")

      {:ok, [row]} = Workshops.list_enrollments_for_organizer(ctx.workshop, ctx.owner)

      html = render_click(lv, "set_payment", %{"id" => row.id, "status" => "paid"})

      assert html =~ "pagou pela programação"
      assert html =~ "R$ 45"
      refute html =~ "R$ 95"
    end
  end

  describe "the received total" do
    test "counts the package slice, not the workshop price", ctx do
      {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, ctx.membership.id, :paid)

      assert manage(ctx) =~ "R$ 45"
    end

    test "adds the slice to whoever paid this workshop alone", ctx do
      {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, ctx.membership.id, :paid)
      avulso = insert(:user, name: "Joao Souza")
      {:ok, _} = Workshops.enroll(ctx.workshop, avulso)
      {:ok, rows} = Workshops.list_enrollments_for_organizer(ctx.workshop, ctx.owner)
      row = Enum.find(rows, &(&1.user.id == avulso.id))
      {:ok, _} = Workshops.set_payment_status(ctx.workshop, ctx.owner, row.id, :paid)

      assert manage(ctx) =~ "R$ 95"
    end
  end

  describe "the program panel" do
    test "shows how the package price divides across the workshops", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}")

      assert html =~ "Como cada pacote se divide"
      assert html =~ "R$ 45"
    end
  end
end
