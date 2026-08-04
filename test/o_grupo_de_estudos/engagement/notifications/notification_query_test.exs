defmodule OGrupoDeEstudos.Engagement.Notifications.NotificationQueryTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement.Notifications.{Grouper, Notification, NotificationQuery}
  alias OGrupoDeEstudos.Repo

  defp notificar(user, actor, group_key, opts) do
    now = Keyword.get(opts, :at, NaiveDateTime.utc_now()) |> NaiveDateTime.truncate(:second)

    Repo.insert_all(Notification, [
      %{
        id: Ecto.UUID.generate(),
        user_id: user.id,
        actor_id: actor.id,
        action: Keyword.get(opts, :action, :followed_user),
        group_key: group_key,
        target_type: "profile",
        target_id: actor.id,
        parent_type: "profile",
        parent_id: actor.id,
        read_at: Keyword.get(opts, :read_at),
        inserted_at: now
      }
    ])
  end

  defp minutos_atras(n), do: NaiveDateTime.add(NaiveDateTime.utc_now(), -n * 60, :second)

  describe "list_for_user/2 com limite" do
    test "limit counts subjects, not rows", %{} do
      owner = insert(:user)

      for i <- 1..30 do
        notificar(owner, insert(:user), "workshop_enrolled:abc", at: minutos_atras(i))
      end

      antiga = insert(:user)
      notificar(owner, antiga, "follow:xyz", at: minutos_atras(100))

      notifications = NotificationQuery.list_for_user(owner.id, limit: 8)
      grupos = Grouper.group(notifications)

      assert length(grupos) == 2
      assert Enum.find(grupos, &(&1.parent_id == antiga.id))
    end

    test "actor count of a group survives the cut" do
      owner = insert(:user)

      for i <- 1..30 do
        notificar(owner, insert(:user), "workshop_enrolled:abc", at: minutos_atras(i))
      end

      [grupo] =
        owner.id
        |> NotificationQuery.list_for_user(limit: 8)
        |> Grouper.group()

      assert grupo.count == 30
    end

    test "when only one subject fits, the unread one wins over the most recent read" do
      owner = insert(:user)
      lido = insert(:user)
      nao_lido = insert(:user)
      agora = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      notificar(owner, lido, "follow:lido",
        at: agora,
        read_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      notificar(owner, nao_lido, "follow:novo", at: minutos_atras(30))

      assert [notification] = NotificationQuery.list_for_user(owner.id, limit: 1)
      assert notification.actor_id == nao_lido.id
    end

    test "offset pagina por assunto" do
      owner = insert(:user)

      for i <- 1..5 do
        notificar(owner, insert(:user), "follow:#{i}", at: minutos_atras(i))
      end

      first_page = owner.id |> NotificationQuery.list_for_user(limit: 2) |> Grouper.group()

      second_page =
        owner.id |> NotificationQuery.list_for_user(limit: 2, offset: 2) |> Grouper.group()

      assert length(first_page) == 2
      assert length(second_page) == 2

      first_page_ids = MapSet.new(first_page, & &1.id)
      second_page_ids = MapSet.new(second_page, & &1.id)
      assert MapSet.disjoint?(first_page_ids, second_page_ids)
    end

    test "returns an empty list when there is no notification" do
      assert NotificationQuery.list_for_user(insert(:user).id, limit: 8) == []
    end
  end
end
