defmodule OGrupoDeEstudosWeb.WorkshopTeachersTest do
  @moduledoc """
  Quem dá a aula aparece com rosto.

  Nome solto no meio de uma linha de metadados não divulga ninguém. Com foto e
  link para o perfil, o workshop apresenta o professor, que é metade do motivo
  de alguém se inscrever.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Brazil, Workshops}

  defp em(dias) do
    Brazil.today()
    |> Date.add(dias)
    |> DateTime.new!(Time.new!(14, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp publicado(organizer) do
    {:ok, w} =
      Workshops.create_workshop(organizer, %{
        title: "Workshop de pisada",
        description: "Conteúdo.",
        location: "Curitiba",
        starts_at: em(7)
      })

    {:ok, w} = Workshops.publish_workshop(organizer, w)
    w
  end

  describe "na página do workshop" do
    test "quem dá a aula aparece com foto, nome e @", %{conn: conn} do
      dono = insert(:user, name: "Tavano Silva", avatar_path: "/uploads/avatars/t/1.jpg")
      workshop = publicado(dono)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      assert html =~ "Quem dá a aula"
      assert html =~ "/uploads/avatars/t/1.jpg"
      assert html =~ "Tavano Silva"
      assert html =~ "@#{dono.username}"
    end

    test "sem foto, a inicial no lugar, nunca uma imagem quebrada", %{conn: conn} do
      dono = insert(:user, name: "Joana Ribeiro", avatar_path: nil)
      workshop = publicado(dono)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      assert html =~ "Joana Ribeiro"
      refute html =~ ~s|src=""|
    end

    test "co-organizador também é professor da turma", %{conn: conn} do
      dono = insert(:user, name: "Tavano Silva")
      parceira = insert(:user, name: "Marina Costa", avatar_path: "/uploads/avatars/m/2.jpg")
      workshop = publicado(dono)
      {:ok, _} = Workshops.add_admin(workshop, dono, parceira.id)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      assert html =~ "Marina Costa"
      assert html =~ "/uploads/avatars/m/2.jpg"
    end

    test "o rosto leva ao perfil, que é o ponto de divulgar o professor", %{conn: conn} do
      dono = insert(:user, name: "Tavano Silva")
      workshop = publicado(dono)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      assert html =~ ~s|href="/users/#{dono.username}"|
    end
  end

  describe "o avatar precisa poder morar dentro de um parágrafo" do
    test "sem foto, a inicial sai em <span>, nunca em <div>" do
      # <div> dentro de <p> é inválido: o navegador fecha o parágrafo sozinho
      # e joga o resto para fora. Com foto o avatar é <img> e passa; sem foto,
      # um <div> arrebentaria a linha de metadados do card, e só na tela (o
      # teste de string não vê, porque o HTML só quebra na hora de parsear).
      html =
        Phoenix.LiveViewTest.render_component(&OGrupoDeEstudosWeb.UI.UserAvatar.user_avatar/1, %{
          user: %{name: "Sem Foto", username: "semfoto", avatar_path: nil},
          size: :xs
        })

      assert html =~ "<span"
      refute html =~ "<div"
    end
  end

  describe "no card da agenda" do
    test "o rosto de quem dá a aula vem junto do nome", %{conn: conn} do
      dono = insert(:user, name: "Tavano Silva", avatar_path: "/uploads/avatars/t/9.jpg")
      publicado(dono)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")

      assert html =~ "/uploads/avatars/t/9.jpg"
      assert html =~ "Tavano Silva"
    end
  end
end
