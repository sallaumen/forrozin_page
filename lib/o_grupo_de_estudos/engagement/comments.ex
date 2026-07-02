defmodule OGrupoDeEstudos.Engagement.Comments do
  @moduledoc """
  Comments on steps, sequences and profiles, built on the generic `Commentable`
  behaviour: each type delegates to its `*Query` module while sharing creation
  (with notification dispatch), soft-delete (tombstone vs. hard-delete by reply
  count), listing, replies, and batch counts.

  ProfileComment keeps backward-compatible 1-arity signatures for UserProfileLive.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Authorization.Policy

  alias OGrupoDeEstudos.Engagement.Comments.{
    SequenceComment,
    SequenceCommentQuery,
    StepComment,
    StepCommentQuery
  }

  alias OGrupoDeEstudos.Engagement.{ProfileComment, ProfileCommentQuery, SafeDispatch}
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.RateLimiter
  alias OGrupoDeEstudos.Repo

  @tombstone_body "[comentário removido]"

  # ── Profile comments — backward-compatible 1-arity signatures ─────────

  @doc "Returns active (non-deleted) comments on a user's profile, newest first."
  def list_profile_comments(opts) when is_list(opts) do
    ProfileCommentQuery.list_by(opts)
  end

  @doc "Posts a new comment on a user's profile (legacy raw-attrs signature)."
  def create_profile_comment(attrs) when is_map(attrs) do
    %ProfileComment{}
    |> ProfileComment.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Soft-deletes a profile comment (legacy signature — no authorization check)."
  def delete_profile_comment(%ProfileComment{} = comment) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    comment
    |> Ecto.Changeset.change(deleted_at: now)
    |> Repo.update()
  end

  # ── Step comments — typed public API ──────────────────────────────────

  @doc "Lists root step comments for the given step, ordered by engagement."
  def list_step_comments(step_id, opts \\ []),
    do: list_comments(StepCommentQuery, step_id, opts)

  @doc "Creates a step comment (root or reply). Bumps parent reply_count via trigger."
  def create_step_comment(user, step_id, attrs),
    do: create_comment(StepComment, StepCommentQuery, user, step_id, attrs)

  @doc "Deletes a step comment with authorization. Hard-deletes if no replies, tombstones otherwise."
  def delete_step_comment(user, comment),
    do: delete_comment(StepComment, StepCommentQuery, user, comment)

  # ── Sequence comments — typed public API ──────────────────────────────

  @doc "Lists root sequence comments for the given sequence, ordered by engagement."
  def list_sequence_comments(sequence_id, opts \\ []),
    do: list_comments(SequenceCommentQuery, sequence_id, opts)

  @doc "Creates a sequence comment (root or reply)."
  def create_sequence_comment(user, sequence_id, attrs),
    do: create_comment(SequenceComment, SequenceCommentQuery, user, sequence_id, attrs)

  @doc "Deletes a sequence comment with authorization."
  def delete_sequence_comment(user, comment),
    do: delete_comment(SequenceComment, SequenceCommentQuery, user, comment)

  # ── Profile comments — new typed API (2-arity) ────────────────────────

  @doc "Lists root profile comments for the given profile, ordered by engagement."
  def list_profile_comments(profile_id, opts) when is_binary(profile_id),
    do: list_comments(ProfileCommentQuery, profile_id, opts)

  @doc "Creates a profile comment via the generic pipeline (with notification dispatch)."
  def create_profile_comment(user, profile_id, attrs),
    do: create_comment(ProfileComment, ProfileCommentQuery, user, profile_id, attrs)

  @doc "Deletes a profile comment with authorization (new 2-arity)."
  def delete_profile_comment(user, comment),
    do: delete_comment(ProfileComment, ProfileCommentQuery, user, comment)

  # ── Replies — generic for any comment type ────────────────────────────

  @doc "Lists replies for a given parent comment (`query_mod` is the Commentable impl)."
  def list_replies(query_mod, comment_id, opts \\ []) do
    query_mod.base_query()
    |> query_mod.replies_for(comment_id)
    |> query_mod.ordered_by_engagement()
    |> paginate(opts)
    |> Repo.all()
    |> preload_user(query_mod)
  end

  # ── Comment counts — batch preload for list pages ─────────────────────

  @doc "Returns `%{parent_id => comment_count}` for the given parent type and IDs."
  def comment_counts_for(type, parent_ids) when is_list(parent_ids) do
    {schema, parent_field} = schema_and_field_for(type)

    counts =
      from(c in schema,
        where: field(c, ^parent_field) in ^parent_ids and is_nil(c.deleted_at),
        group_by: field(c, ^parent_field),
        select: {field(c, ^parent_field), count(c.id)}
      )
      |> Repo.all()
      |> Map.new()

    Map.new(parent_ids, fn id -> {id, Map.get(counts, id, 0)} end)
  end

  # ── Generic CRUD pipeline ─────────────────────────────────────────────

  defp list_comments(query_mod, parent_id, opts) do
    query_mod.base_query()
    |> query_mod.for_parent(parent_id)
    |> query_mod.roots_only()
    |> query_mod.ordered_by_engagement()
    |> paginate(opts)
    |> Repo.all()
    |> preload_user(query_mod)
  end

  defp create_comment(schema_mod, query_mod, user, parent_id, attrs) do
    case RateLimiter.check("comment", user.id, limit: 5, window_seconds: 10) do
      {:error, :rate_limited} -> {:error, :rate_limited}
      :ok -> do_create_comment(schema_mod, query_mod, user, parent_id, attrs)
    end
  end

  defp do_create_comment(schema_mod, query_mod, user, parent_id, attrs) do
    parent_field = query_mod.parent_field()
    user_field = query_mod.user_field()

    changeset =
      struct(schema_mod)
      |> schema_mod.changeset(
        attrs
        |> Map.put(user_field, user.id)
        |> Map.put(parent_field, parent_id)
      )

    # reply_count is handled by a Postgres trigger — a single insert needs no transaction
    case Repo.insert(changeset) do
      {:ok, comment} ->
        safe_dispatch(:new_comment, comment, user, query_mod)
        {:ok, Repo.preload(comment, user_assoc(query_mod))}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp delete_comment(schema_mod, query_mod, user, comment) do
    with :ok <- Policy.authorize(:delete_comment, user, comment) do
      parent_comment_field = query_mod.parent_comment_field()

      if comment.reply_count == 0 do
        hard_delete(schema_mod, comment, parent_comment_field)
      else
        tombstone(comment)
      end
    end
  end

  defp hard_delete(_schema_mod, comment, _parent_comment_field) do
    # reply_count decrement handled by Postgres trigger on DELETE
    case Repo.delete(comment) do
      {:ok, _} -> {:ok, :deleted}
      {:error, reason} -> {:error, reason}
    end
  end

  defp tombstone(comment) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    comment
    |> Ecto.Changeset.change(%{body: @tombstone_body, deleted_at: now})
    |> Repo.update()
  end

  # ── Helpers ───────────────────────────────────────────────────────────

  @doc "Returns a step comment by id, or `nil`."
  def get_step_comment(id), do: Repo.get(StepComment, id)

  @doc "Returns a sequence comment by id, or `nil`."
  def get_sequence_comment(id), do: Repo.get(SequenceComment, id)

  defp paginate(query, opts) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    query
    |> limit(^limit)
    |> offset(^offset)
  end

  defp preload_user(comments, query_mod) do
    assoc = user_assoc(query_mod)
    Repo.preload(comments, assoc)
  end

  defp user_assoc(query_mod) do
    query_mod.user_field()
    |> Atom.to_string()
    |> String.trim_trailing("_id")
    |> String.to_existing_atom()
  end

  defp safe_dispatch(action, comment, actor, query_mod) do
    SafeDispatch.run(fn -> Dispatcher.notify(action, comment, actor, query_mod) end)
  end

  defp schema_and_field_for("step"), do: {StepComment, :step_id}
  defp schema_and_field_for("sequence"), do: {SequenceComment, :sequence_id}
  defp schema_and_field_for("profile"), do: {ProfileComment, :profile_id}
end
