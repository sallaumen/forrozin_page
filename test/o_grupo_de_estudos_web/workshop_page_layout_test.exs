defmodule OGrupoDeEstudosWeb.WorkshopPageLayoutTest do
  @moduledoc """
  What the workshop page says once, and what it used to say twice.

  The page grew by stacking boxes: the panel link sat both under the title and
  inside the price card, and every state announced itself with a border, a
  background, an icon and a sentence at the same time. These lock the page down
  to one statement per fact.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Workshops

  setup do
    organizer = insert(:user, is_teacher: true)
    student = insert(:user)

    workshop =
      insert(:workshop,
        organizer: organizer,
        price_cents: 5000,
        capacity: 20,
        location: "Telhado do Tatá"
      )

    %{organizer: organizer, student: student, workshop: workshop}
  end

  defp open(conn, user, workshop),
    do: live(log_in_user(conn, user), ~p"/workshops/#{workshop.slug}")

  defp occurrences(html, text), do: length(String.split(html, text)) - 1

  describe "whoever runs the workshop" do
    test "reaches the panel through a single link", ctx do
      {:ok, _lv, html} = open(ctx.conn, ctx.organizer, ctx.workshop)

      assert occurrences(html, "Gerenciar inscritos") == 1
    end
  end

  describe "whoever is in the class" do
    test "is told so once, and cancelling is right beside it", ctx do
      {:ok, _} = Workshops.enroll(ctx.workshop, ctx.student)
      {:ok, _lv, html} = open(ctx.conn, ctx.student, ctx.workshop)

      assert occurrences(html, "Você está inscrito") == 1
      assert html =~ "cancel_enrollment"
    end
  end

  describe "a step already learned" do
    test "carries a check and not a colour scheme of its own", ctx do
      step = insert(:step, code: "IV", name: "Inversão")
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.organizer, step.id)

      {:ok, _lv, html} = open(ctx.conn, ctx.organizer, ctx.workshop)

      assert html =~ "IV"
      refute html =~ "border-accent-orange/25"
    end
  end

  describe "the practical side" do
    test "price, date and place read without the eyebrow treatment", ctx do
      {:ok, _lv, html} = open(ctx.conn, ctx.student, ctx.workshop)

      assert html =~ "R$ 50"
      assert html =~ "Telhado do Tatá"
      refute html =~ "border-l-accent-green"
    end
  end
end
