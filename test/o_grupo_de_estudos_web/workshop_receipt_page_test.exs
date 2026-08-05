defmodule OGrupoDeEstudosWeb.WorkshopReceiptPageTest do
  @moduledoc """
  Sending the receipt from the workshop page.

  The two paths live side by side: through the app, which lands next to the
  payment control, and through WhatsApp, which is where people already are.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Workshops

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    dir = Path.join(System.tmp_dir!(), "receipt_page_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    previous = Application.get_env(:o_grupo_de_estudos, :uploads_path)
    Application.put_env(:o_grupo_de_estudos, :uploads_path, dir)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:o_grupo_de_estudos, :uploads_path)
        value -> Application.put_env(:o_grupo_de_estudos, :uploads_path, value)
      end

      File.rm_rf!(dir)
    end)

    organizer = insert(:user, is_teacher: true)
    student = insert(:user)

    workshop =
      insert(:workshop,
        organizer: organizer,
        price_cents: 5000,
        payment_phone: "41999998888"
      )

    {:ok, _} = Workshops.enroll(workshop, student)

    %{organizer: organizer, student: student, workshop: workshop}
  end

  defp open(conn, user, workshop),
    do: live(log_in_user(conn, user), ~p"/workshops/#{workshop.slug}")

  defp attach_receipt(lv) do
    file =
      file_input(lv, "#receipt-form", :receipt, [
        %{name: "comprovante.png", content: @png, type: "image/png"}
      ])

    render_upload(file, "comprovante.png")
    lv |> element("#receipt-form") |> render_submit()
  end

  describe "whoever is in a paid workshop" do
    test "sends the receipt through the page", ctx do
      {:ok, lv, _} = open(ctx.conn, ctx.student, ctx.workshop)

      assert attach_receipt(lv) =~ "Comprovante enviado"

      assert %{sent_at: %DateTime{}} = Workshops.my_receipt(ctx.workshop, ctx.student)
    end

    test "sees when it was sent, and can swap or remove it", ctx do
      {:ok, lv, _} = open(ctx.conn, ctx.student, ctx.workshop)
      attach_receipt(lv)

      {:ok, lv, html} = open(ctx.conn, ctx.student, ctx.workshop)

      assert html =~ "Enviado em"
      assert html =~ "Trocar comprovante"

      lv |> element("button[phx-click='remove_receipt']") |> render_click()

      assert %{sent_at: nil} = Workshops.my_receipt(ctx.workshop, ctx.student)
    end

    test "choosing WhatsApp instead is recorded", ctx do
      {:ok, lv, _} = open(ctx.conn, ctx.student, ctx.workshop)

      lv |> element("a[phx-click='receipt_via_whatsapp']") |> render_click()

      assert %{app: 0, whatsapp: 1} = Workshops.receipt_summary(ctx.workshop.id)
    end
  end

  describe "whoever has no receipt to send" do
    test "a free workshop offers no box", ctx do
      free = insert(:workshop, organizer: ctx.organizer)
      {:ok, _} = Workshops.enroll(free, ctx.student)

      {:ok, _lv, html} = open(ctx.conn, ctx.student, free)

      refute html =~ "Escolher comprovante"
    end

    test "whoever is not in the class sees no box", ctx do
      {:ok, _lv, html} = open(ctx.conn, insert(:user), ctx.workshop)

      refute html =~ "Escolher comprovante"
    end
  end

  describe "the panel of whoever runs the workshop" do
    test "links the receipt and separates the two paths", ctx do
      {:ok, lv, _} = open(ctx.conn, ctx.student, ctx.workshop)
      attach_receipt(lv)

      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.organizer), ~p"/workshops/#{ctx.workshop.slug}/manage")

      assert html =~ "Ver comprovante"
      assert html =~ "pelo app"
    end

    test "with nothing sent, there is no link to open", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.organizer), ~p"/workshops/#{ctx.workshop.slug}/manage")

      refute html =~ "Ver comprovante"
    end
  end
end
