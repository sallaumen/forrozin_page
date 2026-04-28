defmodule OGrupoDeEstudos.Engagement.Notifications.GrouperTest do
  use OGrupoDeEstudos.DataCase, async: true
  import OGrupoDeEstudos.Factory
  alias OGrupoDeEstudos.Engagement.Notifications.Grouper

  test "returns one entry per notification (no grouping)" do
    user1 = insert(:user)
    user2 = insert(:user)
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

    result = Grouper.group([n1, n2])
    assert length(result) == 2
    assert Enum.all?(result, &(&1.count == 1))
    assert Enum.all?(result, &(length(&1.actors) == 1))
  end

  test "returns read: false for unread notification" do
    receiver = insert(:user)
    n = insert(:notification, user: receiver, read_at: nil)

    [entry] = Grouper.group([n])
    refute entry.read
  end

  test "returns read: true for read notification" do
    receiver = insert(:user)
    n = insert(:notification, user: receiver, read_at: NaiveDateTime.utc_now())

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
