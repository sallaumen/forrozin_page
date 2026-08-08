defmodule OGrupoDeEstudosWeb.Emails.TeacherReminderEmailTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.Emails.TeacherReminderEmail

  defp fake_teacher do
    %{name: "Lucas Tavano", username: "tata", email: "lucas@test.com"}
  end

  defp fake_workshop do
    %{
      title: "Pisada e Condução",
      slug: "pisada-e-conducao",
      location: "Espaço Cultural do Batel",
      starts_at: ~U[2026-08-20 22:00:00Z],
      ends_at: nil,
      capacity: 30
    }
  end

  defp fake_participants do
    [%{name: "Maria Silva", username: "mariasilva"}, %{name: nil, username: "ze_do_forro"}]
  end

  describe "tomorrow flavor" do
    test "carries the headcount, the roster and the manage link" do
      email =
        TeacherReminderEmail.new(fake_teacher(), fake_workshop(), fake_participants(), 3,
          flavor: :tomorrow
        )

      assert email.subject =~ "Amanhã"
      assert email.subject =~ "2 inscritos"
      assert email.html_body =~ "Maria Silva"
      assert email.html_body =~ "ze_do_forro"
      assert email.html_body =~ "2 de 30"
      assert email.html_body =~ "3 na lista de espera"
      assert email.html_body =~ "/workshops/pisada-e-conducao/manage"
      assert email.text_body =~ "Maria Silva"
    end
  end

  describe "today flavor" do
    test "says today and never tomorrow" do
      email =
        TeacherReminderEmail.new(fake_teacher(), fake_workshop(), fake_participants(), 0,
          flavor: :today
        )

      haystack = String.downcase(email.subject <> email.text_body)
      assert haystack =~ "hoje"
      refute haystack =~ "amanhã"
    end
  end

  describe "empty states" do
    test "an empty roster says so instead of listing nothing" do
      email = TeacherReminderEmail.new(fake_teacher(), fake_workshop(), [], 0, flavor: :tomorrow)

      assert email.subject =~ "0 inscritos"
      assert email.html_body =~ "Ainda ninguém confirmado"
    end

    test "no waitlist line when the waitlist is empty" do
      email =
        TeacherReminderEmail.new(fake_teacher(), fake_workshop(), fake_participants(), 0,
          flavor: :tomorrow
        )

      refute email.html_body =~ "lista de espera"
    end

    test "headcount stands alone without capacity" do
      workshop = %{fake_workshop() | capacity: nil}

      email =
        TeacherReminderEmail.new(fake_teacher(), workshop, fake_participants(), 0,
          flavor: :tomorrow
        )

      assert email.subject =~ "2 inscritos"
      refute email.html_body =~ "2 de "
    end
  end

  describe "tone guard" do
    test "no em dash in any flavor" do
      for flavor <- [:tomorrow, :today] do
        email =
          TeacherReminderEmail.new(fake_teacher(), fake_workshop(), fake_participants(), 1,
            flavor: flavor
          )

        refute email.subject =~ "—"
        refute email.text_body =~ "—"
        refute email.html_body =~ "—"
      end
    end
  end
end
