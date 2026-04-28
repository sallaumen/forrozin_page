defmodule OGrupoDeEstudos.Engagement.Comments.SequenceCommentQuery do
  @moduledoc false
  @behaviour OGrupoDeEstudos.Engagement.Comments.Commentable
  import Ecto.Query
  alias OGrupoDeEstudos.Engagement.Comments.SequenceComment

  @impl true
  def base_query, do: from(c in SequenceComment, where: is_nil(c.deleted_at))

  @impl true
  def for_parent(query, sequence_id), do: where(query, [c], c.sequence_id == ^sequence_id)

  @impl true
  def roots_only(query), do: where(query, [c], is_nil(c.parent_sequence_comment_id))

  @impl true
  def replies_for(query, comment_id),
    do: where(query, [c], c.parent_sequence_comment_id == ^comment_id)

  @impl true
  def ordered_by_engagement(query),
    do: order_by(query, [c], desc: c.like_count, desc: c.inserted_at)

  @impl true
  def schema, do: SequenceComment

  @impl true
  def parent_field, do: :sequence_id

  @impl true
  def parent_comment_field, do: :parent_sequence_comment_id

  @impl true
  def likeable_type, do: "sequence_comment"

  @impl true
  def user_field, do: :user_id
end
