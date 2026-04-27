defmodule OGrupoDeEstudosWeb.Emails.PasswordResetEmailTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.Emails.PasswordResetEmail

  defp fake_user do
    %{name: "Lucas", username: "tata", email: "lucas@test.com"}
  end

  describe "new/3" do
    test "first reset has polite subject" do
      email = PasswordResetEmail.new(fake_user(), "https://example.com/reset/abc", 1)

      assert email.subject == "Recuperação de senha"
      assert email.html_body =~ "Acontece com todo mundo"
    end

    test "second reset has rsrs" do
      email = PasswordResetEmail.new(fake_user(), "https://example.com/reset/abc", 2)

      assert email.subject =~ "rsrs"
      assert email.html_body =~ "rsrs"
    end

    test "third reset has suahsuhauhs" do
      email = PasswordResetEmail.new(fake_user(), "https://example.com/reset/abc", 3)

      assert email.subject =~ "suahsuhauhs"
      assert email.html_body =~ "suahsuhauhs"
    end

    test "fourth reset has kkkkkkk" do
      email = PasswordResetEmail.new(fake_user(), "https://example.com/reset/abc", 4)

      assert email.subject =~ "kkkkkkk"
    end

    test "fifth+ reset has KKKKKKKKKKYING" do
      email = PasswordResetEmail.new(fake_user(), "https://example.com/reset/abc", 5)

      assert email.subject =~ "KKKKKKKKKKYING"
      assert email.html_body =~ "servidor do Tavano"
    end

    test "includes reset URL in html and text body" do
      url = "https://example.com/reset/token123"
      email = PasswordResetEmail.new(fake_user(), url, 1)

      assert email.html_body =~ url
      assert email.text_body =~ url
    end

    test "includes user name in greeting" do
      email = PasswordResetEmail.new(fake_user(), "https://example.com/reset/x", 1)

      assert email.html_body =~ "Lucas"
      assert email.text_body =~ "Lucas"
    end

    test "uses username when name is nil" do
      user = %{name: nil, username: "tata", email: "tata@test.com"}
      email = PasswordResetEmail.new(user, "https://example.com/reset/x", 1)

      assert email.html_body =~ "tata"
    end
  end
end
