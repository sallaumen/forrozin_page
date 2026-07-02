defmodule OGrupoDeEstudosWeb.Helpers.EngagementMessagesTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.Helpers.EngagementMessages

  test "rate limit tem mensagem amigável em likes e favoritos" do
    assert EngagementMessages.like_error(:rate_limited) =~ "Calma"
    assert EngagementMessages.favorite_error(:rate_limited) =~ "Calma"
  end

  test "erros genéricos têm mensagem específica por ação" do
    assert EngagementMessages.like_error(%Ecto.Changeset{}) =~ "curtida"
    assert EngagementMessages.favorite_error(:whatever) =~ "favoritar"
  end

  test "anotação do professor distingue permissão de falha" do
    assert EngagementMessages.teacher_note_error(:unauthorized) =~ "Sem permissão"
    assert EngagementMessages.teacher_note_error(%Ecto.Changeset{}) =~ "salvar a anotação"
  end

  test "revisão de sugestão mapeia os códigos de aplicação" do
    assert EngagementMessages.suggestion_review_error(:step_not_found) =~ "não existe mais"
    assert EngagementMessages.suggestion_review_error(:steps_not_found) =~ "conexão"
    assert EngagementMessages.suggestion_review_error(:invalid_connection_format) =~ "inválido"
    assert EngagementMessages.suggestion_review_error(:outro) =~ "aplicar"
  end
end
