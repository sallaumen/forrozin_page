defmodule OGrupoDeEstudosWeb.ProfileWorkshopsTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.{Brazil, Workshops}

  defp at_day(days, hour \\ 19) do
    Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(Time.new!(hour, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  setup do
    %{owner: insert(:user), student: insert(:user)}
  end

  describe "upcoming workshops on the profile" do
    test "shows the upcoming ones, nearest first", ctx do
      later = insert(:workshop, organizer: ctx.owner, title: "Mais tarde", starts_at: at_day(20))
      earlier = insert(:workshop, organizer: ctx.owner, title: "Bem perto", starts_at: at_day(2))
      for w <- [later, earlier], do: Workshops.enroll(w, ctx.student)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.student), ~p"/users/#{ctx.student.username}")

      assert html =~ "Próximos workshops"
      assert html =~ "Bem perto"
      assert html =~ "Mais tarde"
      assert :binary.match(html, "Bem perto") < :binary.match(html, "Mais tarde")
    end

    test "workshop that already happened does not show up", ctx do
      past_workshop =
        insert(:workshop, organizer: ctx.owner, title: "Já foi", starts_at: at_day(-10))

      {:ok, _} = Workshops.enroll(past_workshop, ctx.student)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.student), ~p"/users/#{ctx.student.username}")

      refute html =~ "Já foi"
      assert html =~ "não está inscrito em nenhum workshop"
    end

    test "workshop happening right now still counts", ctx do
      happening_now =
        insert(:workshop,
          organizer: ctx.owner,
          title: "Acontecendo agora",
          starts_at:
            DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:second),
          ends_at: DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.truncate(:second)
        )

      {:ok, _} = Workshops.enroll(happening_now, ctx.student)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.student), ~p"/users/#{ctx.student.username}")

      assert html =~ "Acontecendo agora"
    end

    test "shows at most three and says how many are left", ctx do
      for i <- 1..5 do
        w = insert(:workshop, organizer: ctx.owner, title: "Workshop #{i}", starts_at: at_day(i))
        Workshops.enroll(w, ctx.student)
      end

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.student), ~p"/users/#{ctx.student.username}")

      assert html =~ "Workshop 3"
      refute html =~ "Workshop 4"
      assert html =~ "E mais 2 depois desses"
    end

    test "empty state invites the user to the agenda", ctx do
      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.student), ~p"/users/#{ctx.student.username}")

      assert html =~ "não está inscrito em nenhum workshop"
      assert html =~ "Ver a agenda"
    end

    test "another user's agenda is not published on their profile", ctx do
      w =
        insert(:workshop, organizer: ctx.owner, title: "Onde ela vai estar", starts_at: at_day(3))

      {:ok, _} = Workshops.enroll(w, ctx.student)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/users/#{ctx.student.username}")

      refute html =~ "Onde ela vai estar"
      refute html =~ "Próximos workshops"
    end

    test "draft workshop does not count", ctx do
      draft =
        insert(:workshop,
          organizer: ctx.owner,
          title: "Segredo",
          status: :draft,
          starts_at: at_day(5)
        )

      OGrupoDeEstudos.Repo.insert!(%OGrupoDeEstudos.Workshops.WorkshopEnrollment{
        workshop_id: draft.id,
        user_id: ctx.student.id
      })

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.student), ~p"/users/#{ctx.student.username}")

      refute html =~ "Segredo"
    end
  end
end
