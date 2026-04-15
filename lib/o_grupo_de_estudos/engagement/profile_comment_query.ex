defmodule OGrupoDeEstudos.Engagement.ProfileCommentQuery do
  @moduledoc """
  Query reducers for ProfileComment.

  All DB access for profile comments in the Engagement context is delegated here.
  Accepts a keyword list of filters and composable options.

  ## Supported options

  - `:profile_id` — filter by profile user id
  - `:author_id` — filter by comment author id
  - `:include_deleted` — when `true`, includes soft-deleted comments (default: `false`)
  - `:preload` — list of associations to preload (e.g. `[:author]`)
  - `:order_by` — Ecto order_by clause (default: `[desc: :inserted_at]`)
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Engagement.ProfileComment

  @doc """
  Returns all profile comments matching the given filters.

  ## Example

      ProfileCommentQuery.list_by(profile_id: user.id, preload: [:author])
  """
  def list_by(opts \\ []) do
    opts = Keyword.put_new(opts, :include_deleted, false)
    opts = Keyword.put_new(opts, :order_by, desc: :inserted_at)

    ProfileComment
    |> apply_filters(opts)
    |> Repo.all()
    |> maybe_preload(Keyword.get(opts, :preload, []))
  end

  # --- private reducers ---

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, &apply_filter/2)
  end

  defp apply_filter({:profile_id, id}, query) do
    where(query, [c], c.profile_id == ^id)
  end

  defp apply_filter({:author_id, id}, query) do
    where(query, [c], c.author_id == ^id)
  end

  defp apply_filter({:include_deleted, false}, query) do
    where(query, [c], is_nil(c.deleted_at))
  end

  defp apply_filter({:include_deleted, true}, query), do: query

  defp apply_filter({:order_by, order}, query) do
    order_by(query, ^order)
  end

  defp apply_filter({:preload, _}, query), do: query

  defp apply_filter(_unknown, query), do: query

  defp maybe_preload(results, []), do: results

  defp maybe_preload(results, preloads) do
    Repo.preload(results, preloads)
  end
end
