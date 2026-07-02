defmodule OGrupoDeEstudosWeb.Helpers.EngagementMessages do
  @moduledoc """
  Mensagens de erro (PT-BR) para ações de engajamento na borda.

  Traduz os motivos internos dos contextos (`:rate_limited`, changesets,
  códigos de aplicação de sugestão) em texto de flash — a borda faz
  pattern match aqui em vez de engolir `{:error, _}` em silêncio.
  """

  @rate_limited "Calma! Muitas ações seguidas — espera alguns segundos."

  @spec like_error(term()) :: String.t()
  def like_error(:rate_limited), do: @rate_limited
  def like_error(_reason), do: "Não foi possível registrar a curtida."

  @spec favorite_error(term()) :: String.t()
  def favorite_error(:rate_limited), do: @rate_limited
  def favorite_error(_reason), do: "Não foi possível favoritar agora."

  @spec teacher_note_error(term()) :: String.t()
  def teacher_note_error(:unauthorized), do: "Sem permissão para editar esta anotação."
  def teacher_note_error(_reason), do: "Não foi possível salvar a anotação."

  @spec suggestion_review_error(term()) :: String.t()
  def suggestion_review_error(:step_not_found), do: "O passo desta sugestão não existe mais."

  def suggestion_review_error(:steps_not_found),
    do: "Os passos da conexão sugerida não existem mais."

  def suggestion_review_error(:invalid_connection_format),
    do: "Formato de conexão inválido na sugestão."

  def suggestion_review_error(_reason), do: "Erro ao aplicar a sugestão."
end
