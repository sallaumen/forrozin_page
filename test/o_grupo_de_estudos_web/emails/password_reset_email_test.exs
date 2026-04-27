defmodule OGrupoDeEstudosWeb.Emails.PasswordResetEmailTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.Emails.PasswordResetEmail

  defp fake_user do
    %{name: "Lucas", username: "tata", email: "lucas@test.com"}
  end

  describe "new/3" do
    test "subject is always fixed" do
      for count <- [1, 2, 3, 4, 5] do
        email = PasswordResetEmail.new(fake_user(), "https://example.com/reset/abc", count)
        assert email.subject == "Recuperação de senha"
      end
    end

    test "first reset has polite body" do
      email = PasswordResetEmail.new(fake_user(), "https://example.com/reset/abc", 1)
      assert email.html_body =~ "Acontece com todo mundo"
    end

    test "second reset has rsrs in body" do
      email = PasswordResetEmail.new(fake_user(), "https://example.com/reset/abc", 2)
      assert email.html_body =~ "rsrs"
    end

    test "third reset has suahsuhauhs in body" do
      email = PasswordResetEmail.new(fake_user(), "https://example.com/reset/abc", 3)
      assert email.html_body =~ "suahsuhauhs"
    end

    test "fourth reset has kkkkkkk in body" do
      email = PasswordResetEmail.new(fake_user(), "https://example.com/reset/abc", 4)
      assert email.html_body =~ "kkkkkkk"
    end

    test "fifth+ reset has KKKKKKKKKKYING in body" do
      email = PasswordResetEmail.new(fake_user(), "https://example.com/reset/abc", 5)
      assert email.html_body =~ "KKKKKKKKKKYING"
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
