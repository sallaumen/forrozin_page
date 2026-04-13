defmodule Forrozin.Workers.EnviarEmailConfirmacaoTest do
  use Forrozin.DataCase, async: true

  import Swoosh.TestAssertions

  alias Forrozin.Workers.EnviarEmailConfirmacao

  describe "perform/1" do
    test "envia email de confirmação para usuário existente" do
      user = insert(:user, confirmation_token: "token123", confirmed_at: nil)

      assert :ok = perform_job(EnviarEmailConfirmacao, %{user_id: user.id})

      assert_email_sent(subject: "Confirme seu email — Forrózin")
    end

    test "ignora silenciosamente se o usuário foi removido" do
      assert :ok = perform_job(EnviarEmailConfirmacao, %{user_id: Ecto.UUID.generate()})
      assert_no_email_sent()
    end
  end
end
