defmodule OGrupoDeEstudosWeb.NotificationsLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement

  defp logged_in_conn(conn) do
    user = insert(:user)
    {log_in_user(conn, user), user}
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

      # Most recent actor is primary, plus the others, with a plural verb
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
