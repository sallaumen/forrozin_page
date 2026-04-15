defmodule OGrupoDeEstudos.Encyclopedia.StepLinkQuery do
  @moduledoc """
  Query module for the StepLink schema.

  Provides `get_by/1`, `list_by/1`, and `count_by/1` backed by the
  shared_reducer/2 pattern so every filter is defined once and reused.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Encyclopedia.StepLink

  @doc "Returns the first step link matching `opts`, or `nil`."
  def get_by(opts) do
    opts
    |> Keyword.put_new(:include_deleted, false)
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.one()
  end

  @doc "Returns all step links matching `opts`, ordered by inserted_at desc by default."
  def list_by(opts \\ []) do
    opts
    |> Keyword.put_new(:include_deleted, false)
    |> Keyword.put_new(:order_by, desc: :inserted_at)
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.all()
  end

  @doc "Counts step links matching `opts`."
  def count_by(opts \\ []) do
    opts
    |> Keyword.put_new(:include_deleted, false)
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.aggregate(:count)
  end

  defp default_scope, do: from(l in StepLink, as: :step_link)

  defp shared_reducer({:include_deleted, true}, q), do: q

  defp shared_reducer({:include_deleted, false}, q),
    do: where(q, [step_link: l], is_nil(l.deleted_at))

  defp shared_reducer({:id, id}, q),
    do: where(q, [step_link: l], l.id == ^id)

  defp shared_reducer({:step_id, id}, q),
    do: where(q, [step_link: l], l.step_id == ^id)

  defp shared_reducer({:submitted_by_id, id}, q),
    do: where(q, [step_link: l], l.submitted_by_id == ^id)

  defp shared_reducer({:approved, value}, q),
    do: where(q, [step_link: l], l.approved == ^value)

  # Shortcut: pending = approved false + not deleted
  defp shared_reducer({:pending, true}, q),
    do: where(q, [step_link: l], l.approved == false and is_nil(l.deleted_at))

  defp shared_reducer({:preload, preloads}, q), do: preload(q, ^preloads)

  defp shared_reducer({:order_by, ordering}, q), do: order_by(q, ^ordering)

  @doc """
  Returns a MapSet of step IDs that have at least one approved, non-deleted link.

  Used to efficiently render indicators in list views without N+1 queries.
  """
  def step_ids_with_links do
    from(l in StepLink,
      where: l.approved == true and is_nil(l.deleted_at),
      distinct: l.step_id,
      select: l.step_id
    )
    |> Repo.all()
    |> MapSet.new()
  end
end
