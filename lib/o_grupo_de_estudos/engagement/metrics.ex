defmodule OGrupoDeEstudos.Engagement.Metrics do
  @moduledoc """
  Read-only engagement metrics for a user or profile: likes given, comments
  authored, and likes received on the user's comments. Includes batch variants
  (`*_batch/1,2`) used by `Engagement.Badges` to avoid N+1 queries.

  StepComment and SequenceComment key on `user_id`; ProfileComment on `author_id`.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Engagement.Comments.{SequenceComment, StepComment}
  alias OGrupoDeEstudos.Engagement.{Like, ProfileComment}
  alias OGrupoDeEstudos.Repo

  @doc "Returns a MapSet of step IDs that the given user has liked."
  def liked_step_ids(user_id) do
    from(l in Like,
      where: l.user_id == ^user_id and l.likeable_type == "step",
      select: l.likeable_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  @doc "Returns the step codes the user has liked (deleted steps excluded)."
  def liked_step_codes(user_id) do
    user_id
    |> liked_step_ids()
    |> Enum.to_list()
    |> Encyclopedia.step_summaries_by_ids()
    |> Map.values()
    |> Enum.map(& &1.code)
  end

  @doc "Returns the count of likes given by a user for a specific likeable_type."
  def count_likes_given(user_id, likeable_type) do
    Repo.aggregate(
      from(l in Like,
        where: l.user_id == ^user_id and l.likeable_type == ^likeable_type
      ),
      :count
    )
  end

  @doc """
  Returns the total number of comments authored by the user across all comment types.

  StepComment and SequenceComment use `user_id`. ProfileComment uses `author_id`.
  """
  def count_comments_authored(user_id) do
    step_count =
      Repo.aggregate(
        from(c in StepComment, where: c.user_id == ^user_id and is_nil(c.deleted_at)),
        :count
      )

    sequence_count =
      Repo.aggregate(
        from(c in SequenceComment, where: c.user_id == ^user_id and is_nil(c.deleted_at)),
        :count
      )

    profile_count =
      Repo.aggregate(
        from(c in ProfileComment, where: c.author_id == ^user_id and is_nil(c.deleted_at)),
        :count
      )

    step_count + sequence_count + profile_count
  end

  @doc """
  Returns the total number of likes received on all comments authored by the user.

  Sums likes on step_comments (user_id), sequence_comments (user_id),
  and profile_comments (author_id).
  """
  def total_likes_received(user_id) do
    step_likes =
      from(l in Like,
        join: c in StepComment,
        on: l.likeable_id == c.id and l.likeable_type == "step_comment",
        where: c.user_id == ^user_id,
        select: count(l.id)
      )
      |> Repo.one()
      |> Kernel.||(0)

    sequence_likes =
      from(l in Like,
        join: c in SequenceComment,
        on: l.likeable_id == c.id and l.likeable_type == "sequence_comment",
        where: c.user_id == ^user_id,
        select: count(l.id)
      )
      |> Repo.one()
      |> Kernel.||(0)

    profile_likes =
      from(l in Like,
        join: c in ProfileComment,
        on: l.likeable_id == c.id and l.likeable_type == "profile_comment",
        where: c.author_id == ^user_id,
        select: count(l.id)
      )
      |> Repo.one()
      |> Kernel.||(0)

    step_likes + sequence_likes + profile_likes
  end

  # ── Batch helpers (used by Badges.primary_batch/1) ───────────────────

  @doc "Returns `%{user_id => count}` of likes given for the given type, for a list of users."
  def count_likes_given_batch(user_ids, likeable_type) do
    from(l in Like,
      where: l.user_id in ^user_ids and l.likeable_type == ^likeable_type,
      group_by: l.user_id,
      select: {l.user_id, count(l.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "Returns `%{user_id => count}` of comments authored across all types, for a list of users."
  def count_comments_authored_batch(user_ids) do
    step_counts =
      from(c in StepComment,
        where: c.user_id in ^user_ids and is_nil(c.deleted_at),
        group_by: c.user_id,
        select: {c.user_id, count(c.id)}
      )
      |> Repo.all()
      |> Map.new()

    sequence_counts =
      from(c in SequenceComment,
        where: c.user_id in ^user_ids and is_nil(c.deleted_at),
        group_by: c.user_id,
        select: {c.user_id, count(c.id)}
      )
      |> Repo.all()
      |> Map.new()

    profile_counts =
      from(c in ProfileComment,
        where: c.author_id in ^user_ids and is_nil(c.deleted_at),
        group_by: c.author_id,
        select: {c.author_id, count(c.id)}
      )
      |> Repo.all()
      |> Map.new()

    Map.new(user_ids, fn uid ->
      total =
        Map.get(step_counts, uid, 0) +
          Map.get(sequence_counts, uid, 0) +
          Map.get(profile_counts, uid, 0)

      {uid, total}
    end)
  end

  @doc "Returns `%{user_id => count}` of likes received on all authored comments, for a list of users."
  def total_likes_received_batch(user_ids) do
    step_likes =
      from(l in Like,
        join: c in StepComment,
        on: l.likeable_id == c.id and l.likeable_type == "step_comment",
        where: c.user_id in ^user_ids,
        group_by: c.user_id,
        select: {c.user_id, count(l.id)}
      )
      |> Repo.all()
      |> Map.new()

    sequence_likes =
      from(l in Like,
        join: c in SequenceComment,
        on: l.likeable_id == c.id and l.likeable_type == "sequence_comment",
        where: c.user_id in ^user_ids,
        group_by: c.user_id,
        select: {c.user_id, count(l.id)}
      )
      |> Repo.all()
      |> Map.new()

    profile_likes =
      from(l in Like,
        join: c in ProfileComment,
        on: l.likeable_id == c.id and l.likeable_type == "profile_comment",
        where: c.author_id in ^user_ids,
        group_by: c.author_id,
        select: {c.author_id, count(l.id)}
      )
      |> Repo.all()
      |> Map.new()

    Map.new(user_ids, fn uid ->
      total =
        Map.get(step_likes, uid, 0) +
          Map.get(sequence_likes, uid, 0) +
          Map.get(profile_likes, uid, 0)

      {uid, total}
    end)
  end
end
