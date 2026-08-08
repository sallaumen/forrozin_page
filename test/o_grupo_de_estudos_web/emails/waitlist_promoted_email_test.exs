defmodule OGrupoDeEstudosWeb.Emails.WaitlistPromotedEmailTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.Emails.WaitlistPromotedEmail

  defp fake_user do
    %{name: "Maria Silva", username: "mariasilva", email: "maria@test.com"}
  end

  defp fake_workshop do
    %{
      title: "Pisada e Condução",
      slug: "pisada-e-conducao",
      location: "Espaço Cultural do Batel",
      starts_at: ~U[2026-08-20 22:00:00Z],
      ends_at: nil,
      flyer_path: "https://cdn.example.com/flyers/pisada.png"
    }
  end

  describe "capacity increased flavor" do
    test "says the seats grew and the person is in" do
      email = WaitlistPromotedEmail.new(fake_user(), fake_workshop(), :capacity_increased)

      assert email.subject =~ "você entrou"
      assert email.text_body =~ "vagas"
      assert email.text_body =~ "pisada-e-conducao"
      assert email.html_body =~ ~s(src="https://cdn.example.com/flyers/pisada.png")
    end
  end

  describe "seat freed flavor" do
    test "says a seat opened and it was theirs" do
      email = WaitlistPromotedEmail.new(fake_user(), fake_workshop(), :seat_freed)

      assert email.subject =~ "vaga"
      assert email.text_body =~ "vaga"
      assert email.text_body =~ "pisada-e-conducao"
    end
  end

  describe "tone guard" do
    test "no em dash in any flavor" do
      for reason <- [:capacity_increased, :seat_freed] do
        email = WaitlistPromotedEmail.new(fake_user(), fake_workshop(), reason)

        refute email.subject =~ "—"
        refute email.html_body =~ "—"
        refute email.text_body =~ "—"
      end
    end
  end
end
