defmodule OGrupoDeEstudos.Authorization.Policy do
  @moduledoc """
  Centralized authorization rules, checked at the web boundary.

  Pattern: `authorize(action, user, resource) :: :ok | {:error, reason}`

  Uses pattern matching to enforce authorization policies:
  - Admin rules are checked first (catch-all)
  - Resource ownership rules follow
  - Fallthrough returns unauthorized/unauthenticated

  `authorized?/3` is the boolean mirror for UI flags and `if` gates.
  """

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Encyclopedia.{Step, StepLink}
  alias OGrupoDeEstudos.Sequences.Sequence

  @type reason :: :unauthorized | :unauthenticated

  @spec authorized?(atom(), User.t() | nil, struct() | nil) :: boolean()
  def authorized?(action, user, resource), do: authorize(action, user, resource) == :ok

  @spec authorize(atom(), User.t() | nil, struct() | nil) :: :ok | {:error, reason()}

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

  def authorize(:delete_comment, %User{id: user_id}, %{author_id: author_id})
      when user_id == author_id,
      do: :ok

  def authorize(:delete_comment, _, _), do: {:error, :unauthorized}

  def authorize(:create_comment, %User{}, _), do: :ok

  def authorize(:create_comment, nil, _), do: {:error, :unauthenticated}

  # ===== Encyclopedia: steps =====
  # Admin edits anything; the user who suggested a step may keep editing it.
  # Deleting, approving and section/category management are admin-only.

  def authorize(:edit_step, %User{role: "admin"}, _step), do: :ok

  def authorize(:edit_step, %User{id: user_id}, %Step{suggested_by_id: user_id}), do: :ok

  def authorize(:edit_step, _, _), do: {:error, :unauthorized}

  def authorize(:delete_step, %User{role: "admin"}, _step), do: :ok

  def authorize(:delete_step, _, _), do: {:error, :unauthorized}

  def authorize(:approve_step, %User{role: "admin"}, _step), do: :ok

  def authorize(:approve_step, _, _), do: {:error, :unauthorized}

  def authorize(:manage_section, %User{role: "admin"}, _section), do: :ok

  def authorize(:manage_section, _, _), do: {:error, :unauthorized}

  # ===== Encyclopedia: step video links =====
  # Admin manages any link; the submitter manages their own link.

  def authorize(:manage_step_link, %User{role: "admin"}, %StepLink{}), do: :ok

  def authorize(:manage_step_link, %User{id: user_id}, %StepLink{submitted_by_id: user_id}),
    do: :ok

  def authorize(:manage_step_link, _, _), do: {:error, :unauthorized}

  # ===== Sequences =====
  # Edit/delete: admin manages any sequence; the owner manages their own.

  def authorize(:manage_sequence, %User{role: "admin"}, %Sequence{}), do: :ok

  def authorize(:manage_sequence, %User{id: user_id}, %Sequence{user_id: user_id}), do: :ok

  def authorize(:manage_sequence, _, _), do: {:error, :unauthorized}
end
