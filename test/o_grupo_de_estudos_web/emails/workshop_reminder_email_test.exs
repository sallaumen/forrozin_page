defmodule OGrupoDeEstudosWeb.Emails.WorkshopReminderEmailTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.Emails.WorkshopReminderEmail

  @variation_indexes 0..4

  defp fake_user do
    %{name: "Lucas Tavano", username: "tata", email: "lucas@test.com"}
  end

  defp fake_workshop do
    %{
      title: "Pisada e Condução",
      slug: "pisada-e-conducao",
      location: "Espaço Cultural do Batel",
      starts_at: ~U[2026-08-20 22:00:00Z],
      ends_at: nil,
      flyer_path: nil
    }
  end

  describe "tomorrow flavor" do
    test "every variation says tomorrow and carries title, link and location" do
      for index <- @variation_indexes do
        email = WorkshopReminderEmail.new(fake_user(), fake_workshop(), :tomorrow, index)

        assert String.downcase(email.subject <> email.text_body) =~ "amanhã"
        assert email.subject <> email.html_body =~ "Pisada e Condução"
        assert email.text_body =~ "pisada-e-conducao"
        assert email.html_body =~ "Espaço Cultural do Batel"
      end
    end

    test "subjects differ across the five variations" do
      subjects =
        for index <- @variation_indexes, uniq: true do
          WorkshopReminderEmail.new(fake_user(), fake_workshop(), :tomorrow, index).subject
        end

      assert length(subjects) == 5
    end
  end

  describe "today flavor" do
    test "every variation says today and never tomorrow" do
      for index <- @variation_indexes do
        email = WorkshopReminderEmail.new(fake_user(), fake_workshop(), :today, index)
        haystack = String.downcase(email.subject <> email.text_body)

        assert haystack =~ "hoje"
        refute haystack =~ "amanhã"
      end
    end

    test "subjects differ across the five variations" do
      subjects =
        for index <- @variation_indexes, uniq: true do
          WorkshopReminderEmail.new(fake_user(), fake_workshop(), :today, index).subject
        end

      assert length(subjects) == 5
    end
  end

  describe "random pick" do
    test "stays inside the variation set of its flavor" do
      known_subjects =
        for index <- @variation_indexes do
          WorkshopReminderEmail.new(fake_user(), fake_workshop(), :today, index).subject
        end

      assert WorkshopReminderEmail.new(fake_user(), fake_workshop(), :today).subject in known_subjects
    end
  end

  describe "event banner" do
    test "a flyer stored as a full url goes into the email as it is" do
      workshop = %{fake_workshop() | flyer_path: "https://cdn.example.com/flyers/pisada.png"}

      for index <- @variation_indexes, flavor <- [:tomorrow, :today] do
        email = WorkshopReminderEmail.new(fake_user(), workshop, flavor, index)

        assert email.html_body =~ ~s(src="https://cdn.example.com/flyers/pisada.png")
      end
    end

    test "a flyer stored as a local path becomes an absolute app url" do
      workshop = %{fake_workshop() | flyer_path: "/uploads/flyers/pisada.png"}

      email = WorkshopReminderEmail.new(fake_user(), workshop, :tomorrow, 0)

      expected = OGrupoDeEstudosWeb.Endpoint.url() <> "/uploads/flyers/pisada.png"
      assert email.html_body =~ ~s(src="#{expected}")
      refute email.html_body =~ ~s(src="/uploads/)
    end

    test "no banner and no broken image without a flyer" do
      email = WorkshopReminderEmail.new(fake_user(), fake_workshop(), :tomorrow, 0)

      refute email.html_body =~ "og-image"
      refute email.html_body =~ "<img"
    end
  end

  describe "tone guard" do
    test "no variation uses an em dash in any flavor" do
      for index <- @variation_indexes, flavor <- [:tomorrow, :today] do
        email = WorkshopReminderEmail.new(fake_user(), fake_workshop(), flavor, index)

        refute email.subject =~ "—"
        refute email.text_body =~ "—"
      end
    end
  end
end
