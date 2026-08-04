defmodule OGrupoDeEstudos.Workshops.Access do
  @moduledoc """
  What a person can do in a workshop, resolved in one pass.

  It exists because `Authorization.Policy` is pure and does not query the
  database, but "is a co-organizer?" and "is enrolled?" are database facts. The
  boundary builds this struct once at mount and the Policy decides over it.
  """

  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{
          workshop: Workshop.t(),
          user_id: Ecto.UUID.t() | nil,
          owner?: boolean(),
          admin?: boolean(),
          enrolled?: boolean()
        }

  @enforce_keys [:workshop, :user_id, :owner?, :admin?, :enrolled?]
  defstruct [:workshop, :user_id, :owner?, :admin?, :enrolled?]
end
