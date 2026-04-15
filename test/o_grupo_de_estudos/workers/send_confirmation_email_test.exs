defmodule OGrupoDeEstudos.Workers.SendConfirmationEmailTest do
  use OGrupoDeEstudos.DataCase, async: true

  import Swoosh.TestAssertions

  alias OGrupoDeEstudos.Workers.SendConfirmationEmail

  describe "perform/1" do
    test "sends confirmation email for existing user" do
      user = insert(:user, confirmation_token: "token123", confirmed_at: nil)

      assert :ok = perform_job(SendConfirmationEmail, %{user_id: user.id})

      assert_email_sent(subject: "Confirme seu email — Forrózin")
    end

    test "silently ignores when user has been removed" do
      assert :ok = perform_job(SendConfirmationEmail, %{user_id: Ecto.UUID.generate()})
      assert_no_email_sent()
    end
  end
end
