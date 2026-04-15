defmodule Forrozin.Encyclopedia.SectionQuery do
  @moduledoc """
  Query module for the Section schema.

  Provides `get_by/1` and `list_by/1` as the public API, both backed by the
  shared_reducer/2 pattern so every filter is defined once and reused.
  """

  import Ecto.Query

  alias Forrozin.Repo
  alias Forrozin.Encyclopedia.Section

  @doc "Returns the first section matching `opts`, or `nil`."
  def get_by(opts) do
    opts
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.one()
  end

  @doc "Returns all sections matching `opts`, ordered by position by default."
  def list_by(opts \\ []) do
    opts
    |> Keyword.put_new(:order_by, asc: :position)
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.all()
  end

  defp default_scope, do: from(s in Section, as: :section)

  defp shared_reducer({:id, id}, q),
    do: where(q, [section: s], s.id == ^id)

  defp shared_reducer({:order_by, ordering}, q), do: order_by(q, ^ordering)

  defp shared_reducer({:preload, preloads}, q), do: preload(q, ^preloads)
end
