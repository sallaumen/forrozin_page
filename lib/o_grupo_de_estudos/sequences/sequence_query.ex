defmodule OGrupoDeEstudos.Sequences.SequenceQuery do
  @moduledoc """
  Query module for the Sequence schema.

  Provides `get_by/1` and `list_by/1` as the public API, both backed by the
  shared_reducer/2 pattern so every filter is defined once and reused.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Sequences.Sequence

  @type list_opt ::
          {:include_deleted, boolean()}
          | {:id, Ecto.UUID.t()}
          | {:user_id, Ecto.UUID.t()}
          | {:ids, [Ecto.UUID.t()]}
          | {:public, boolean()}
          | {:order_by, Keyword.t()}
          | {:preload, term()}
  @type opts :: [list_opt()]

  @doc "Returns the first sequence matching `opts`, or `nil`."
  @spec get_by(opts()) :: Sequence.t() | nil
  def get_by(opts) do
    opts
    |> Keyword.put_new(:include_deleted, false)
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.one()
  end

  @doc "Returns all sequences matching `opts`, ordered by inserted_at desc by default."
  @spec list_by(opts()) :: [Sequence.t()]
  def list_by(opts \\ []) do
    opts
    |> Keyword.put_new(:include_deleted, false)
    |> Keyword.put_new(:order_by, desc: :inserted_at)
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.all()
  end

  @doc "Returns `%{user_id => count}` of public, non-deleted sequences per user."
  @spec public_counts_by_user([Ecto.UUID.t()]) :: %{Ecto.UUID.t() => non_neg_integer()}
  def public_counts_by_user([]), do: %{}

  def public_counts_by_user(user_ids) when is_list(user_ids) do
    from(s in Sequence,
      where: s.user_id in ^user_ids and s.public == true and is_nil(s.deleted_at),
      group_by: s.user_id,
      select: {s.user_id, count(s.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp default_scope, do: from(s in Sequence, as: :sequence)

  defp shared_reducer({:include_deleted, true}, q), do: q

  defp shared_reducer({:include_deleted, false}, q),
    do: where(q, [sequence: s], is_nil(s.deleted_at))

  defp shared_reducer({:id, id}, q), do: where(q, [sequence: s], s.id == ^id)
  defp shared_reducer({:user_id, id}, q), do: where(q, [sequence: s], s.user_id == ^id)
  defp shared_reducer({:ids, ids}, q), do: where(q, [sequence: s], s.id in ^ids)
  defp shared_reducer({:public, val}, q), do: where(q, [sequence: s], s.public == ^val)
  defp shared_reducer({:order_by, ordering}, q), do: order_by(q, ^ordering)
  defp shared_reducer({:preload, preloads}, q), do: preload(q, ^preloads)
end
