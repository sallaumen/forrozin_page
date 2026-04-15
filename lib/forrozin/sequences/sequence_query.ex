defmodule Forrozin.Sequences.SequenceQuery do
  @moduledoc """
  Query module for the Sequence schema.

  Provides `get_by/1` and `list_by/1` as the public API, both backed by the
  shared_reducer/2 pattern so every filter is defined once and reused.
  """

  import Ecto.Query

  alias Forrozin.Repo
  alias Forrozin.Sequences.Sequence

  @doc "Returns the first sequence matching `opts`, or `nil`."
  def get_by(opts) do
    opts
    |> Keyword.put_new(:include_deleted, false)
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.one()
  end

  @doc "Returns all sequences matching `opts`, ordered by inserted_at desc by default."
  def list_by(opts \\ []) do
    opts
    |> Keyword.put_new(:include_deleted, false)
    |> Keyword.put_new(:order_by, desc: :inserted_at)
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.all()
  end

  defp default_scope, do: from(s in Sequence, as: :sequence)

  defp shared_reducer({:include_deleted, true}, q), do: q

  defp shared_reducer({:include_deleted, false}, q),
    do: where(q, [sequence: s], is_nil(s.deleted_at))

  defp shared_reducer({:id, id}, q), do: where(q, [sequence: s], s.id == ^id)
  defp shared_reducer({:user_id, id}, q), do: where(q, [sequence: s], s.user_id == ^id)
  defp shared_reducer({:public, val}, q), do: where(q, [sequence: s], s.public == ^val)
  defp shared_reducer({:order_by, ordering}, q), do: order_by(q, ^ordering)
  defp shared_reducer({:preload, preloads}, q), do: preload(q, ^preloads)
end
