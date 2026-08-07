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

  describe "the program backstage" do
    test "shows how the package price divides across the workshops", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}/manage")

      assert html =~ "Como cada pacote se divide"
      assert html =~ "R$ 45"
    end

    test "balances the whole event: what came from packages and what came loose", ctx do
      {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, ctx.membership.id, :paid)
      avulso = insert(:user, name: "Joao Souza")
      {:ok, _} = Workshops.enroll(ctx.workshop, avulso)
      {:ok, rows} = Workshops.list_enrollments_for_organizer(ctx.workshop, ctx.owner)
      row = Enum.find(rows, &(&1.user.id == avulso.id))
      {:ok, _} = Workshops.set_payment_status(ctx.workshop, ctx.owner, row.id, :paid)

      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}/manage")

      assert html =~ "Balanço da programação"
      assert html =~ "Total do evento"
      assert html =~ "pacote R$ 45 · avulso R$ 50"
      assert html =~ "R$ 140"
    end

    test "says plainly when a workshop has not received anything", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}/manage")

      assert html =~ "ninguém pagou ainda"
    end

    test "the balance stays behind the owner's door: the page does not even open", ctx do
      assert {:error, {:redirect, %{to: "/study/workshops"}}} =
               live(
                 log_in_user(ctx.conn, insert(:user)),
                 ~p"/programs/#{ctx.program.slug}/manage"
               )
    end
  end

  describe "waiving a package" do
    defp program_manage(ctx) do
      live(log_in_user(ctx.conn, ctx.owner), ~p"/programs/#{ctx.program.slug}/manage")
    end

    defp waive_button(id), do: ~s{button[phx-value-id="#{id}"][phx-value-status="waived"]}
    defp undo_button(id), do: ~s{button[phx-value-id="#{id}"][phx-value-status="pending"]}

    test "a pending package offers the waive, like a workshop does", ctx do
      {:ok, lv, _html} = program_manage(ctx)

      assert has_element?(lv, waive_button(ctx.membership.id), "Isentar")
    end

    test "waiving reads as waived and charges nothing", ctx do
      {:ok, lv, _html} = program_manage(ctx)

      html =
        render_click(lv, "set_package_payment", %{
          "id" => ctx.membership.id,
          "status" => "waived"
        })

      assert html =~ "Isento"
      refute html =~ "R$ 45,00 no recebido"
      assert {:ok, summary} = Workshops.package_summary(ctx.program, ctx.owner)
      assert summary.waived == 1
      assert summary.revenue_cents == 0
    end

    test "a waived package can be undone straight back to pending", ctx do
      {:ok, _} =
        Workshops.set_package_payment(ctx.program, ctx.owner, ctx.membership.id, :waived)

      {:ok, lv, _html} = program_manage(ctx)

      assert has_element?(lv, undo_button(ctx.membership.id), "Desfazer")

      html =
        render_click(lv, "set_package_payment", %{
          "id" => ctx.membership.id,
          "status" => "pending"
        })

      assert html =~ "Aguardando"
    end

    test "the summary names the waived instead of letting them read as debtors", ctx do
      {:ok, _} =
        Workshops.set_package_payment(ctx.program, ctx.owner, ctx.membership.id, :waived)

      {:ok, _lv, html} = program_manage(ctx)

      assert html =~ ~r{>1</b>\s*isento}
    end

    test "a paid package does not offer the waive", ctx do
      {:ok, _} = Workshops.set_package_payment(ctx.program, ctx.owner, ctx.membership.id, :paid)

      {:ok, lv, _html} = program_manage(ctx)

      refute has_element?(lv, waive_button(ctx.membership.id))
    end
  end

  describe "undoing a waive on the workshop panel" do
    test "a waived daily enrollment also goes straight back to pending", ctx do
      person = insert(:user, name: "Isenta Da Silva")
      {:ok, _} = Workshops.enroll(ctx.workshop, person)
      {:ok, rows} = Workshops.list_enrollments_for_organizer(ctx.workshop, ctx.owner)
      row = Enum.find(rows, &(&1.user.id == person.id))
      {:ok, _} = Workshops.set_payment_status(ctx.workshop, ctx.owner, row.id, :waived)

      {:ok, lv, _html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/workshops/#{ctx.workshop.slug}/manage")

      assert has_element?(
               lv,
               ~s{button[phx-value-id="#{row.id}"][phx-value-status="pending"]},
               "Desfazer"
             )
    end
  end
end
