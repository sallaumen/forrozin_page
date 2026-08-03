defmodule OGrupoDeEstudosWeb.ProfileWorkshopsTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.{Brazil, Workshops}

  defp em(dias, hora \\ 19) do
    Brazil.today()
    |> Date.add(dias)
    |> DateTime.new!(Time.new!(hora, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  setup do
    %{dono: insert(:user), aluna: insert(:user)}
  end

  describe "próximos workshops no perfil" do
    test "mostra os que estão por vir, do mais próximo primeiro", ctx do
      depois = insert(:workshop, organizer: ctx.dono, title: "Mais tarde", starts_at: em(20))
      antes = insert(:workshop, organizer: ctx.dono, title: "Bem perto", starts_at: em(2))
      for w <- [depois, antes], do: Workshops.enroll(w, ctx.aluna)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.aluna), ~p"/users/#{ctx.aluna.username}")

      assert html =~ "Próximos workshops"
      assert html =~ "Bem perto"
      assert html =~ "Mais tarde"
      # O mais proximo vem primeiro na ordem do HTML.
      assert :binary.match(html, "Bem perto") < :binary.match(html, "Mais tarde")
    end

    test "workshop que já passou não aparece", ctx do
      passado = insert(:workshop, organizer: ctx.dono, title: "Já foi", starts_at: em(-10))
      {:ok, _} = Workshops.enroll(passado, ctx.aluna)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.aluna), ~p"/users/#{ctx.aluna.username}")

      refute html =~ "Já foi"
      assert html =~ "não está inscrito em nenhum workshop"
    end

    test "workshop rolando agora ainda conta", ctx do
      rolando =
        insert(:workshop,
          organizer: ctx.dono,
          title: "Acontecendo agora",
          starts_at:
            DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:second),
          ends_at: DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.truncate(:second)
        )

      {:ok, _} = Workshops.enroll(rolando, ctx.aluna)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.aluna), ~p"/users/#{ctx.aluna.username}")

      assert html =~ "Acontecendo agora"
    end

    test "mostra no máximo três, e diz quantos faltam", ctx do
      for i <- 1..5 do
        w = insert(:workshop, organizer: ctx.dono, title: "Workshop #{i}", starts_at: em(i))
        Workshops.enroll(w, ctx.aluna)
      end

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.aluna), ~p"/users/#{ctx.aluna.username}")

      assert html =~ "Workshop 3"
      refute html =~ "Workshop 4"
      assert html =~ "E mais 2 depois desses"
    end

    test "estado vazio convida para a agenda", ctx do
      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.aluna), ~p"/users/#{ctx.aluna.username}")

      assert html =~ "não está inscrito em nenhum workshop"
      assert html =~ "Ver a agenda"
    end

    test "a agenda de outra pessoa não é publicada no perfil dela", ctx do
      w = insert(:workshop, organizer: ctx.dono, title: "Onde ela vai estar", starts_at: em(3))
      {:ok, _} = Workshops.enroll(w, ctx.aluna)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/users/#{ctx.aluna.username}")

      # Saber onde alguem vai estar fisicamente e exposicao nova.
      refute html =~ "Onde ela vai estar"
      refute html =~ "Próximos workshops"
    end

    test "workshop em rascunho não conta", ctx do
      rascunho =
        insert(:workshop, organizer: ctx.dono, title: "Segredo", status: :draft, starts_at: em(5))

      OGrupoDeEstudos.Repo.insert!(%OGrupoDeEstudos.Workshops.WorkshopEnrollment{
        workshop_id: rascunho.id,
        user_id: ctx.aluna.id
      })

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.aluna), ~p"/users/#{ctx.aluna.username}")

      refute html =~ "Segredo"
    end
  end
end
