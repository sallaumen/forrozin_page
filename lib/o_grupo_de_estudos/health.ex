defmodule OGrupoDeEstudos.Health do
  @moduledoc """
  Liveness facts about the running node, for the health check endpoint.

  Lives in the domain so the web layer can ask "is the database responsive?"
  without owning the how (raw query, timeout, rescue).
  """

  alias OGrupoDeEstudos.Repo

  @query_timeout 4_000

  @doc "Whether the database answers a trivial query within the timeout."
  @spec database_responsive?() :: boolean()
  def database_responsive? do
    match?({:ok, _result}, Repo.query("SELECT 1", [], timeout: @query_timeout))
  rescue
    _error -> false
  end
end
