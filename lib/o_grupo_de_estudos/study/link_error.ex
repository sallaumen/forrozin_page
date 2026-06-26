defmodule OGrupoDeEstudos.Study.LinkError do
  @moduledoc """
  Domain error for teacher-student link operations (request / invite / accept /
  reject / end).

  The `:code` is the discriminator a UI layer translates into a user-facing
  message (see `OGrupoDeEstudosWeb.ErrorMessage`). Returned as data
  (`{:error, %LinkError{}}`); it is also a proper exception so it reads sanely
  if ever raised.
  """

  @type code ::
          :already_connected
          | :already_pending
          | :cannot_link_self
          | :not_teacher
          | :teacher_not_found
          | :invalid
          | :forbidden

  @type t :: %__MODULE__{code: code(), details: map() | nil}

  defexception [:code, details: nil]

  @impl true
  def message(%__MODULE__{code: code}), do: "teacher-student link error: #{code}"

  @doc "Builds a `%LinkError{}` with the given `code`."
  @spec new(code(), map() | nil) :: t()
  def new(code, details \\ nil), do: %__MODULE__{code: code, details: details}
end
