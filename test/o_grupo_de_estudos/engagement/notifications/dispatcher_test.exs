defmodule OGrupoDeEstudos.Engagement.Notifications.DispatcherTest do
  use OGrupoDeEstudos.DataCase, async: true
  import Ecto.Query
  import OGrupoDeEstudos.Factory
  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Study

  test "replying to a comment notifies the parent comment author" do
    step = insert(:step)
    author = insert(:user)
    replier = insert(:user)

    {:ok, parent} = Engagement.create_step_comment(author, step.id, %{body: "I'm the parent"})

    {:ok, _reply} =
      Engagement.create_step_comment(replier, step.id, %{
        body: "I'm the reply",
        parent_step_comment_id: parent.id
      })

    notifications = Repo.all(from n in Notification, where: n.user_id == ^author.id)
    assert length(notifications) == 1
    [notif] = notifications
    assert notif.action == "replied_comment"
    assert notif.actor_id == replier.id
  end

  test "replying to own comment does NOT create notification" do
    step = insert(:step)
    user = insert(:user)

    {:ok, parent} = Engagement.create_step_comment(user, step.id, %{body: "Parent"})

    {:ok, _reply} =
      Engagement.create_step_comment(user, step.id, %{
        body: "Self reply",
        parent_step_comment_id: parent.id
      })

    notifications = Repo.all(from n in Notification, where: n.user_id == ^user.id)
    assert notifications == []
  end

  test "root comment does not generate notification" do
    step = insert(:step)
    user = insert(:user)
    {:ok, _comment} = Engagement.create_step_comment(user, step.id, %{body: "Root"})
    assert Repo.aggregate(Notification, :count) == 0
  end

  # ── Like notifications ──────────────────────────────────────────────
  # Likes/favorites intentionally do NOT generate notifications (safe_dispatch_like is a no-op).

  test "liking a step comment does NOT create a notification" do
    step = insert(:step)
    author = insert(:user)
    liker = insert(:user)

    {:ok, comment} = Engagement.create_step_comment(author, step.id, %{body: "My comment"})
    Engagement.toggle_like(liker.id, "step_comment", comment.id)

    notifications =
      Repo.all(
        from n in Notification,
          where: n.user_id == ^author.id and n.action == "liked_comment"
      )

    assert notifications == []
  end

  test "liking a sequence comment does NOT create a notification" do
    author = insert(:user)
    liker = insert(:user)
    sequence = insert(:sequence, user: author)

    {:ok, comment} =
      Engagement.create_sequence_comment(author, sequence.id, %{body: "Sequence comment"})

    Engagement.toggle_like(liker.id, "sequence_comment", comment.id)

    notifications =
      Repo.all(
        from n in Notification,
          where: n.user_id == ^author.id and n.action == "liked_comment"
      )

    assert notifications == []
  end

  test "liking a community step does NOT create a notification" do
    section = insert(:section)
    suggester = insert(:user)
    liker = insert(:user)

    step =
      insert(:step,
        section: section,
        code: "DISP-1",
        name: "Passo Sugerido",
        suggested_by: suggester
      )

    Engagement.toggle_like(liker.id, "step", step.id)

    notifications =
      Repo.all(
        from n in Notification,
          where: n.user_id == ^suggester.id and n.action == "liked_step"
      )

    assert notifications == []
  end

  test "liking does not notify the author if the comment is deleted" do
    step = insert(:step)
    author = insert(:user)
    liker = insert(:user)

    {:ok, comment} = Engagement.create_step_comment(author, step.id, %{body: "Will be gone"})

    comment
    |> Ecto.Changeset.change(
      deleted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    )
    |> Repo.update!()

    Engagement.toggle_like(liker.id, "step_comment", comment.id)

    author_notifications =
      Repo.all(
        from n in Notification,
          where: n.user_id == ^author.id and n.action == "liked_comment"
      )

    assert author_notifications == []
  end

  test "notify_shared_note/3 creates notification for student" do
    teacher = insert(:user, is_teacher: true)
    student = insert(:user)
    {:ok, link} = Study.accept_invite(student, teacher.invite_slug)
    {:ok, link} = Study.accept_link_request(link, teacher)

    Dispatcher.notify_shared_note(teacher, student.id, link.id)

    notifications =
      Repo.all(
        from n in Notification,
          where: n.user_id == ^student.id and n.action == "shared_note_updated"
      )

    assert notifications != []
    [notif] = notifications
    assert notif.actor_id == teacher.id
    assert notif.target_id == link.id
  end

  test "following a user creates a follow notification" do
    follower = insert(:user)
    followed = insert(:user)

    Engagement.toggle_follow(follower.id, followed.id)

    [notification] =
      Repo.all(
        from n in Notification,
          where: n.user_id == ^followed.id and n.action == "followed_user"
      )

    assert notification.actor_id == follower.id
    assert notification.target_type == "profile"
    assert notification.parent_type == "profile"
    assert notification.parent_id == follower.id
  end
end
