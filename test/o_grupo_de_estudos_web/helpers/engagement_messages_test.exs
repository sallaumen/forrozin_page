defmodule OGrupoDeEstudosWeb.Helpers.EngagementMessagesTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.Helpers.EngagementMessages

  test "rate limit has a friendly message for likes and favorites" do
    assert EngagementMessages.like_error(:rate_limited) =~ "Calma"
    assert EngagementMessages.favorite_error(:rate_limited) =~ "Calma"
  end

  test "generic errors have a specific message per action" do
    assert EngagementMessages.like_error(%Ecto.Changeset{}) =~ "curtida"
    assert EngagementMessages.favorite_error(:whatever) =~ "favoritar"
  end

  test "teacher note distinguishes permission from failure" do
    assert EngagementMessages.teacher_note_error(:unauthorized) =~ "Sem permissão"
    assert EngagementMessages.teacher_note_error(%Ecto.Changeset{}) =~ "salvar a anotação"
  end

  test "suggestion review maps the application codes" do
    assert EngagementMessages.suggestion_review_error(:step_not_found) =~ "não existe mais"
    assert EngagementMessages.suggestion_review_error(:steps_not_found) =~ "conexão"
    assert EngagementMessages.suggestion_review_error(:invalid_connection_format) =~ "inválido"
    assert EngagementMessages.suggestion_review_error(:other) =~ "aplicar"
  end
end
