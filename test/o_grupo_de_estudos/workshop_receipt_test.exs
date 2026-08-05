defmodule OGrupoDeEstudos.WorkshopReceiptTest do
  @moduledoc """
  Sending the payment receipt without leaving the app.

  The receipt used to go by WhatsApp, and someone once posted it in the gallery
  by mistake. Here it has its own place: attached to the enrollment, private to
  whoever sent it and whoever runs the class, next to the button that confirms
  the payment.
  """

  use OGrupoDeEstudos.DataCase, async: false

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    dir = Path.join(System.tmp_dir!(), "receipt_test_#{System.unique_integer([:positive])}")
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

    source = Path.join(dir, "comprovante.png")
    File.write!(source, @png)

    organizer = insert(:user, is_teacher: true)
    student = insert(:user)
    workshop = insert(:workshop, organizer: organizer, price_cents: 5000)
    {:ok, _} = Workshops.enroll(workshop, student)

    %{dir: dir, source: source, organizer: organizer, student: student, workshop: workshop}
  end

  defp upload(ctx, overrides \\ %{}) do
    Map.merge(
      %{tmp_path: ctx.source, content_type: "image/png", byte_size: byte_size(@png)},
      overrides
    )
  end

  describe "send_workshop_receipt/3" do
    test "whoever enrolled sends it and the file is served back", ctx do
      assert {:ok, enrollment} =
               Workshops.send_workshop_receipt(ctx.workshop, ctx.student, upload(ctx))

      assert enrollment.receipt_key =~ ~r{^workshop_receipts/}
      assert enrollment.receipt_content_type == "image/png"
      assert %DateTime{} = enrollment.receipt_sent_at
      assert {:file, _path} = Workshops.serve_receipt(enrollment)
    end

    test "a PDF goes through, since that is what a bank app exports", ctx do
      assert {:ok, enrollment} =
               Workshops.send_workshop_receipt(
                 ctx.workshop,
                 ctx.student,
                 upload(ctx, %{content_type: "application/pdf"})
               )

      assert enrollment.receipt_content_type == "application/pdf"
    end

    test "sending again replaces the file instead of piling up", ctx do
      {:ok, first} = Workshops.send_workshop_receipt(ctx.workshop, ctx.student, upload(ctx))
      {:file, old_path} = Workshops.serve_receipt(first)

      assert {:ok, second} =
               Workshops.send_workshop_receipt(ctx.workshop, ctx.student, upload(ctx))

      assert second.receipt_key != first.receipt_key
      refute File.exists?(old_path)
    end

    test "whoever is not in the workshop sends nothing", ctx do
      assert {:error, :not_enrolled} =
               Workshops.send_workshop_receipt(ctx.workshop, insert(:user), upload(ctx))
    end

    test "a type that is neither image nor PDF is refused", ctx do
      assert {:error, :unsupported_type} =
               Workshops.send_workshop_receipt(
                 ctx.workshop,
                 ctx.student,
                 upload(ctx, %{content_type: "text/html"})
               )
    end

    test "a file above the limit is refused", ctx do
      assert {:error, :too_large} =
               Workshops.send_workshop_receipt(
                 ctx.workshop,
                 ctx.student,
                 upload(ctx, %{byte_size: 20_000_000})
               )
    end

    test "it notifies whoever runs the workshop", ctx do
      {:ok, _} = Workshops.send_workshop_receipt(ctx.workshop, ctx.student, upload(ctx))

      assert [notification] = notifications_for(ctx.organizer, :receipt_sent)
      assert notification.actor_id == ctx.student.id
      assert notification.parent_id == ctx.workshop.id
    end
  end

  describe "remove_workshop_receipt/3" do
    setup ctx do
      {:ok, enrollment} = Workshops.send_workshop_receipt(ctx.workshop, ctx.student, upload(ctx))
      Map.put(ctx, :enrollment, enrollment)
    end

    test "whoever sent it takes it down and the file goes with it", ctx do
      {:file, path} = Workshops.serve_receipt(ctx.enrollment)

      assert {:ok, enrollment} =
               Workshops.remove_workshop_receipt(ctx.workshop, ctx.student, ctx.enrollment.id)

      assert is_nil(enrollment.receipt_key)
      assert is_nil(enrollment.receipt_sent_at)
      refute File.exists?(path)
    end

    test "whoever runs the workshop takes it down too", ctx do
      assert {:ok, _} =
               Workshops.remove_workshop_receipt(ctx.workshop, ctx.organizer, ctx.enrollment.id)
    end

    test "another person in the class does not", ctx do
      other = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, other)

      assert {:error, :unauthorized} =
               Workshops.remove_workshop_receipt(ctx.workshop, other, ctx.enrollment.id)
    end

    test "an enrollment from another workshop finds nothing", ctx do
      elsewhere = insert(:workshop, organizer: ctx.organizer)

      assert {:error, :not_found} =
               Workshops.remove_workshop_receipt(elsewhere, ctx.student, ctx.enrollment.id)
    end
  end

  describe "the package receipt" do
    setup ctx do
      program = insert(:workshop_program, owner: ctx.organizer, price_cents: 12_000)
      workshop = insert(:workshop, organizer: ctx.organizer, program: program)
      buyer = insert(:user)
      {:ok, _} = Workshops.enroll_in_package(program, buyer)

      Map.merge(ctx, %{program: program, buyer: buyer, program_workshop: workshop})
    end

    test "whoever bought the package sends the receipt", ctx do
      assert {:ok, enrollment} =
               Workshops.send_program_receipt(ctx.program, ctx.buyer, upload(ctx))

      assert enrollment.receipt_key =~ ~r{^program_receipts/}
      assert {:file, _path} = Workshops.serve_receipt(enrollment)
    end

    test "whoever did not buy it sends nothing", ctx do
      assert {:error, :not_enrolled} =
               Workshops.send_program_receipt(ctx.program, insert(:user), upload(ctx))
    end

    test "whoever owns the program takes the receipt down", ctx do
      {:ok, enrollment} = Workshops.send_program_receipt(ctx.program, ctx.buyer, upload(ctx))

      assert {:ok, cleared} =
               Workshops.remove_program_receipt(ctx.program, ctx.organizer, enrollment.id)

      assert is_nil(cleared.receipt_key)
    end

    test "an outsider takes nothing down", ctx do
      {:ok, enrollment} = Workshops.send_program_receipt(ctx.program, ctx.buyer, upload(ctx))

      assert {:error, :unauthorized} =
               Workshops.remove_program_receipt(ctx.program, insert(:user), enrollment.id)
    end
  end

  describe "which path people take" do
    test "opening WhatsApp is recorded once per person", ctx do
      assert {:ok, first} = Workshops.mark_whatsapp_receipt(ctx.workshop, ctx.student)
      assert %DateTime{} = first.whatsapp_opened_at

      assert {:ok, second} = Workshops.mark_whatsapp_receipt(ctx.workshop, ctx.student)
      assert second.whatsapp_opened_at == first.whatsapp_opened_at
    end

    test "whoever is not in the workshop records nothing", ctx do
      assert {:error, :not_enrolled} =
               Workshops.mark_whatsapp_receipt(ctx.workshop, insert(:user))
    end

    test "the summary separates app from WhatsApp", ctx do
      other = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, other)

      {:ok, _} = Workshops.send_workshop_receipt(ctx.workshop, ctx.student, upload(ctx))
      {:ok, _} = Workshops.mark_whatsapp_receipt(ctx.workshop, other)

      assert %{app: 1, whatsapp: 1} = Workshops.receipt_summary(ctx.workshop.id)
    end

    test "a workshop nobody paid for reports zeros", ctx do
      assert %{app: 0, whatsapp: 0} = Workshops.receipt_summary(ctx.workshop.id)
    end
  end

  defp notifications_for(user, action) do
    import Ecto.Query
    alias OGrupoDeEstudos.Engagement.Notifications.Notification

    OGrupoDeEstudos.Repo.all(
      from n in Notification, where: n.user_id == ^user.id and n.action == ^action
    )
  end
end
