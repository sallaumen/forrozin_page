defmodule OGrupoDeEstudosWeb.NotificationsLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement

  defp logged_in_conn(conn) do
    user = insert(:user)
    {log_in_user(conn, user), user}
  end

  defp notificar(user, actor, group_key, minutos_atras) do
    at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-minutos_atras * 60, :second)
      |> NaiveDateTime.truncate(:second)

    OGrupoDeEstudos.Repo.insert_all(OGrupoDeEstudos.Engagement.Notifications.Notification, [
      %{
        id: Ecto.UUID.generate(),
        user_id: user.id,
        actor_id: actor.id,
        action: :followed_user,
        group_key: group_key,
        target_type: "profile",
        target_id: actor.id,
        parent_type: "profile",
        parent_id: actor.id,
        inserted_at: at
      }
    ])
  end

  describe "pagination by subject" do
    test "button stays visible when one subject has several rows", %{conn: conn} do
      user = insert(:user)

      for i <- 1..21, do: notificar(user, insert(:user), "follow:#{i}", i)

      for _ <- 1..3, do: notificar(user, insert(:user), "follow:1", 1)

      {:ok, _lv, html} = live(log_in_user(conn, user), ~p"/notifications")

      assert html =~ "Carregar mais"
    end

    test "button disappears when no subject is left", %{conn: conn} do
      user = insert(:user)
      for i <- 1..3, do: notificar(user, insert(:user), "follow:#{i}", i)

      {:ok, _lv, html} = live(log_in_user(conn, user), ~p"/notifications")

      refute html =~ "Carregar mais"
    end

    test "loading more brings the remaining subjects", %{conn: conn} do
      user = insert(:user)
      for i <- 1..25, do: notificar(user, insert(:user), "follow:#{i}", i)

      {:ok, lv, html} = live(log_in_user(conn, user), ~p"/notifications")
      assert html =~ "Carregar mais"

      html = render_click(lv, "load_more", %{})

      refute html =~ "Carregar mais"
    end
  end

  describe "access" do
    test "redirects to /login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/notifications")
    end
  end

  describe "mount" do
    test "renders empty state when no notifications", %{conn: conn} do
      {conn, _user} = logged_in_conn(conn)
      {:ok, _view, html} = live(conn, ~p"/notifications")
      assert html =~ "Nenhuma notificação"
    end

    test "renders notifications when they exist", %{conn: conn} do
      {conn, user} = logged_in_conn(conn)
      step = insert(:step)
      {:ok, comment} = Engagement.create_step_comment(user, step.id, %{body: "My comment"})
      replier = insert(:user)

      {:ok, _reply} =
        Engagement.create_step_comment(replier, step.id, %{
          body: "Reply!",
          parent_step_comment_id: comment.id
        })

      {:ok, _view, html} = live(conn, ~p"/notifications")
      assert html =~ "respondeu"
    end

    test "groups same-target likes into one row with plural verb and 'e mais N'", %{conn: conn} do
      {conn, user} = logged_in_conn(conn)
      step = insert(:step)
      actor1 = insert(:user, name: "Maria Souza")
      actor2 = insert(:user, name: "Joao Lima")
      key = "like:step:#{step.id}"

      insert(:notification,
        user: user,
        actor: actor1,
        action: :liked_step,
        target_type: "step",
        target_id: step.id,
        parent_type: "step",
        parent_id: step.id,
        group_key: key,
        inserted_at: ~N[2026-01-01 10:00:00]
      )

      insert(:notification,
        user: user,
        actor: actor2,
        action: :liked_step,
        target_type: "step",
        target_id: step.id,
        parent_type: "step",
        parent_id: step.id,
        group_key: key,
        inserted_at: ~N[2026-01-01 11:00:00]
      )

      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "Joao Lima"
      assert html =~ "e mais 1"
      assert html =~ "curtiram"
    end

    test "marks unread notifications as read when opened while keeping new marker", %{conn: conn} do
      {conn, user} = logged_in_conn(conn)
      actor = insert(:user)

      notification =
        insert(:notification,
          user: user,
          actor: actor,
          action: :followed_user,
          target_type: "profile",
          target_id: actor.id,
          parent_type: "profile",
          parent_id: actor.id,
          read_at: nil
        )

      {:ok, view, _html} = live(conn, ~p"/notifications")

      assert has_element?(view, "#notification-unread-#{notification.id}")
      assert Engagement.unread_count(user.id) == 0
    end
  end

  describe "mark_all_read" do
    test "clears unread notifications", %{conn: conn} do
      {conn, user} = logged_in_conn(conn)
      step = insert(:step)
      {:ok, comment} = Engagement.create_step_comment(user, step.id, %{body: "My comment"})
      replier = insert(:user)

      {:ok, _} =
        Engagement.create_step_comment(replier, step.id, %{
          body: "Reply",
          parent_step_comment_id: comment.id
        })

      {:ok, view, _html} = live(conn, ~p"/notifications")

      view |> render_click("mark_all_read", %{})

      assert Engagement.unread_count(user.id) == 0
    end
  end

  describe "mark_read" do
    test "marks individual notification as read", %{conn: conn} do
      {conn, user} = logged_in_conn(conn)
      step = insert(:step)
      {:ok, comment} = Engagement.create_step_comment(user, step.id, %{body: "Test"})
      replier = insert(:user)

      {:ok, _} =
        Engagement.create_step_comment(replier, step.id, %{
          body: "Reply",
          parent_step_comment_id: comment.id
        })

      assert Engagement.unread_count(user.id) >= 1

      {:ok, view, _html} = live(conn, ~p"/notifications")

      notif = hd(Engagement.list_notifications(user.id))
      view |> render_click("mark_read", %{"id" => notif.id})

      assert Engagement.unread_count(user.id) == 0
    end
  end
end
