defmodule OGrupoDeEstudos.WorkshopPaymentTest do
  @moduledoc """
  Como as pessoas pagam deixa de ser texto livre.

  Antes era um campo aberto ("Pix na inscrição, dinheiro na hora..."), e texto
  livre o sistema não consegue usar: não dava para mostrar o jeito certo de
  pagar nem oferecer o atalho de mandar o comprovante. Agora o **quando** é
  uma escolha entre duas opções, e quem paga na inscrição tem para onde mandar
  o comprovante.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops
  alias OGrupoDeEstudos.Workshops.Workshop

  setup do
    %{dono: insert(:user)}
  end

  describe "escolher quando se paga" do
    test "na inscrição, com telefone para o comprovante", ctx do
      assert {:ok, workshop} =
               Workshops.create_workshop(ctx.dono, %{
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

    test "na hora do evento", ctx do
      assert {:ok, workshop} = criar(ctx.dono, %{payment_mode: :at_event})

      assert workshop.payment_mode == :at_event
    end

    test "modo que não existe é recusado, em vez de virar texto solto", ctx do
      assert {:error, changeset} = criar(ctx.dono, %{payment_mode: :quando_der})

      assert "is invalid" in errors_on(changeset).payment_mode
    end

    test "pagar na hora do evento não precisa de telefone", ctx do
      assert {:ok, workshop} = criar(ctx.dono, %{payment_mode: :at_event, payment_phone: nil})

      assert workshop.payment_mode == :at_event
    end

    test "workshop gratuito não precisa de modo nenhum", ctx do
      assert {:ok, workshop} = criar(ctx.dono, %{price_cents: 0, payment_mode: nil})

      assert Workshop.free?(workshop)
    end
  end

  describe "o telefone do comprovante" do
    test "vira um link de WhatsApp com o workshop já na mensagem" do
      workshop = build(:workshop, title: "Pisada e Condução", payment_phone: "(41) 99999-0000")

      url = Workshop.receipt_link(workshop)

      # Só dígitos com DDI: é o formato que o wa.me aceita.
      assert url =~ "https://wa.me/5541999990000"
      assert url =~ "Pisada"
    end

    test "sem telefone não há link", do: assert(is_nil(Workshop.receipt_link(build(:workshop))))

    test "número que já vem com DDI não ganha outro" do
      workshop = build(:workshop, payment_phone: "+55 41 99999-0000")

      assert Workshop.receipt_link(workshop) =~ "wa.me/5541999990000"
    end

    test "número curto demais não vira link quebrado" do
      workshop = build(:workshop, payment_phone: "1234")

      assert is_nil(Workshop.receipt_link(workshop))
    end
  end

  defp criar(dono, extra) do
    Workshops.create_workshop(
      dono,
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
