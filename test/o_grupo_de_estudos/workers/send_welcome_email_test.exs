defmodule OGrupoDeEstudos.Workers.SendWelcomeEmailTest do
  use OGrupoDeEstudos.DataCase, async: true

  import Swoosh.TestAssertions

  alias OGrupoDeEstudos.Workers.SendWelcomeEmail

  describe "perform/1" do
    test "sends welcome email with confirmation link for a password signup" do
      user = insert(:user, confirmation_token: "token123", confirmed_at: nil)

      assert :ok = perform_job(SendWelcomeEmail, %{user_id: user.id})

      assert_email_sent(fn email ->
        assert {_, address} = hd(email.to)
        assert address == user.email
        assert email.text_body =~ "/confirm/token123"
      end)
    end

    test "sends welcome email without confirmation link for a google signup" do
      user = insert(:user, confirmation_token: nil, google_id: "google-sub-1")

      assert :ok = perform_job(SendWelcomeEmail, %{user_id: user.id})

      assert_email_sent(fn email ->
        refute email.text_body =~ "/confirm/"
        assert email.text_body =~ "Google"
      end)
    end

    test "silently ignores when user has been removed" do
      assert :ok = perform_job(SendWelcomeEmail, %{user_id: Ecto.UUID.generate()})
      assert_no_email_sent()
    end
  end
end
