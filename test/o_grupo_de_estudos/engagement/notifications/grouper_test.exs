defmodule OGrupoDeEstudos.Engagement.Notifications.GrouperTest do
  use OGrupoDeEstudos.DataCase, async: true
  import OGrupoDeEstudos.Factory
  alias OGrupoDeEstudos.Engagement.Notifications.Grouper

  test "groups notifications by group_key" do
    user1 = insert(:user)
    user2 = insert(:user)
    user3 = insert(:user)
    target_id = Ecto.UUID.generate()
    receiver = insert(:user)

    n1 =
      insert(:notification,
        actor: user1,
        user: receiver,
        group_key: "like:sc:#{target_id}",
        action: "liked_comment"
      )

    n2 =
      insert(:notification,
        actor: user2,
        user: receiver,
        group_key: "like:sc:#{target_id}",
        action: "liked_comment"
      )

    n3 =
      insert(:notification,
        actor: user3,
        user: receiver,
        group_key: "other:key",
        action: "replied_comment"
      )

    grouped = Grouper.group([n1, n2, n3])
    assert length(grouped) == 2
    like_group = Enum.find(grouped, &(&1.action == "liked_comment"))
    assert length(like_group.actors) == 2
    assert like_group.count == 2
  end

  test "returns read: false when any notification in group is unread" do
    target_id = Ecto.UUID.generate()
    receiver = insert(:user)

    n1 = insert(:notification, user: receiver, group_key: "like:sc:#{target_id}", read_at: nil)

    n2 =
      insert(:notification,
        user: receiver,
        group_key: "like:sc:#{target_id}",
        read_at: NaiveDateTime.utc_now()
      )

    [group] = Grouper.group([n1, n2])
    refute group.read
  end

  test "returns read: true when all in group are read" do
    now = NaiveDateTime.utc_now()
    target_id = Ecto.UUID.generate()
    receiver = insert(:user)

    n1 = insert(:notification, user: receiver, group_key: "like:sc:#{target_id}", read_at: now)
    n2 = insert(:notification, user: receiver, group_key: "like:sc:#{target_id}", read_at: now)

    [group] = Grouper.group([n1, n2])
    assert group.read
  end
end
