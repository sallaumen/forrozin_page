defmodule OGrupoDeEstudos.Engagement.Comments.StepCommentQuery do
  @moduledoc false
  @behaviour OGrupoDeEstudos.Engagement.Comments.Commentable
  import Ecto.Query
  alias OGrupoDeEstudos.Engagement.Comments.StepComment

  @impl true
  @spec base_query() :: Ecto.Query.t()
  def base_query, do: from(c in StepComment, where: is_nil(c.deleted_at))

  @impl true
  @spec for_parent(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def for_parent(query, step_id), do: where(query, [c], c.step_id == ^step_id)

  @impl true
  @spec roots_only(Ecto.Query.t()) :: Ecto.Query.t()
  def roots_only(query), do: where(query, [c], is_nil(c.parent_step_comment_id))

  @impl true
  @spec replies_for(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def replies_for(query, comment_id),
    do: where(query, [c], c.parent_step_comment_id == ^comment_id)

  @impl true
  @spec ordered_by_engagement(Ecto.Query.t()) :: Ecto.Query.t()
  def ordered_by_engagement(query),
    do: order_by(query, [c], desc: c.like_count, desc: c.inserted_at)

  @impl true
  @spec schema() :: module()
  def schema, do: StepComment

  @impl true
  @spec parent_field() :: atom()
  def parent_field, do: :step_id

  @impl true
  @spec parent_comment_field() :: atom()
  def parent_comment_field, do: :parent_step_comment_id

  @impl true
  @spec likeable_type() :: String.t()
  def likeable_type, do: "step_comment"

  @impl true
  @spec user_field() :: atom()
  def user_field, do: :user_id
end
