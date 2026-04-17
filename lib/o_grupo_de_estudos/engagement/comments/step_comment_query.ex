defmodule OGrupoDeEstudos.Engagement.Comments.StepCommentQuery do
  @behaviour OGrupoDeEstudos.Engagement.Comments.Commentable
  import Ecto.Query
  alias OGrupoDeEstudos.Engagement.Comments.StepComment

  @impl true
  def base_query, do: from(c in StepComment, where: is_nil(c.deleted_at))

  @impl true
  def for_parent(query, step_id), do: where(query, [c], c.step_id == ^step_id)

  @impl true
  def roots_only(query), do: where(query, [c], is_nil(c.parent_step_comment_id))

  @impl true
  def replies_for(query, comment_id), do: where(query, [c], c.parent_step_comment_id == ^comment_id)

  @impl true
  def ordered_by_engagement(query), do: order_by(query, [c], [desc: c.like_count, desc: c.inserted_at])

  @impl true
  def schema, do: StepComment

  @impl true
  def parent_field, do: :step_id

  @impl true
  def parent_comment_field, do: :parent_step_comment_id

  @impl true
  def likeable_type, do: "step_comment"

  @impl true
  def user_field, do: :user_id
end
