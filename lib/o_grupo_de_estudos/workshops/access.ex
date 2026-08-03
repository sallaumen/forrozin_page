defmodule OGrupoDeEstudos.Workshops.Access do
  @moduledoc """
  O que uma pessoa pode fazer num workshop, resolvido de uma vez.

  Existe porque `Authorization.Policy` é pura e não consulta o banco, mas
  "é co-organizador?" e "está inscrito?" são fatos do banco. A borda monta
  este struct uma vez no mount e a Policy decide em cima dele.
  """

  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{
          workshop: Workshop.t(),
          user_id: Ecto.UUID.t() | nil,
          owner?: boolean(),
          admin?: boolean(),
          enrolled?: boolean(),
          invited?: boolean()
        }

  @enforce_keys [:workshop, :user_id, :owner?, :admin?, :enrolled?, :invited?]
  defstruct [:workshop, :user_id, :owner?, :admin?, :enrolled?, :invited?]
end
