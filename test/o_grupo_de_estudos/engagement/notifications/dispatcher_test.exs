defmodule OGrupoDeEstudos.Engagement.Notifications.DispatcherTest do
  use OGrupoDeEstudos.DataCase, async: true
  import Ecto.Query
  import OGrupoDeEstudos.Factory
  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Repo

  test "replying to a comment notifies the parent comment author" do
    step = insert(:step)
    author = insert(:user)
    replier = insert(:user)

    {:ok, parent} = Engagement.create_step_comment(author, step.id, %{body: "I'm the parent"})
    {:ok, _reply} = Engagement.create_step_comment(replier, step.id, %{
      body: "I'm the reply", parent_step_comment_id: parent.id
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
    {:ok, _reply} = Engagement.create_step_comment(user, step.id, %{
      body: "Self reply", parent_step_comment_id: parent.id
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
end
