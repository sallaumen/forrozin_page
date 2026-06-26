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

  @behaviour OGrupoDeEstudos.Engagement.Comments.Commentable

  import Ecto.Query

  alias OGrupoDeEstudos.Engagement.ProfileComment
  alias OGrupoDeEstudos.Repo

  @type list_opt ::
          {:profile_id, Ecto.UUID.t()}
          | {:author_id, Ecto.UUID.t()}
          | {:include_deleted, boolean()}
          | {:preload, term()}
          | {:order_by, Keyword.t()}
  @type opts :: [list_opt()]

  @doc """
  Returns all profile comments matching the given filters.

  ## Example

      ProfileCommentQuery.list_by(profile_id: user.id, preload: [:author])
  """
  @spec list_by(opts()) :: [ProfileComment.t()]
  def list_by(opts \\ []) do
    opts = Keyword.put_new(opts, :include_deleted, false)
    opts = Keyword.put_new(opts, :order_by, desc: :inserted_at)

    ProfileComment
    |> apply_filters(opts)
    |> Repo.all()
    |> maybe_preload(Keyword.get(opts, :preload, []))
  end

  # --- Commentable behaviour ---

  @impl true
  @spec base_query() :: Ecto.Query.t()
  def base_query, do: from(c in ProfileComment, where: is_nil(c.deleted_at))

  @impl true
  @spec for_parent(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def for_parent(query, profile_id), do: where(query, [c], c.profile_id == ^profile_id)

  @impl true
  @spec roots_only(Ecto.Query.t()) :: Ecto.Query.t()
  def roots_only(query), do: where(query, [c], is_nil(c.parent_profile_comment_id))

  @impl true
  @spec replies_for(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def replies_for(query, comment_id),
    do: where(query, [c], c.parent_profile_comment_id == ^comment_id)

  @impl true
  @spec ordered_by_engagement(Ecto.Query.t()) :: Ecto.Query.t()
  def ordered_by_engagement(query),
    do: order_by(query, [c], desc: c.like_count, desc: c.inserted_at)

  @impl true
  @spec schema() :: module()
  def schema, do: ProfileComment

  @impl true
  @spec parent_field() :: atom()
  def parent_field, do: :profile_id

  @impl true
  @spec parent_comment_field() :: atom()
  def parent_comment_field, do: :parent_profile_comment_id

  @impl true
  @spec likeable_type() :: String.t()
  def likeable_type, do: "profile_comment"

  @impl true
  @spec user_field() :: atom()
  def user_field, do: :author_id

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
