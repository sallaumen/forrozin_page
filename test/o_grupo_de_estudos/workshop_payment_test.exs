defmodule OGrupoDeEstudos.WorkshopPaymentTest do
  @moduledoc """
  When payment happens is a choice between two options instead of free text,
  so the page can offer the receipt shortcut.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops
  alias OGrupoDeEstudos.Workshops.Workshop

  setup do
    %{owner: insert(:user)}
  end

  describe "choosing when payment happens" do
    test "on signup, with a phone number for the receipt", ctx do
      assert {:ok, workshop} =
               Workshops.create_workshop(ctx.owner, %{
                 title: "Workshop pago",
                 description: "Conteúdo.",
                 starts_at:
                   DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second),
                 price_cents: 18_000,
                 payment_mode: :on_signup,
                 payment_phone: "(41) 99999-0000"
               })

      assert workshop.payment_mode == :on_signup
      assert workshop.payment_phone == "(41) 99999-0000"
    end

    test "at the event", ctx do
      assert {:ok, workshop} = create_workshop(ctx.owner, %{payment_mode: :at_event})

      assert workshop.payment_mode == :at_event
    end

    test "unknown payment mode is rejected instead of becoming loose text", ctx do
      assert {:error, changeset} = create_workshop(ctx.owner, %{payment_mode: :whenever})

      assert "is invalid" in errors_on(changeset).payment_mode
    end

    test "paying at the event needs no phone number", ctx do
      assert {:ok, workshop} =
               create_workshop(ctx.owner, %{payment_mode: :at_event, payment_phone: nil})

      assert workshop.payment_mode == :at_event
    end

    test "free workshop needs no payment mode", ctx do
      assert {:ok, workshop} = create_workshop(ctx.owner, %{price_cents: 0, payment_mode: nil})

      assert Workshop.free?(workshop)
    end
  end

  describe "the receipt phone number" do
    test "becomes a WhatsApp link with the workshop already in the message" do
      workshop = build(:workshop, title: "Pisada e Condução", payment_phone: "(41) 99999-0000")

      url = Workshop.receipt_link(workshop)

      assert url =~ "https://wa.me/5541999990000"
      assert url =~ "Pisada"
    end

    test "no phone number means no link",
      do: assert(is_nil(Workshop.receipt_link(build(:workshop))))

    test "number that already carries the country code does not get another" do
      workshop = build(:workshop, payment_phone: "+55 41 99999-0000")

      assert Workshop.receipt_link(workshop) =~ "wa.me/5541999990000"
    end

    test "number too short does not become a broken link" do
      workshop = build(:workshop, payment_phone: "1234")

      assert is_nil(Workshop.receipt_link(workshop))
    end
  end

  defp create_workshop(owner, extra) do
    Workshops.create_workshop(
      owner,
      Map.merge(
        %{
          title: "Workshop",
          description: "Conteúdo.",
          starts_at: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second),
          price_cents: 18_000
        },
        extra
      )
    )
  end
end
