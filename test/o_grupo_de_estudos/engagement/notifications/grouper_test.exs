defmodule OGrupoDeEstudos.Engagement.Notifications.GrouperTest do
  use OGrupoDeEstudos.DataCase, async: true
  import OGrupoDeEstudos.Factory
  alias OGrupoDeEstudos.Engagement.Notifications.Grouper

  test "groups notifications sharing the same group_key, newest actor first" do
    user1 = insert(:user)
    user2 = insert(:user)
    target_id = Ecto.UUID.generate()
    receiver = insert(:user)

    n1 =
      insert(:notification,
        actor: user1,
        user: receiver,
        group_key: "like:step:#{target_id}",
        action: "liked_step",
        inserted_at: ~N[2026-01-01 10:00:00]
      )

    n2 =
      insert(:notification,
        actor: user2,
        user: receiver,
        group_key: "like:step:#{target_id}",
        action: "liked_step",
        inserted_at: ~N[2026-01-01 11:00:00]
      )

    assert [entry] = Grouper.group([n1, n2])
    assert entry.count == 2
    # Most recent actor (user2) appears first
    assert entry.actors == [user2.id, user1.id]
    assert entry.id == n2.id
  end

  test "keeps notifications with different group_keys separate" do
    receiver = insert(:user)
    n1 = insert(:notification, user: receiver, group_key: "like:step:#{Ecto.UUID.generate()}")
    n2 = insert(:notification, user: receiver, group_key: "follow:#{Ecto.UUID.generate()}")

    assert length(Grouper.group([n1, n2])) == 2
  end

  test "deduplicates the same actor within a group" do
    actor = insert(:user)
    receiver = insert(:user)
    key = "like:step:#{Ecto.UUID.generate()}"

    n1 = insert(:notification, actor: actor, user: receiver, group_key: key)
    n2 = insert(:notification, actor: actor, user: receiver, group_key: key)

    assert [entry] = Grouper.group([n1, n2])
    assert entry.count == 1
    assert entry.actors == [actor.id]
  end

  test "group is unread when any notification in it is unread" do
    receiver = insert(:user)
    key = "like:step:#{Ecto.UUID.generate()}"
    read_at = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    n1 = insert(:notification, user: receiver, group_key: key, read_at: read_at)
    n2 = insert(:notification, user: receiver, group_key: key, read_at: nil)

    assert [entry] = Grouper.group([n1, n2])
    refute entry.read
  end

  test "returns read: false for unread notification" do
    receiver = insert(:user)
    n = insert(:notification, user: receiver, read_at: nil)

    [entry] = Grouper.group([n])
    refute entry.read
  end

  test "returns read: true for read notification" do
    receiver = insert(:user)
    n = insert(:notification, user: receiver, read_at: DateTime.utc_now())

    [entry] = Grouper.group([n])
    assert entry.read
  end

  test "sorts by latest_at descending" do
    receiver = insert(:user)

    n1 =
      insert(:notification,
        user: receiver,
        inserted_at: ~N[2026-01-01 10:00:00]
      )

    n2 =
      insert(:notification,
        user: receiver,
        inserted_at: ~N[2026-01-02 10:00:00]
      )

    [first, second] = Grouper.group([n1, n2])
    assert first.id == n2.id
    assert second.id == n1.id
  end
end
