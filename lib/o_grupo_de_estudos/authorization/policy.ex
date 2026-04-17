defmodule OGrupoDeEstudos.Authorization.Policy do
  @moduledoc """
  Centralized authorization rules.

  Pattern: `authorize(action, user, resource) :: :ok | {:error, reason}`

  Uses pattern matching to enforce authorization policies:
  - Admin rules are checked first (catch-all)
  - Resource ownership rules follow
  - Fallthrough returns unauthorized/unauthenticated
  """

  alias OGrupoDeEstudos.Accounts.User

  # ===== Comment Management =====

  @doc """
  Delete comment authorization.

  Rules:
  - Admin can delete any comment
  - Author can delete their own comment
  - Other users cannot delete comments

  Also handles create_comment action:
  - Authenticated user can create comments
  - Nil user cannot
  """
  def authorize(:delete_comment, %User{role: "admin"}, _comment), do: :ok

  def authorize(:delete_comment, %User{id: user_id}, %{user_id: comment_user_id})
      when user_id == comment_user_id,
      do: :ok

  def authorize(:delete_comment, _, _), do: {:error, :unauthorized}

  def authorize(:create_comment, %User{}, _), do: :ok

  def authorize(:create_comment, nil, _), do: {:error, :unauthenticated}
end
