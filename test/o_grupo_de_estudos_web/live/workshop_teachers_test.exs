defmodule OGrupoDeEstudosWeb.WorkshopTeachersTest do
  @moduledoc """
  Teachers are shown with photo and profile link, since the teacher is half
  the reason someone enrolls.
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
    {:ok, w} =
      Workshops.create_workshop(organizer, %{
        title: "Workshop de pisada",
        description: "Conteúdo.",
        location: "Curitiba",
        starts_at: at_day(7)
      })

    {:ok, w} = Workshops.publish_workshop(organizer, w)
    w
  end

  describe "on the workshop page" do
    test "teacher shows up with photo, name and handle", %{conn: conn} do
      owner = insert(:user, name: "Tavano Silva", avatar_path: "/uploads/avatars/t/1.jpg")
      workshop = published(owner)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      assert html =~ "Quem dá a aula"
      assert html =~ "/uploads/avatars/t/1.jpg"
      assert html =~ "Tavano Silva"
      assert html =~ "@#{owner.username}"
    end

    test "without a photo the initial takes its place, never a broken image", %{conn: conn} do
      owner = insert(:user, name: "Joana Ribeiro", avatar_path: nil)
      workshop = published(owner)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      assert html =~ "Joana Ribeiro"
      refute html =~ ~s|src=""|
    end

    test "co-organizer does not become a teacher automatically", %{conn: conn} do
      owner = insert(:user, name: "Tavano Silva")
      partner = insert(:user, name: "Marina Costa")
      workshop = published(owner)
      {:ok, _} = Workshops.add_admin(workshop, owner, partner.id)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      refute html =~ "Marina Costa"
    end

    test "chosen teacher shows up even without organizing", %{conn: conn} do
      owner = insert(:user, name: "Produtor do Evento")
      teacher = insert(:user, name: "Marina Costa", avatar_path: "/uploads/avatars/m/2.jpg")
      workshop = published(owner)
      {:ok, _} = Workshops.set_teachers(workshop, owner, [%{user_id: teacher.id}])

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      assert html =~ "Marina Costa"
      assert html =~ "/uploads/avatars/m/2.jpg"
      refute html =~ "Produtor do Evento"
    end

    test "teacher without an account shows up as a name, with no broken link", %{conn: conn} do
      owner = insert(:user)
      workshop = published(owner)
      {:ok, _} = Workshops.set_teachers(workshop, owner, [%{display_name: "Zé de Itaúnas"}])

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      assert html =~ "Zé de Itaúnas"
      refute html =~ ~s|href="/users/"|
    end

    test "the face links to the profile, which is the point of featuring the teacher", %{
      conn: conn
    } do
      owner = insert(:user, name: "Tavano Silva")
      workshop = published(owner)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      assert html =~ ~s|href="/users/#{owner.username}"|
    end
  end

  describe "the avatar has to live inside a paragraph" do
    test "without a photo the initial renders in a span, never in a div" do
      html =
        Phoenix.LiveViewTest.render_component(&OGrupoDeEstudosWeb.UI.UserAvatar.user_avatar/1, %{
          user: %{name: "Sem Foto", username: "semfoto", avatar_path: nil},
          size: :xs
        })

      assert html =~ "<span"
      refute html =~ "<div"
    end
  end

  describe "on the agenda card" do
    test "the teacher face comes next to the name", %{conn: conn} do
      owner = insert(:user, name: "Tavano Silva", avatar_path: "/uploads/avatars/t/9.jpg")
      published(owner)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")

      assert html =~ "/uploads/avatars/t/9.jpg"
      assert html =~ "Tavano Silva"
    end
  end
end
