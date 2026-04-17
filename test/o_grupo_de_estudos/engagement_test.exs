defmodule OGrupoDeEstudos.EngagementTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Engagement.Comments.{StepComment, StepCommentQuery}
  alias OGrupoDeEstudos.Engagement.Comments.{SequenceComment, SequenceCommentQuery}
  alias OGrupoDeEstudos.Engagement.ProfileCommentQuery
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Repo

  setup do
    user = insert(:user)
    step = insert(:step)
    sequence = insert(:sequence, user: user)
    %{user: user, step: step, sequence: sequence}
  end

  # ══════════════════════════════════════════════════════════════════════
  # Likes (existing tests — unchanged)
  # ══════════════════════════════════════════════════════════════════════

  describe "toggle_like/3" do
    test "creates a like when none exists", %{user: user, step: step} do
      assert {:ok, :liked} = Engagement.toggle_like(user.id, "step", step.id)
      assert Engagement.liked?(user.id, "step", step.id)
    end

    test "removes the like when one already exists", %{user: user, step: step} do
      {:ok, :liked} = Engagement.toggle_like(user.id, "step", step.id)
      assert {:ok, :unliked} = Engagement.toggle_like(user.id, "step", step.id)
      refute Engagement.liked?(user.id, "step", step.id)
    end

    test "is idempotent for unlike — a second unlike is a new like", %{user: user, step: step} do
      {:ok, :liked} = Engagement.toggle_like(user.id, "step", step.id)
      {:ok, :unliked} = Engagement.toggle_like(user.id, "step", step.id)
      assert {:ok, :liked} = Engagement.toggle_like(user.id, "step", step.id)
    end

    test "works for sequence likeable_type", %{user: user, sequence: sequence} do
      assert {:ok, :liked} = Engagement.toggle_like(user.id, "sequence", sequence.id)
      assert Engagement.liked?(user.id, "sequence", sequence.id)
    end
  end

  describe "liked?/3" do
    test "returns false when the user has not liked", %{user: user, step: step} do
      refute Engagement.liked?(user.id, "step", step.id)
    end

    test "returns true after a like is created", %{user: user, step: step} do
      {:ok, :liked} = Engagement.toggle_like(user.id, "step", step.id)
      assert Engagement.liked?(user.id, "step", step.id)
    end

    test "returns false after like is removed", %{user: user, step: step} do
      {:ok, :liked} = Engagement.toggle_like(user.id, "step", step.id)
      {:ok, :unliked} = Engagement.toggle_like(user.id, "step", step.id)
      refute Engagement.liked?(user.id, "step", step.id)
    end
  end

  describe "count_likes/2" do
    test "returns 0 when no likes exist", %{step: step} do
      assert 0 == Engagement.count_likes("step", step.id)
    end

    test "returns correct count after multiple users like the same entity", %{step: step} do
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)

      Engagement.toggle_like(user1.id, "step", step.id)
      Engagement.toggle_like(user2.id, "step", step.id)
      Engagement.toggle_like(user3.id, "step", step.id)

      assert 3 == Engagement.count_likes("step", step.id)
    end

    test "decreases after unlike", %{user: user, step: step} do
      Engagement.toggle_like(user.id, "step", step.id)
      assert 1 == Engagement.count_likes("step", step.id)

      Engagement.toggle_like(user.id, "step", step.id)
      assert 0 == Engagement.count_likes("step", step.id)
    end
  end

  describe "likes_map/3" do
    test "returns empty liked_ids and counts when nothing liked", %{user: user, step: step} do
      result = Engagement.likes_map(user.id, "step", [step.id])

      assert %{liked_ids: liked_ids, counts: counts} = result
      assert MapSet.size(liked_ids) == 0
      assert map_size(counts) == 0
    end

    test "marks liked entities in liked_ids and tracks counts", %{user: user, step: step} do
      other_step = insert(:step)
      other_user = insert(:user)

      Engagement.toggle_like(user.id, "step", step.id)
      Engagement.toggle_like(other_user.id, "step", step.id)

      result = Engagement.likes_map(user.id, "step", [step.id, other_step.id])

      assert %{liked_ids: liked_ids, counts: counts} = result
      assert MapSet.member?(liked_ids, step.id)
      refute MapSet.member?(liked_ids, other_step.id)
      assert Map.get(counts, step.id) == 2
      assert Map.get(counts, other_step.id, 0) == 0
    end

    test "does not leak likes across likeable_types", %{
      user: user,
      step: step,
      sequence: sequence
    } do
      Engagement.toggle_like(user.id, "step", step.id)

      result = Engagement.likes_map(user.id, "sequence", [sequence.id])

      assert %{liked_ids: liked_ids} = result
      refute MapSet.member?(liked_ids, sequence.id)
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Step comments
  # ══════════════════════════════════════════════════════════════════════

  describe "step comments" do
    test "create_step_comment/3 creates a root comment", %{user: user, step: step} do
      assert {:ok, comment} = Engagement.create_step_comment(user, step.id, %{body: "Ótimo passo!"})
      assert comment.body == "Ótimo passo!"
      assert comment.user_id == user.id
      assert comment.step_id == step.id
      assert is_nil(comment.parent_step_comment_id)
      # user association should be preloaded
      assert comment.user != nil
      assert comment.user.id == user.id
    end

    test "create_step_comment/3 creates a reply and bumps reply_count", %{user: user, step: step} do
      {:ok, parent} = Engagement.create_step_comment(user, step.id, %{body: "Parent"})
      other_user = insert(:user)

      {:ok, reply} =
        Engagement.create_step_comment(other_user, step.id, %{
          body: "Reply",
          parent_step_comment_id: parent.id
        })

      assert reply.parent_step_comment_id == parent.id

      # DB trigger bumps reply_count on INSERT; our Multi also bumps it.
      # Reload from DB to see the trigger-updated value.
      updated_parent = Repo.get!(StepComment, parent.id)
      assert updated_parent.reply_count >= 1
    end

    test "create_step_comment/3 rejects empty body", %{user: user, step: step} do
      assert {:error, changeset} = Engagement.create_step_comment(user, step.id, %{body: ""})
      assert errors_on(changeset)[:body] != nil
    end

    test "list_step_comments/2 returns roots ordered by engagement", %{user: user, step: step} do
      {:ok, c1} = Engagement.create_step_comment(user, step.id, %{body: "First"})
      {:ok, _c2} = Engagement.create_step_comment(user, step.id, %{body: "Second"})

      # Like c1 to boost its like_count via DB trigger
      Engagement.toggle_like(user.id, "step_comment", c1.id)

      comments = Engagement.list_step_comments(step.id)
      assert length(comments) == 2
      # c1 has like_count=1, c2 has like_count=0 → c1 comes first
      assert hd(comments).id == c1.id
    end

    test "list_step_comments/2 excludes deleted comments", %{user: user, step: step} do
      {:ok, c1} = Engagement.create_step_comment(user, step.id, %{body: "Visible"})
      {:ok, c2} = Engagement.create_step_comment(user, step.id, %{body: "Deleted"})

      c2
      |> Ecto.Changeset.change(deleted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
      |> Repo.update!()

      comments = Engagement.list_step_comments(step.id)
      assert length(comments) == 1
      assert hd(comments).id == c1.id
    end

    test "list_step_comments/2 only returns roots (not replies)", %{user: user, step: step} do
      {:ok, parent} = Engagement.create_step_comment(user, step.id, %{body: "Root"})

      {:ok, _reply} =
        Engagement.create_step_comment(user, step.id, %{
          body: "Reply",
          parent_step_comment_id: parent.id
        })

      comments = Engagement.list_step_comments(step.id)
      assert length(comments) == 1
      assert hd(comments).id == parent.id
    end

    test "delete_step_comment/2 hard deletes when no replies", %{user: user, step: step} do
      {:ok, comment} = Engagement.create_step_comment(user, step.id, %{body: "Delete me"})
      assert {:ok, :deleted} = Engagement.delete_step_comment(user, comment)
      assert Repo.get(StepComment, comment.id) == nil
    end

    test "delete_step_comment/2 tombstones when has replies", %{user: user, step: step} do
      {:ok, parent} = Engagement.create_step_comment(user, step.id, %{body: "Parent"})
      other = insert(:user)

      {:ok, _reply} =
        Engagement.create_step_comment(other, step.id, %{
          body: "Reply",
          parent_step_comment_id: parent.id
        })

      # Reload to get the updated reply_count
      parent = Repo.get!(StepComment, parent.id)
      assert {:ok, tombstoned} = Engagement.delete_step_comment(user, parent)
      assert tombstoned.body == "[comentário removido]"
      assert tombstoned.deleted_at != nil
    end

    test "delete_step_comment/2 rejects unauthorized user", %{step: step} do
      author = insert(:user)
      other = insert(:user)
      {:ok, comment} = Engagement.create_step_comment(author, step.id, %{body: "Mine"})
      assert {:error, :unauthorized} = Engagement.delete_step_comment(other, comment)
    end

    test "delete_step_comment/2 allows admin to delete any comment", %{step: step} do
      author = insert(:user)
      admin = insert(:admin)
      {:ok, comment} = Engagement.create_step_comment(author, step.id, %{body: "Any"})
      assert {:ok, :deleted} = Engagement.delete_step_comment(admin, comment)
    end

    test "delete_step_comment/2 decrements parent reply_count on hard delete", %{
      user: user,
      step: step
    } do
      {:ok, parent} = Engagement.create_step_comment(user, step.id, %{body: "Parent"})
      other = insert(:user)

      {:ok, reply} =
        Engagement.create_step_comment(other, step.id, %{
          body: "Reply",
          parent_step_comment_id: parent.id
        })

      # reply_count should be >= 1
      parent_before = Repo.get!(StepComment, parent.id)
      assert parent_before.reply_count >= 1

      # Delete the reply (author deletes own)
      assert {:ok, :deleted} = Engagement.delete_step_comment(other, reply)

      # reply_count should be decremented
      parent_after = Repo.get!(StepComment, parent.id)
      assert parent_after.reply_count < parent_before.reply_count
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Sequence comments
  # ══════════════════════════════════════════════════════════════════════

  describe "sequence comments" do
    test "create_sequence_comment/3 creates a root comment", %{user: user, sequence: sequence} do
      assert {:ok, comment} =
               Engagement.create_sequence_comment(user, sequence.id, %{body: "Ótima sequência!"})

      assert comment.body == "Ótima sequência!"
      assert comment.user_id == user.id
      assert comment.sequence_id == sequence.id
      assert is_nil(comment.parent_sequence_comment_id)
      assert comment.user != nil
    end

    test "create_sequence_comment/3 creates a reply", %{user: user, sequence: sequence} do
      {:ok, parent} = Engagement.create_sequence_comment(user, sequence.id, %{body: "Parent"})
      other = insert(:user)

      {:ok, reply} =
        Engagement.create_sequence_comment(other, sequence.id, %{
          body: "Reply",
          parent_sequence_comment_id: parent.id
        })

      assert reply.parent_sequence_comment_id == parent.id
    end

    test "list_sequence_comments/2 returns roots for sequence", %{user: user, sequence: sequence} do
      {:ok, _c1} = Engagement.create_sequence_comment(user, sequence.id, %{body: "First"})
      {:ok, _c2} = Engagement.create_sequence_comment(user, sequence.id, %{body: "Second"})

      comments = Engagement.list_sequence_comments(sequence.id)
      assert length(comments) == 2
    end

    test "delete_sequence_comment/2 hard deletes when no replies", %{
      user: user,
      sequence: sequence
    } do
      {:ok, comment} = Engagement.create_sequence_comment(user, sequence.id, %{body: "Gone"})
      assert {:ok, :deleted} = Engagement.delete_sequence_comment(user, comment)
      assert Repo.get(SequenceComment, comment.id) == nil
    end

    test "delete_sequence_comment/2 rejects unauthorized user", %{sequence: sequence} do
      author = insert(:user)
      other = insert(:user)
      {:ok, comment} = Engagement.create_sequence_comment(author, sequence.id, %{body: "Mine"})
      assert {:error, :unauthorized} = Engagement.delete_sequence_comment(other, comment)
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Profile comments — backward compatibility
  # ══════════════════════════════════════════════════════════════════════

  describe "profile comments — legacy 1-arity signatures" do
    test "create_profile_comment/1 works with attrs map", %{user: user} do
      profile = insert(:user)

      assert {:ok, comment} =
               Engagement.create_profile_comment(%{
                 body: "Parabéns!",
                 author_id: user.id,
                 profile_id: profile.id
               })

      assert comment.body == "Parabéns!"
      assert comment.author_id == user.id
      assert comment.profile_id == profile.id
    end

    test "list_profile_comments/1 works with opts keyword list" do
      profile = insert(:user)
      author = insert(:user)

      insert(:profile_comment, author: author, profile: profile, body: "Hello")

      comments = Engagement.list_profile_comments(profile_id: profile.id, preload: [:author])
      assert length(comments) == 1
      assert hd(comments).body == "Hello"
      assert hd(comments).author.id == author.id
    end

    test "delete_profile_comment/1 soft-deletes the comment" do
      comment = insert(:profile_comment)
      assert {:ok, deleted} = Engagement.delete_profile_comment(comment)
      assert deleted.deleted_at != nil
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Profile comments — new generic API
  # ══════════════════════════════════════════════════════════════════════

  describe "profile comments — new typed API" do
    test "create_profile_comment/3 creates via generic pipeline", %{user: user} do
      profile = insert(:user)

      assert {:ok, comment} =
               Engagement.create_profile_comment(user, profile.id, %{body: "Via generic!"})

      assert comment.body == "Via generic!"
      assert comment.author_id == user.id
      assert comment.profile_id == profile.id
      # author association should be preloaded
      assert comment.author != nil
    end

    test "list_profile_comments/2 returns roots by engagement", %{user: user} do
      profile = insert(:user)

      {:ok, _c1} = Engagement.create_profile_comment(user, profile.id, %{body: "First"})
      {:ok, _c2} = Engagement.create_profile_comment(user, profile.id, %{body: "Second"})

      comments = Engagement.list_profile_comments(profile.id, [])
      assert length(comments) == 2
    end

    test "delete_profile_comment/2 with authorization", %{user: user} do
      profile = insert(:user)
      {:ok, comment} = Engagement.create_profile_comment(user, profile.id, %{body: "Mine"})
      assert {:ok, :deleted} = Engagement.delete_profile_comment(user, comment)
    end

    test "delete_profile_comment/2 rejects unauthorized user" do
      author = insert(:user)
      other = insert(:user)
      profile = insert(:user)
      {:ok, comment} = Engagement.create_profile_comment(author, profile.id, %{body: "Mine"})
      assert {:error, :unauthorized} = Engagement.delete_profile_comment(other, comment)
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Replies
  # ══════════════════════════════════════════════════════════════════════

  describe "list_replies/3" do
    test "returns replies for a step comment", %{user: user, step: step} do
      {:ok, parent} = Engagement.create_step_comment(user, step.id, %{body: "Parent"})
      other = insert(:user)

      {:ok, _r1} =
        Engagement.create_step_comment(other, step.id, %{
          body: "Reply 1",
          parent_step_comment_id: parent.id
        })

      {:ok, _r2} =
        Engagement.create_step_comment(user, step.id, %{
          body: "Reply 2",
          parent_step_comment_id: parent.id
        })

      replies = Engagement.list_replies(StepCommentQuery, parent.id)
      assert length(replies) == 2
      # All replies should have user preloaded
      Enum.each(replies, fn r -> assert r.user != nil end)
    end

    test "returns replies for a sequence comment", %{user: user, sequence: sequence} do
      {:ok, parent} = Engagement.create_sequence_comment(user, sequence.id, %{body: "Parent"})

      {:ok, _reply} =
        Engagement.create_sequence_comment(user, sequence.id, %{
          body: "Reply",
          parent_sequence_comment_id: parent.id
        })

      replies = Engagement.list_replies(SequenceCommentQuery, parent.id)
      assert length(replies) == 1
    end

    test "returns empty list when no replies exist", %{user: user, step: step} do
      {:ok, parent} = Engagement.create_step_comment(user, step.id, %{body: "Alone"})
      replies = Engagement.list_replies(StepCommentQuery, parent.id)
      assert replies == []
    end

    test "returns replies for a profile comment", %{user: user} do
      profile = insert(:user)
      {:ok, parent} = Engagement.create_profile_comment(user, profile.id, %{body: "Parent"})
      other = insert(:user)

      {:ok, _reply} =
        Engagement.create_profile_comment(other, profile.id, %{
          body: "Reply",
          parent_profile_comment_id: parent.id
        })

      replies = Engagement.list_replies(ProfileCommentQuery, parent.id)
      assert length(replies) == 1
      assert hd(replies).author != nil
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Comment counts
  # ══════════════════════════════════════════════════════════════════════

  describe "comment_counts_for/2" do
    test "returns counts per step", %{user: user, step: step} do
      other_step = insert(:step)
      {:ok, _} = Engagement.create_step_comment(user, step.id, %{body: "A"})
      {:ok, _} = Engagement.create_step_comment(user, step.id, %{body: "B"})
      {:ok, _} = Engagement.create_step_comment(user, other_step.id, %{body: "C"})

      counts = Engagement.comment_counts_for("step", [step.id, other_step.id])
      assert counts[step.id] == 2
      assert counts[other_step.id] == 1
    end

    test "returns counts per sequence", %{user: user, sequence: sequence} do
      other_sequence = insert(:sequence, user: user)
      {:ok, _} = Engagement.create_sequence_comment(user, sequence.id, %{body: "A"})
      {:ok, _} = Engagement.create_sequence_comment(user, other_sequence.id, %{body: "B"})

      counts = Engagement.comment_counts_for("sequence", [sequence.id, other_sequence.id])
      assert counts[sequence.id] == 1
      assert counts[other_sequence.id] == 1
    end

    test "returns 0 for IDs with no comments" do
      missing_id = Ecto.UUID.generate()
      counts = Engagement.comment_counts_for("step", [missing_id])
      assert counts[missing_id] == 0
    end

    test "excludes deleted comments from counts", %{user: user, step: step} do
      {:ok, _c1} = Engagement.create_step_comment(user, step.id, %{body: "Active"})
      {:ok, c2} = Engagement.create_step_comment(user, step.id, %{body: "Deleted"})

      # Soft-delete c2
      c2
      |> Ecto.Changeset.change(deleted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
      |> Repo.update!()

      counts = Engagement.comment_counts_for("step", [step.id])
      assert counts[step.id] == 1
    end

    test "returns counts for profile comments" do
      profile = insert(:user)
      author = insert(:user)
      insert(:profile_comment, author: author, profile: profile)
      insert(:profile_comment, author: author, profile: profile)

      counts = Engagement.comment_counts_for("profile", [profile.id])
      assert counts[profile.id] == 2
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Notifications
  # ══════════════════════════════════════════════════════════════════════

  describe "list_notifications/2" do
    test "returns notifications for a user ordered unread first", %{user: user} do
      actor = insert(:user)

      read = insert(:notification, user: user, actor: actor, read_at: ~N[2026-01-01 00:00:00])
      unread = insert(:notification, user: user, actor: actor, read_at: nil)

      notifications = Engagement.list_notifications(user.id)
      notification_ids = Enum.map(notifications, & &1.id)

      # Unread (nil read_at) should come before read
      assert List.first(notification_ids) == unread.id
      assert List.last(notification_ids) == read.id
    end

    test "respects limit and offset", %{user: user} do
      actor = insert(:user)

      for _ <- 1..5, do: insert(:notification, user: user, actor: actor)

      page1 = Engagement.list_notifications(user.id, limit: 2, offset: 0)
      page2 = Engagement.list_notifications(user.id, limit: 2, offset: 2)

      assert length(page1) == 2
      assert length(page2) == 2
      refute hd(page1).id == hd(page2).id
    end
  end

  describe "unread_count/1" do
    test "returns 0 when no unread notifications", %{user: user} do
      assert 0 == Engagement.unread_count(user.id)
    end

    test "counts unread notifications", %{user: user} do
      actor = insert(:user)
      insert(:notification, user: user, actor: actor, read_at: nil)
      insert(:notification, user: user, actor: actor, read_at: nil)
      insert(:notification, user: user, actor: actor, read_at: ~N[2026-01-01 00:00:00])

      assert 2 == Engagement.unread_count(user.id)
    end
  end

  describe "mark_as_read/2" do
    test "marks a single notification as read", %{user: user} do
      actor = insert(:user)
      notification = insert(:notification, user: user, actor: actor, read_at: nil)

      assert {:ok, :marked} = Engagement.mark_as_read(user, notification.id)

      updated = Repo.get!(Notification, notification.id)
      assert updated.read_at != nil
    end

    test "returns :already_read for already-read notification", %{user: user} do
      actor = insert(:user)

      notification =
        insert(:notification, user: user, actor: actor, read_at: ~N[2026-01-01 00:00:00])

      assert {:ok, :already_read} = Engagement.mark_as_read(user, notification.id)
    end

    test "does not mark another user's notification", %{user: user} do
      other = insert(:user)
      actor = insert(:user)
      notification = insert(:notification, user: other, actor: actor, read_at: nil)

      assert {:ok, :already_read} = Engagement.mark_as_read(user, notification.id)
      # The notification should still be unread
      assert is_nil(Repo.get!(Notification, notification.id).read_at)
    end
  end

  describe "mark_all_read/1" do
    test "marks all unread notifications as read", %{user: user} do
      actor = insert(:user)
      insert(:notification, user: user, actor: actor, read_at: nil)
      insert(:notification, user: user, actor: actor, read_at: nil)
      insert(:notification, user: user, actor: actor, read_at: ~N[2026-01-01 00:00:00])

      assert {:ok, 2} = Engagement.mark_all_read(user)
      assert 0 == Engagement.unread_count(user.id)
    end

    test "returns 0 when no unread notifications", %{user: user} do
      assert {:ok, 0} = Engagement.mark_all_read(user)
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Favorites
  # ══════════════════════════════════════════════════════════════════════

  describe "favorites" do
    test "toggle_favorite/3 creates favorite + auto-likes", %{user: user, step: step} do
      assert {:ok, :favorited} = Engagement.toggle_favorite(user.id, "step", step.id)
      assert Engagement.favorited?(user.id, "step", step.id)
      assert Engagement.liked?(user.id, "step", step.id)
    end

    test "toggle_favorite/3 removes favorite but keeps like", %{user: user, step: step} do
      {:ok, :favorited} = Engagement.toggle_favorite(user.id, "step", step.id)
      {:ok, :unfavorited} = Engagement.toggle_favorite(user.id, "step", step.id)
      refute Engagement.favorited?(user.id, "step", step.id)
      assert Engagement.liked?(user.id, "step", step.id)
    end

    test "toggle_favorite/3 does not double-like if already liked", %{user: user, step: step} do
      Engagement.toggle_like(user.id, "step", step.id)
      {:ok, :favorited} = Engagement.toggle_favorite(user.id, "step", step.id)
      assert Engagement.liked?(user.id, "step", step.id)
    end

    test "favorites_map/3 returns favorited_ids MapSet", %{user: user, step: step} do
      other_step = insert(:step)
      Engagement.toggle_favorite(user.id, "step", step.id)
      result = Engagement.favorites_map(user.id, "step", [step.id, other_step.id])
      assert MapSet.member?(result, step.id)
      refute MapSet.member?(result, other_step.id)
    end

    test "list_user_favorites/2 returns favorited steps", %{user: user, step: step} do
      Engagement.toggle_favorite(user.id, "step", step.id)
      favorites = Engagement.list_user_favorites(user.id, "step")
      assert length(favorites) == 1
      assert hd(favorites).id == step.id
    end

    test "count_user_favorites/1 counts all favorites", %{user: user, step: step} do
      Engagement.toggle_favorite(user.id, "step", step.id)
      assert Engagement.count_user_favorites(user.id) == 1
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Metrics
  # ══════════════════════════════════════════════════════════════════════

  describe "metrics" do
    test "liked_step_ids/1 returns MapSet of liked step ids", %{user: user, step: step} do
      Engagement.toggle_like(user.id, "step", step.id)
      ids = Engagement.liked_step_ids(user.id)
      assert MapSet.member?(ids, step.id)
    end

    test "count_likes_given/2 counts likes by type", %{user: user, step: step} do
      Engagement.toggle_like(user.id, "step", step.id)
      assert Engagement.count_likes_given(user.id, "step") == 1
    end

    test "count_comments_authored/1 counts all comment types", %{user: user, step: step} do
      Engagement.create_step_comment(user, step.id, %{body: "Test 1"})
      Engagement.create_step_comment(user, step.id, %{body: "Test 2"})
      assert Engagement.count_comments_authored(user.id) >= 2
    end

    test "total_likes_received/1 counts likes on user's comments", %{user: user, step: step} do
      {:ok, comment} = Engagement.create_step_comment(user, step.id, %{body: "My comment"})
      other = insert(:user)
      Engagement.toggle_like(other.id, "step_comment", comment.id)
      assert Engagement.total_likes_received(user.id) >= 1
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Follows
  # ══════════════════════════════════════════════════════════════════════

  describe "follows" do
    test "toggle_follow/2 creates a follow", %{user: user} do
      other = insert(:user)
      assert {:ok, :followed} = Engagement.toggle_follow(user.id, other.id)
      assert Engagement.following?(user.id, other.id)
    end

    test "toggle_follow/2 removes follow on second call", %{user: user} do
      other = insert(:user)
      {:ok, :followed} = Engagement.toggle_follow(user.id, other.id)
      {:ok, :unfollowed} = Engagement.toggle_follow(user.id, other.id)
      refute Engagement.following?(user.id, other.id)
    end

    test "toggle_follow/2 rejects self-follow", %{user: user} do
      assert {:error, _} = Engagement.toggle_follow(user.id, user.id)
    end

    test "following?/2 returns false when not following", %{user: user} do
      other = insert(:user)
      refute Engagement.following?(user.id, other.id)
    end

    test "list_following/1 returns followed users", %{user: user} do
      u1 = insert(:user)
      u2 = insert(:user)
      Engagement.toggle_follow(user.id, u1.id)
      Engagement.toggle_follow(user.id, u2.id)
      following = Engagement.list_following(user.id)
      assert length(following) == 2
      assert Enum.any?(following, &(&1.id == u1.id))
    end

    test "list_followers/1 returns followers", %{user: user} do
      u1 = insert(:user)
      u2 = insert(:user)
      Engagement.toggle_follow(u1.id, user.id)
      Engagement.toggle_follow(u2.id, user.id)
      followers = Engagement.list_followers(user.id)
      assert length(followers) == 2
    end

    test "list_following/2 supports search filter", %{user: user} do
      maria = insert(:user, username: "maria_danca", name: "Maria Silva")
      joao = insert(:user, username: "joao_forro", name: "João Santos")
      Engagement.toggle_follow(user.id, maria.id)
      Engagement.toggle_follow(user.id, joao.id)
      results = Engagement.list_following(user.id, search: "maria")
      assert length(results) == 1
      assert hd(results).id == maria.id
    end

    test "count_following/1 and count_followers/1", %{user: user} do
      u1 = insert(:user)
      u2 = insert(:user)
      Engagement.toggle_follow(user.id, u1.id)
      Engagement.toggle_follow(user.id, u2.id)
      Engagement.toggle_follow(u1.id, user.id)
      assert Engagement.count_following(user.id) == 2
      assert Engagement.count_followers(user.id) == 1
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Follow edge cases
  # ══════════════════════════════════════════════════════════════════════

  describe "follow edge cases" do
    test "triple toggle restores follow and count stays at 1", %{user: user} do
      other = insert(:user)
      {:ok, :followed} = Engagement.toggle_follow(user.id, other.id)
      {:ok, :unfollowed} = Engagement.toggle_follow(user.id, other.id)
      {:ok, :followed} = Engagement.toggle_follow(user.id, other.id)
      assert Engagement.following?(user.id, other.id)
      assert Engagement.count_following(user.id) == 1
    end

    test "follow is directional — A following B does not mean B follows A", %{user: user} do
      other = insert(:user)
      Engagement.toggle_follow(user.id, other.id)
      assert Engagement.following?(user.id, other.id)
      refute Engagement.following?(other.id, user.id)
    end

    test "list_followers search filters by username case-insensitively", %{user: user} do
      beatriz = insert(:user, username: "beatriz_roots", name: "Beatriz")
      rui = insert(:user, username: "rui_forro", name: "Rui Santos")
      Engagement.toggle_follow(beatriz.id, user.id)
      Engagement.toggle_follow(rui.id, user.id)
      results = Engagement.list_followers(user.id, search: "BEATRIZ")
      assert length(results) == 1
      assert hd(results).id == beatriz.id
    end

    test "list_following returns empty list when user follows nobody", %{user: user} do
      assert Engagement.list_following(user.id) == []
    end

    test "unfollowed user no longer appears in list_following", %{user: user} do
      other = insert(:user)
      {:ok, :followed} = Engagement.toggle_follow(user.id, other.id)
      {:ok, :unfollowed} = Engagement.toggle_follow(user.id, other.id)
      following = Engagement.list_following(user.id)
      refute Enum.any?(following, &(&1.id == other.id))
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Favorites edge cases
  # ══════════════════════════════════════════════════════════════════════

  describe "favorite edge cases" do
    test "favoriting already-liked step does not create duplicate like", %{user: user, step: step} do
      Engagement.toggle_like(user.id, "step", step.id)
      {:ok, :favorited} = Engagement.toggle_favorite(user.id, "step", step.id)
      assert Engagement.count_likes("step", step.id) == 1
    end

    test "list_user_favorites returns favorited steps ordered newest first", %{user: user} do
      s1 = insert(:step)
      s2 = insert(:step)
      Engagement.toggle_favorite(user.id, "step", s1.id)
      # Wait > 1s so Postgres NaiveDateTime (second precision) differs between the two favorites
      Process.sleep(1100)
      Engagement.toggle_favorite(user.id, "step", s2.id)
      favorites = Engagement.list_user_favorites(user.id, "step")
      assert length(favorites) == 2
      assert hd(favorites).id == s2.id
    end

    test "list_user_favorites excludes deleted steps", %{user: user} do
      step = insert(:step)
      Engagement.toggle_favorite(user.id, "step", step.id)

      step
      |> Ecto.Changeset.change(deleted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
      |> Repo.update!()

      assert Engagement.list_user_favorites(user.id, "step") == []
    end

    test "count_user_favorites reflects toggle off", %{user: user, step: step} do
      {:ok, :favorited} = Engagement.toggle_favorite(user.id, "step", step.id)
      assert Engagement.count_user_favorites(user.id) == 1
      {:ok, :unfavorited} = Engagement.toggle_favorite(user.id, "step", step.id)
      assert Engagement.count_user_favorites(user.id) == 0
    end
  end
end
