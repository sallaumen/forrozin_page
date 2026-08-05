defmodule OGrupoDeEstudosWeb.WorkshopModerationTest do
  @moduledoc """
  Whoever runs the workshop takes down what should not be on its page.

  Someone posted a payment receipt in the gallery by mistake and neither she nor
  the organizer got it off the page. What lands on a workshop has to be
  removable by whoever runs that workshop, without waiting for a site admin.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Engagement, Workshops}

  setup do
    organizer = insert(:user, is_teacher: true)
    student = insert(:user)
    workshop = insert(:workshop, organizer: organizer)
    {:ok, _} = Workshops.enroll(workshop, student)

    {:ok, comment} =
      Engagement.create_workshop_comment(student, workshop.id, %{body: "Comentário fora de hora."})

    %{organizer: organizer, student: student, workshop: workshop, comment: comment}
  end

  defp open(conn, user, workshop),
    do: live(log_in_user(conn, user), ~p"/workshops/#{workshop.slug}")

  defp trash(comment),
    do: "button[phx-click='delete_comment'][phx-value-id='#{comment.id}']"

  describe "a comment written by someone else" do
    test "whoever organizes takes it down", ctx do
      {:ok, lv, _} = open(ctx.conn, ctx.organizer, ctx.workshop)

      assert has_element?(lv, trash(ctx.comment))
      lv |> element(trash(ctx.comment)) |> render_click()

      refute Engagement.get_workshop_comment(ctx.comment.id)
    end

    test "a co-organizer takes it down too", ctx do
      partner = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.organizer, partner.id)

      {:ok, lv, _} = open(ctx.conn, partner, ctx.workshop)
      lv |> element(trash(ctx.comment)) |> render_click()

      refute Engagement.get_workshop_comment(ctx.comment.id)
    end

    test "another person in the class is not offered the trash", ctx do
      other = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, other)

      {:ok, lv, _} = open(ctx.conn, other, ctx.workshop)

      refute has_element?(lv, trash(ctx.comment))
    end

    test "and does not take it down by forcing the event", ctx do
      other = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, other)

      {:ok, lv, _} = open(ctx.conn, other, ctx.workshop)
      render_click(lv, "delete_comment", %{"id" => ctx.comment.id})

      assert Engagement.get_workshop_comment(ctx.comment.id)
    end

    test "whoever organizes another workshop has no reach here", ctx do
      outsider = insert(:user, is_teacher: true)
      _elsewhere = insert(:workshop, organizer: outsider)
      {:ok, _} = Workshops.enroll(ctx.workshop, outsider)

      {:ok, lv, _} = open(ctx.conn, outsider, ctx.workshop)
      render_click(lv, "delete_comment", %{"id" => ctx.comment.id})

      assert Engagement.get_workshop_comment(ctx.comment.id)
    end
  end

  describe "a comment of one's own" do
    test "whoever wrote it still takes it down", ctx do
      {:ok, lv, _} = open(ctx.conn, ctx.student, ctx.workshop)

      assert has_element?(lv, trash(ctx.comment))
      lv |> element(trash(ctx.comment)) |> render_click()

      refute Engagement.get_workshop_comment(ctx.comment.id)
    end
  end
end
