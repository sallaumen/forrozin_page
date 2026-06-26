defmodule OGrupoDeEstudosWeb.ErrorMessage do
  @moduledoc """
  Central translator from domain errors to clear, friendly pt-BR flash messages.

  One home for user-facing error copy, so the same error reads the same warm,
  clear way everywhere (no more per-LiveView copy drift). Pattern-matches domain
  error structs (e.g. `Study.LinkError`) and cross-cutting atoms, with a
  reassuring fallback. The bar: every message should make the situation clearer
  for the person reading it, never colder or vaguer.
  """

  alias OGrupoDeEstudos.Study.LinkError

  @doc """
  Translates a domain error into a user-facing pt-BR string.

  The caller still decides the flash level (`:info` vs `:error`) and any
  navigation, since those are context decisions.
  """
  @spec to_flash(term()) :: String.t()
  def to_flash(%LinkError{code: code}), do: link_error(code)

  def to_flash(:rate_limited), do: "Calma! Muitas ações seguidas. Espere alguns segundinhos."
  def to_flash(:unauthorized), do: "Você não tem permissão para isso."
  def to_flash(:unauthenticated), do: "Faça login para continuar."

  def to_flash(_other), do: "Algo deu errado. Tente de novo em instantes."

  @doc """
  Suggests a flash level for an error: `:info` for benign "already done" states
  (so they read as gentle notices, not failures), `:error` otherwise.
  """
  @spec flash_level(term()) :: :info | :error
  def flash_level(%LinkError{code: code}) when code in [:already_connected, :already_pending],
    do: :info

  def flash_level(_other), do: :error

  # Teacher-student link errors — warm and specific.
  defp link_error(:already_connected), do: "Vocês já estudam juntos!"
  defp link_error(:already_pending), do: "Pedido já enviado. Aguarde a resposta."
  defp link_error(:cannot_link_self), do: "Você não pode ser aluno de si mesmo."
  defp link_error(:not_teacher), do: "Apenas professores podem convidar alunos."
  defp link_error(:teacher_not_found), do: "Professor não encontrado."
  defp link_error(:invalid), do: "Você não pode aceitar um pedido que você mesmo enviou."
  defp link_error(:forbidden), do: "Você não pode encerrar esta conexão."
end
