defmodule OGrupoDeEstudosWeb.WorkshopCreationAccessTest do
  @moduledoc """
  Organizing an event is the teaching side of the app.

  The agenda is read by everyone, so offering "create a workshop" to every student
  clutters the page for the majority who will never open a class. Whoever already
  organizes one keeps managing it: that is a different question.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Brazil, Workshops}

  defp at_day(days) do
    Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(Time.new!(14, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp published(organizer) do
    {:ok, workshop} =
      Workshops.create_workshop(organizer, %{
        title: "Workshop de sacadas",
        description: "Conteúdo do workshop.",
        location: "Curitiba",
        starts_at: at_day(7)
      })

    {:ok, workshop} = Workshops.publish_workshop(organizer, workshop)
    workshop
  end

  describe "the agenda page" do
    test "whoever teaches gets both ways to create", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)

      {:ok, _lv, html} = live(log_in_user(conn, teacher), ~p"/study/workshops")

      assert html =~ "Criar workshop"
      assert html =~ "Juntar num link só"
    end

    test "a site admin gets them too", %{conn: conn} do
      {:ok, _lv, html} = live(log_in_user(conn, insert(:admin)), ~p"/study/workshops")

      assert html =~ "Criar workshop"
    end

    test "whoever only studies reads the agenda without the invitation to create",
         %{conn: conn} do
      student = insert(:user, is_teacher: false)

      {:ok, _lv, html} = live(log_in_user(conn, student), ~p"/study/workshops")

      assert html =~ "Agenda da comunidade"
      refute html =~ "Criar workshop"
      refute html =~ "Juntar num link só"
    end

    test "the empty agenda reads as information, not as a call to create",
         %{conn: conn} do
      student = insert(:user, is_teacher: false)

      {:ok, _lv, html} = live(log_in_user(conn, student), ~p"/study/workshops")

      assert html =~ "Nada marcado por aqui ainda"
      refute html =~ "Criar o primeiro"
    end
  end

  describe "reaching the form by the address bar" do
    test "whoever teaches opens it", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)

      {:ok, _lv, html} = live(log_in_user(conn, teacher), ~p"/study/workshops/new")

      assert html =~ "Novo workshop"
    end

    test "whoever only studies is sent back to the agenda", %{conn: conn} do
      student = insert(:user, is_teacher: false)

      assert {:error, {:redirect, %{to: "/study/workshops"}}} =
               live(log_in_user(conn, student), ~p"/study/workshops/new")
    end

    test "the program form answers the same way", %{conn: conn} do
      student = insert(:user, is_teacher: false)

      assert {:error, {:redirect, %{to: "/study/workshops"}}} =
               live(log_in_user(conn, student), ~p"/study/programs/new")
    end
  end

  describe "what whoever already organizes keeps" do
    test "a workshop created before the rule stays manageable by its organizer",
         %{conn: conn} do
      organizer = insert(:user, is_teacher: false)
      workshop = published(organizer)

      {:ok, _lv, html} =
        live(log_in_user(conn, organizer), ~p"/study/workshops/#{workshop.slug}/edit")

      assert html =~ "Editar workshop"
    end
  end
end
