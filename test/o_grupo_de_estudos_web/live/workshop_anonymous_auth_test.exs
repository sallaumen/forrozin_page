defmodule OGrupoDeEstudosWeb.WorkshopAnonymousAuthTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import OGrupoDeEstudos.Factory
  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Brazil, Workshops}

  defp at_day(days, hour) do
    Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(Time.new!(hour, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  setup do
    owner = insert(:user, name: "Tavano Professor")
    workshop = insert(:workshop, organizer: owner, starts_at: at_day(7, 19))

    %{owner: owner, workshop: workshop}
  end

  describe "anonymous visitor enrolling" do
    test "sends to login keeping the workshop as destination", ctx do
      {:ok, lv, _html} = live(build_conn(), ~p"/workshops/#{ctx.workshop.slug}")

      assert {:error, {:redirect, %{to: destination}}} =
               lv |> element("button", "Fazer inscrição") |> render_click()

      assert destination =~ "/login"
      assert destination =~ "return_to=%2Fworkshops%2F#{ctx.workshop.slug}"
    end

    test "login page offers google carrying the workshop destination", ctx do
      conn = get(build_conn(), ~p"/login?return_to=/workshops/#{ctx.workshop.slug}")
      response = html_response(conn, 200)

      assert response =~ "Entrar com o Google"
      assert response =~ "return_to=%2Fworkshops%2F#{ctx.workshop.slug}"
    end

    test "logging in with a password lands back on the workshop", ctx do
      insert(:user, username: "aluna", password_hash: Argon2.hash_pwd_salt("senhasegura123"))

      conn =
        post(build_conn(), ~p"/login", %{
          "session" => %{
            "username" => "aluna",
            "password" => "senhasegura123",
            "return_to" => "/workshops/#{ctx.workshop.slug}"
          }
        })

      assert redirected_to(conn) == "/workshops/#{ctx.workshop.slug}"
    end

    test "the workshop page opens with the enrollment button after login", ctx do
      student = insert(:user)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), student), ~p"/workshops/#{ctx.workshop.slug}")

      assert html =~ "Fazer inscrição"
    end
  end

  describe "anonymous visitor joining the waitlist" do
    test "a full workshop offers the waitlist instead of a dead end", ctx do
      full_workshop =
        insert(:workshop, organizer: ctx.owner, capacity: 1, starts_at: at_day(7, 19))

      Workshops.enroll(full_workshop, insert(:user))

      {:ok, _lv, html} = live(build_conn(), ~p"/workshops/#{full_workshop.slug}")

      assert html =~ "Vagas esgotadas"
      assert html =~ "Entrar na lista de espera"
    end

    test "sends to login keeping the workshop as destination", ctx do
      full_workshop =
        insert(:workshop, organizer: ctx.owner, capacity: 1, starts_at: at_day(7, 19))

      Workshops.enroll(full_workshop, insert(:user))

      {:ok, lv, _html} = live(build_conn(), ~p"/workshops/#{full_workshop.slug}")

      assert {:error, {:redirect, %{to: destination}}} =
               lv |> element("button", "Entrar na lista de espera") |> render_click()

      assert destination =~ "/login"
      assert destination =~ "return_to=%2Fworkshops%2F#{full_workshop.slug}"
    end
  end

  describe "links on the public workshop page" do
    test "the header sign-in link keeps the workshop as destination", ctx do
      {:ok, _lv, html} = live(build_conn(), ~p"/workshops/#{ctx.workshop.slug}")

      assert html =~ "/login?return_to=%2Fworkshops%2F#{ctx.workshop.slug}"
    end

    test "the comment prompt sends to login, not signup", ctx do
      {:ok, _lv, html} = live(build_conn(), ~p"/workshops/#{ctx.workshop.slug}")

      refute html =~ "/signup?workshop="
    end
  end
end
