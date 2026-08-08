defmodule OGrupoDeEstudosWeb.Emails.WelcomeEmailTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.Emails.WelcomeEmail

  @variation_indexes 0..4

  defp password_user do
    %{
      name: "Lucas Tavano",
      username: "tata",
      email: "lucas@test.com",
      confirmation_token: "tok123",
      google_id: nil
    }
  end

  defp google_user do
    %{
      name: "Maria Silva",
      username: "mariasilva",
      email: "maria@gmail.com",
      confirmation_token: nil,
      google_id: "google-sub-1"
    }
  end

  describe "password signup flavor" do
    test "every variation greets by first name and carries the confirmation link" do
      for index <- @variation_indexes do
        email = WelcomeEmail.new(password_user(), index)

        assert email.html_body =~ "Lucas"
        assert email.html_body =~ "/confirm/tok123"
        assert email.text_body =~ "/confirm/tok123"
      end
    end

    test "subjects differ across the five variations" do
      subjects =
        for index <- @variation_indexes, uniq: true do
          WelcomeEmail.new(password_user(), index).subject
        end

      assert length(subjects) == 5
    end

    test "random pick stays inside the variation set" do
      known_subjects =
        for index <- @variation_indexes do
          WelcomeEmail.new(password_user(), index).subject
        end

      assert WelcomeEmail.new(password_user()).subject in known_subjects
    end
  end

  describe "google signup flavor" do
    test "no variation asks to confirm the email" do
      for index <- @variation_indexes do
        email = WelcomeEmail.new(google_user(), index)

        refute email.html_body =~ "/confirm/"
        refute email.text_body =~ "/confirm/"
      end
    end

    test "every variation says the google email is already confirmed" do
      for index <- @variation_indexes do
        email = WelcomeEmail.new(google_user(), index)

        assert email.html_body =~ "Google"
        assert email.text_body =~ "Google"
      end
    end
  end

  describe "tone guard" do
    test "no variation uses an em dash in any flavor" do
      for index <- @variation_indexes, user <- [password_user(), google_user()] do
        email = WelcomeEmail.new(user, index)

        refute email.subject =~ "—"
        refute email.html_body =~ "—"
        refute email.text_body =~ "—"
      end
    end
  end
end
