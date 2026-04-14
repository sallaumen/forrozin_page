defmodule Forrozin.Encyclopedia.ConnectionQuery do
  @moduledoc """
  Query module for the Connection schema.

  Provides `get_by/1` and `list_by/1` as the public API, both backed by the
  shared_reducer/2 pattern so every filter is defined once and reused.
  """

  import Ecto.Query

  alias Forrozin.Repo
  alias Forrozin.Encyclopedia.{Connection, Step}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Returns the first connection matching `opts`, or `nil`."
  def get_by(opts) do
    opts
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.one()
  end

  @doc "Returns all connections matching `opts`."
  def list_by(opts \\ []) do
    opts
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.all()
  end

  @doc "Deletes all connections matching `opts`. Returns `{count, nil}`."
  def delete_all_by(opts) do
    opts
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.delete_all()
  end

  # ---------------------------------------------------------------------------
  # Base scope
  # ---------------------------------------------------------------------------

  defp default_scope, do: from(c in Connection, as: :connection)

  # ---------------------------------------------------------------------------
  # Shared reducer — one clause per filter
  # ---------------------------------------------------------------------------

  defp shared_reducer({:source_step_id, id}, q),
    do: where(q, [connection: c], c.source_step_id == ^id)

  defp shared_reducer({:target_step_id, id}, q),
    do: where(q, [connection: c], c.target_step_id == ^id)

  defp shared_reducer({:step_ids, ids}, q),
    do:
      where(
        q,
        [connection: c],
        c.source_step_id in ^ids and c.target_step_id in ^ids
      )

  defp shared_reducer({:either_step_id, id}, q),
    do:
      where(
        q,
        [connection: c],
        c.source_step_id == ^id or c.target_step_id == ^id
      )

  # Finds a connection by source and target step codes, joining the steps table.
  defp shared_reducer({:source_code, code}, q) do
    q
    |> join(:inner, [connection: c], s in Step, on: c.source_step_id == s.id, as: :source_step)
    |> where([source_step: s], s.code == ^code)
  end

  defp shared_reducer({:target_code, code}, q) do
    q
    |> join(:inner, [connection: c], t in Step, on: c.target_step_id == t.id, as: :target_step)
    |> where([target_step: t], t.code == ^code)
  end

  defp shared_reducer({:preload, preloads}, q), do: preload(q, ^preloads)

  defp shared_reducer({:order_by, ordering}, q), do: order_by(q, ^ordering)
end
