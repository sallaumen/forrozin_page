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
  alias OGrupoDeEstudos.Study.Lesson
  alias OGrupoDeEstudos.Workshops.{Access, Workshop, WorkshopProgram}

  @type reason :: :unauthorized | :unauthenticated

  @spec authorized?(atom(), User.t() | nil, struct() | nil) :: boolean()
  def authorized?(action, user, resource), do: authorize(action, user, resource) == :ok

  @spec authorize(atom(), User.t() | nil, struct() | nil) :: :ok | {:error, reason()}

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
  def authorize(:delete_comment, %User{role: :admin}, _comment), do: :ok

  def authorize(:delete_comment, %User{id: user_id}, %{user_id: comment_user_id})
      when user_id == comment_user_id,
      do: :ok

  def authorize(:delete_comment, %User{id: user_id}, %{author_id: author_id})
      when user_id == author_id,
      do: :ok

  def authorize(:delete_comment, _, _), do: {:error, :unauthorized}

  def authorize(:create_comment, %User{}, _), do: :ok

  def authorize(:create_comment, nil, _), do: {:error, :unauthenticated}

  # Admin edits anything; the user who suggested a step may keep editing it.
  # Deleting, approving and section/category management are admin-only.

  def authorize(:edit_step, %User{role: :admin}, _step), do: :ok

  def authorize(:edit_step, %User{id: user_id}, %Step{suggested_by_id: user_id}), do: :ok

  def authorize(:edit_step, _, _), do: {:error, :unauthorized}

  def authorize(:delete_step, %User{role: :admin}, _step), do: :ok

  def authorize(:delete_step, _, _), do: {:error, :unauthorized}

  def authorize(:approve_step, %User{role: :admin}, _step), do: :ok

  def authorize(:approve_step, _, _), do: {:error, :unauthorized}

  def authorize(:manage_section, %User{role: :admin}, _section), do: :ok

  def authorize(:manage_section, _, _), do: {:error, :unauthorized}

  # Admin manages any link; the submitter manages their own link.

  def authorize(:manage_step_link, %User{role: :admin}, %StepLink{}), do: :ok

  def authorize(:manage_step_link, %User{id: user_id}, %StepLink{submitted_by_id: user_id}),
    do: :ok

  def authorize(:manage_step_link, _, _), do: {:error, :unauthorized}

  # Broadcasting requires being a teacher; managing belongs to the owner alone.
  # Admin is left out on purpose: the content belongs to the teacher-student link.

  def authorize(:broadcast_lesson, %User{is_teacher: true}, _), do: :ok

  def authorize(:broadcast_lesson, _, _), do: {:error, :unauthorized}

  def authorize(:manage_lesson, %User{id: teacher_id}, %Lesson{teacher_id: teacher_id}), do: :ok

  def authorize(:manage_lesson, _, _), do: {:error, :unauthorized}

  # Creating belongs to whoever teaches: organizing an event is the teaching side
  # of the app, and offering the button to every student only clutters the page
  # for the majority who will never open a class. Whoever already organizes a
  # workshop keeps managing it, because that is `manage_workshop` and it answers
  # to the organizer, admin included: payment control is internal to whoever
  # organizes.

  # A cancelled workshop keeps its conversation open: the organizer usually needs
  # it precisely to explain the cancellation. A draft does not, being private to
  # whoever organizes.
  def authorize(:comment_workshop, nil, _workshop), do: {:error, :unauthenticated}

  def authorize(:comment_workshop, %User{}, %Workshop{status: status})
      when status in [:published, :cancelled],
      do: :ok

  def authorize(:comment_workshop, _user, _workshop), do: {:error, :unauthorized}

  def authorize(:like, nil, _resource), do: {:error, :unauthenticated}
  def authorize(:like, %User{}, _resource), do: :ok

  # A draft is private to the organizer. Returns :not_found rather than
  # :unauthorized, because "no permission" already confirms a workshop exists at
  # that slug.
  #
  # A PRIVATE workshop does not come through here: private is not secret, it
  # opens for anyone. Visibility changes the door (entry by approval), not the
  # existence, and `Workshops.inside_open?/2` decides the inside.
  def authorize(:view_workshop, user, %Access{workshop: workshop}),
    do: authorize(:view_workshop, user, workshop)

  def authorize(:view_workshop, _user, %Workshop{status: status})
      when status in [:published, :cancelled],
      do: :ok

  def authorize(:view_workshop, %User{id: organizer_id}, %Workshop{organizer_id: organizer_id}),
    do: :ok

  def authorize(:view_workshop, _user, _workshop), do: {:error, :not_found}

  # A program follows the same visibility rule as a workshop: a draft belongs to
  # its creator, and the answer is :not_found so existence is not confirmed.
  def authorize(:view_program, _user, %WorkshopProgram{status: status})
      when status in [:published, :cancelled],
      do: :ok

  def authorize(:view_program, %User{id: owner_id}, %WorkshopProgram{owner_id: owner_id}),
    do: :ok

  def authorize(:view_program, _user, _program), do: {:error, :not_found}

  def authorize(:create_program, %User{is_teacher: true}, _), do: :ok
  def authorize(:create_program, %User{role: :admin}, _), do: :ok
  def authorize(:create_program, nil, _), do: {:error, :unauthenticated}
  def authorize(:create_program, %User{}, _), do: {:error, :unauthorized}

  def authorize(:manage_program, %User{id: owner_id}, %WorkshopProgram{owner_id: owner_id}),
    do: :ok

  def authorize(:manage_program, _, _), do: {:error, :unauthorized}

  def authorize(:create_workshop, %User{is_teacher: true}, _), do: :ok

  def authorize(:create_workshop, %User{role: :admin}, _), do: :ok

  def authorize(:create_workshop, nil, _), do: {:error, :unauthenticated}

  def authorize(:create_workshop, %User{}, _), do: {:error, :unauthorized}

  # Takes the resolved Access (which already accounts for co-organizers) or the
  # raw Workshop, which only knows the creator. The boundary passes Access
  # whenever the answer can depend on co-organization.
  def authorize(:manage_workshop, %User{id: user_id}, %Access{user_id: user_id, admin?: true}),
    do: :ok

  def authorize(:manage_workshop, %User{id: organizer_id}, %Workshop{organizer_id: organizer_id}),
    do: :ok

  def authorize(:manage_workshop, _, _), do: {:error, :unauthorized}

  # Edit/delete: admin manages any sequence; the owner manages their own.

  def authorize(:manage_sequence, %User{role: :admin}, %Sequence{}), do: :ok

  def authorize(:manage_sequence, %User{id: user_id}, %Sequence{user_id: user_id}), do: :ok

  def authorize(:manage_sequence, _, _), do: {:error, :unauthorized}
end
