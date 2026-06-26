defmodule OGrupoDeEstudosWeb.ErrorMessageTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Study.LinkError
  alias OGrupoDeEstudosWeb.ErrorMessage

  describe "to_flash/1 — teacher-student link errors" do
    test "already_connected reads warm and positive" do
      assert ErrorMessage.to_flash(LinkError.new(:already_connected)) ==
               "Vocês já estudam juntos!"
    end

    test "already_pending is clear and reassuring" do
      assert ErrorMessage.to_flash(LinkError.new(:already_pending)) ==
               "Pedido já enviado. Aguarde a resposta."
    end

    test "cannot_link_self explains the constraint plainly" do
      assert ErrorMessage.to_flash(LinkError.new(:cannot_link_self)) ==
               "Você não pode ser aluno de si mesmo."
    end

    test "not_teacher explains who can invite" do
      assert ErrorMessage.to_flash(LinkError.new(:not_teacher)) ==
               "Apenas professores podem convidar alunos."
    end

    test "teacher_not_found" do
      assert ErrorMessage.to_flash(LinkError.new(:teacher_not_found)) ==
               "Professor não encontrado."
    end

    test "invalid (accepting own request)" do
      assert ErrorMessage.to_flash(LinkError.new(:invalid)) ==
               "Você não pode aceitar um pedido que você mesmo enviou."
    end

    test "forbidden (ending someone else's link)" do
      assert ErrorMessage.to_flash(LinkError.new(:forbidden)) ==
               "Você não pode encerrar esta conexão."
    end

    test "every LinkError code has a non-empty message with no em dash" do
      for code <- ~w(already_connected already_pending cannot_link_self not_teacher
                     teacher_not_found invalid forbidden)a do
        msg = ErrorMessage.to_flash(LinkError.new(code))
        assert is_binary(msg) and msg != ""
        refute msg =~ "—", "message for #{code} contains an em dash (marca de IA)"
      end
    end
  end

  describe "to_flash/1 — cross-cutting atoms" do
    test "rate_limited stays friendly" do
      assert ErrorMessage.to_flash(:rate_limited) =~ "Calma!"
    end

    test "unauthorized" do
      assert ErrorMessage.to_flash(:unauthorized) == "Você não tem permissão para isso."
    end

    test "unauthenticated" do
      assert ErrorMessage.to_flash(:unauthenticated) == "Faça login para continuar."
    end

    test "unknown errors get a reassuring fallback" do
      assert ErrorMessage.to_flash(:something_weird) ==
               "Algo deu errado. Tente de novo em instantes."

      assert ErrorMessage.to_flash(%Ecto.Changeset{}) ==
               "Algo deu errado. Tente de novo em instantes."
    end
  end

  describe "flash_level/1" do
    test "benign already-done states are :info" do
      assert ErrorMessage.flash_level(LinkError.new(:already_connected)) == :info
      assert ErrorMessage.flash_level(LinkError.new(:already_pending)) == :info
    end

    test "real failures are :error" do
      assert ErrorMessage.flash_level(LinkError.new(:cannot_link_self)) == :error
      assert ErrorMessage.flash_level(LinkError.new(:invalid)) == :error
      assert ErrorMessage.flash_level(:rate_limited) == :error
      assert ErrorMessage.flash_level(:anything) == :error
    end
  end
end
