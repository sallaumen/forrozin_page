defmodule OGrupoDeEstudos.Accounts.AdminIdsCache do
  @moduledoc """
  Node-local cache of admin user ids via `:persistent_term`.

  Admin promotion happens directly in the database (no interface), so a
  short TTL is enough. With `admin_ids_cache_ttl_ms` set to 0 (test env)
  every call hits the database, keeping sandboxed tests isolated.
  """

  alias OGrupoDeEstudos.Accounts.UserQuery

  @key {__MODULE__, :admin_ids}

  @spec get() :: [Ecto.UUID.t()]
  def get do
    case ttl_ms() do
      ttl when ttl <= 0 -> UserQuery.admin_ids()
      ttl -> cached_or_refresh(ttl)
    end
  end

  defp cached_or_refresh(ttl) do
    case :persistent_term.get(@key, nil) do
      {ids, cached_at} ->
        if now_ms() - cached_at < ttl, do: ids, else: refresh()

      nil ->
        refresh()
    end
  end

  defp refresh do
    ids = UserQuery.admin_ids()
    :persistent_term.put(@key, {ids, now_ms()})
    ids
  end

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp ttl_ms, do: Application.get_env(:o_grupo_de_estudos, :admin_ids_cache_ttl_ms, 60_000)
end
