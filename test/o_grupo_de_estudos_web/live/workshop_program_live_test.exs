defmodule OGrupoDeEstudosWeb.WorkshopProgramLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.{Brazil, Workshops}

  defp at_day(days, hour) do
    Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(Time.new!(hour, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp published_program(owner, workshops) do
    {:ok, program} = Workshops.create_program(owner, %{title: "Fim de semana de forró"})
    for w <- workshops, do: Workshops.attach_workshop(program, owner, w.id)
    {:ok, program} = Workshops.publish_program(owner, program)
    program
  end

  setup do
    owner = insert(:user, name: "Tavano")

    thursday =
      insert(:workshop,
        organizer: owner,
        title: "Básico e intermediário",
        starts_at: at_day(7, 19)
      )

    friday = insert(:workshop, organizer: owner, title: "Avançado", starts_at: at_day(8, 19))

    %{
      owner: owner,
      thursday: thursday,
      friday: friday,
      program: published_program(owner, [thursday, friday])
    }
  end

  describe "public program page" do
    test "anonymous visitor opens it and sees both workshops", ctx do
      {:ok, _lv, html} = live(build_conn(), ~p"/programs/#{ctx.program.slug}")

      assert html =~ "Fim de semana de forró"
      assert html =~ "Básico e intermediário"
      assert html =~ "Avançado"
      assert html =~ "2 workshops"
    end

    test "groups by day, with the weekday spelled out", ctx do
      {:ok, _lv, html} = live(build_conn(), ~p"/programs/#{ctx.program.slug}")

      thursday_date = ctx.thursday.starts_at |> Brazil.to_local() |> DateTime.to_date()
      assert html =~ Brazil.strftime(thursday_date, "%A, %d de %B")

      friday_date = ctx.friday.starts_at |> Brazil.to_local() |> DateTime.to_date()
      assert html =~ Brazil.strftime(friday_date, "%A, %d de %B")
    end

    test "enrolled user sees the mark on the card", ctx do
      student = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.thursday, student)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), student), ~p"/programs/#{ctx.program.slug}")

      assert html =~ "Você está inscrito"
    end

    test "draft does not leak through the link", %{owner: owner} do
      {:ok, draft} = Workshops.create_program(owner, %{title: "Ainda montando"})

      assert {:error, {:redirect, %{to: destination}}} =
               live(build_conn(), ~p"/programs/#{draft.slug}")

      assert destination == ~p"/study/workshops"
    end

    test "creator opens their own draft and can publish it", %{owner: owner} do
      {:ok, draft} = Workshops.create_program(owner, %{title: "Ainda montando"})

      {:ok, lv, html} = live(log_in_user(build_conn(), owner), ~p"/programs/#{draft.slug}")
      assert html =~ "Ainda é rascunho"

      html = render_click(lv, "publish", %{})
      assert html =~ "publicada"
      assert Workshops.get_program(draft.id).status == :published
    end

    test "draft workshop stays out for plain visitors", ctx do
      draft = insert(:workshop, organizer: ctx.owner, title: "Segredo", status: :draft)
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.owner, draft.id)

      {:ok, _lv, html} = live(build_conn(), ~p"/programs/#{ctx.program.slug}")
      refute html =~ "Segredo"

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.owner), ~p"/programs/#{ctx.program.slug}")

      assert html =~ "Segredo"
    end

    test "empty program explains what to do", %{owner: owner} do
      {:ok, vazia} = Workshops.create_program(owner, %{title: "Sem nada ainda"})
      {:ok, vazia} = Workshops.publish_program(owner, vazia)

      {:ok, _lv, html} = live(build_conn(), ~p"/programs/#{vazia.slug}")

      assert html =~ "Nenhum workshop nesta programação ainda"
    end
  end

  describe "package alongside single enrollment" do
    setup ctx do
      {:ok, com_pacote} =
        Workshops.create_program(ctx.owner, %{
          title: "Três dias",
          price_cents: 15_000,
          payment_info: "Pix do festival: 41 98888-7777"
        })

      for w <- [ctx.thursday, ctx.friday],
          do: Workshops.attach_workshop(com_pacote, ctx.owner, w.id)

      {:ok, com_pacote} = Workshops.publish_program(ctx.owner, com_pacote)
      Map.put(ctx, :com_pacote, com_pacote)
    end

    test "page offers both options and shows the savings", ctx do
      {:ok, _lv, html} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/programs/#{ctx.com_pacote.slug}")

      assert html =~ "pela programação toda"
      assert html =~ "Quero a programação toda"
      assert html =~ "Ou escolha os dias"
      assert html =~ "cada um pelo preço dele"
    end

    test "buying the package enrolls in every workshop at once", ctx do
      student = insert(:user)

      {:ok, lv, _} =
        live(log_in_user(build_conn(), student), ~p"/programs/#{ctx.com_pacote.slug}")

      html = render_click(lv, "buy_package", %{})

      assert html =~ "Você tem a programação toda"
      enrolled_ids = Workshops.enrolled_workshop_ids(student.id)
      assert MapSet.member?(enrolled_ids, ctx.thursday.id)
      assert MapSet.member?(enrolled_ids, ctx.friday.id)
    end

    test "Pix key stays hidden from whoever has not bought the package", ctx do
      {:ok, _lv, html} = live(build_conn(), ~p"/programs/#{ctx.com_pacote.slug}")

      refute html =~ "41 98888-7777"
    end

    test "Pix key appears after buying the package", ctx do
      student = insert(:user)

      {:ok, lv, _} =
        live(log_in_user(build_conn(), student), ~p"/programs/#{ctx.com_pacote.slug}")

      html = render_click(lv, "buy_package", %{})

      assert html =~ "41 98888-7777"
    end

    test "program without a package price shows no package", ctx do
      {:ok, _lv, html} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/programs/#{ctx.program.slug}")

      refute html =~ "Quero a programação toda"
    end

    test "anonymous visitor is sent to signup", ctx do
      {:ok, lv, _} = live(build_conn(), ~p"/programs/#{ctx.com_pacote.slug}")

      assert {:error, {:redirect, %{to: destination}}} = render_click(lv, "buy_package", %{})
      assert destination =~ "/signup"
    end

    test "full class removes the package and explains, keeping single enrollment", ctx do
      {:ok, full_workshop} = Workshops.update_workshop(ctx.owner, ctx.friday, %{capacity: 1})
      {:ok, _} = Workshops.enroll(full_workshop, insert(:user))

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/programs/#{ctx.com_pacote.slug}")

      refute html =~ "Quero a programação toda"
      assert html =~ "lotou, então o pacote fechado não dá"
      assert html =~ "Confirmar inscrição"
    end

    test "creator sees the package dashboard and marks as paid", ctx do
      student = insert(:user)
      {:ok, _} = Workshops.enroll_in_package(ctx.com_pacote, student)

      {:ok, lv, html} =
        live(log_in_user(build_conn(), ctx.owner), ~p"/programs/#{ctx.com_pacote.slug}")

      assert html =~ "Quem levou a programação toda"
      assert html =~ student.name

      {:ok, [row]} = Workshops.list_package_enrollments(ctx.com_pacote, ctx.owner)
      html = render_click(lv, "set_package_payment", %{"id" => row.id, "status" => "paid"})

      assert html =~ "R$ 150"
    end

    test "non-creator does not see the package dashboard", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.com_pacote, insert(:user))

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/programs/#{ctx.com_pacote.slug}")

      refute html =~ "Quem levou a programação toda"
    end
  end

  describe "batch enrollment through the checklist" do
    test "checks both and confirms at once", ctx do
      student = insert(:user)

      {:ok, lv, html} =
        live(log_in_user(build_conn(), student), ~p"/programs/#{ctx.program.slug}")

      assert html =~ "Marque os workshops que você vai"

      render_click(lv, "toggle_selection", %{"id" => ctx.thursday.id})
      html = render_click(lv, "toggle_selection", %{"id" => ctx.friday.id})
      assert html =~ "2 workshops marcados"

      html = render_click(lv, "confirm_enrollment", %{})

      assert html =~ "2 inscrições confirmadas"
      enrolled_ids = Workshops.enrolled_workshop_ids(student.id)
      assert MapSet.member?(enrolled_ids, ctx.thursday.id)
      assert MapSet.member?(enrolled_ids, ctx.friday.id)
    end

    test "unchecking removes from the count without unenrolling anyone", ctx do
      student = insert(:user)

      {:ok, lv, _} =
        live(log_in_user(build_conn(), student), ~p"/programs/#{ctx.program.slug}")

      render_click(lv, "toggle_selection", %{"id" => ctx.thursday.id})
      html = render_click(lv, "toggle_selection", %{"id" => ctx.thursday.id})

      assert html =~ "Marque os workshops que você vai"
      assert Workshops.enrolled_workshop_ids(student.id) |> MapSet.size() == 0
    end

    test "confirming with nothing checked warns instead of pretending it worked", ctx do
      {:ok, lv, _} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/programs/#{ctx.program.slug}")

      html = render_click(lv, "confirm_enrollment", %{})

      assert html =~ "Marque pelo menos um workshop"
    end

    test "one full workshop in the middle: the others go in and the message names what failed",
         ctx do
      full_workshop =
        insert(:workshop,
          organizer: ctx.owner,
          title: "Lotado demais",
          capacity: 1,
          starts_at: at_day(9, 19)
        )

      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.owner, full_workshop.id)
      {:ok, _} = Workshops.enroll(full_workshop, insert(:user))

      student = insert(:user)

      {:ok, lv, _} =
        live(log_in_user(build_conn(), student), ~p"/programs/#{ctx.program.slug}")

      render_click(lv, "toggle_selection", %{"id" => full_workshop.id})
      render_click(lv, "toggle_selection", %{"id" => ctx.thursday.id})
      html = render_click(lv, "confirm_enrollment", %{})

      assert html =~ "1 inscrição confirmada"
      assert MapSet.member?(Workshops.enrolled_workshop_ids(student.id), ctx.thursday.id)
    end

    test "already enrolled user sees the mark instead of the checkbox", ctx do
      student = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.thursday, student)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), student), ~p"/programs/#{ctx.program.slug}")

      refute html =~ ~s(id="pick-#{ctx.thursday.id}")
      assert html =~ ~s(id="pick-#{ctx.friday.id}")
    end

    test "organizer gets no checklist for their own workshops", ctx do
      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.owner), ~p"/programs/#{ctx.program.slug}")

      refute html =~ ~s(id="pick-#{ctx.thursday.id}")
    end

    test "anonymous visitor is sent to signup instead of crashing", ctx do
      {:ok, lv, _} = live(build_conn(), ~p"/programs/#{ctx.program.slug}")

      assert {:error, {:redirect, %{to: destination}}} =
               render_click(lv, "confirm_enrollment", %{})

      assert destination =~ "/signup"
    end

    test "forged id does not enter the selection", ctx do
      student = insert(:user)
      alheio = insert(:workshop)

      {:ok, lv, _} =
        live(log_in_user(build_conn(), student), ~p"/programs/#{ctx.program.slug}")

      html = render_click(lv, "toggle_selection", %{"id" => alheio.id})

      assert html =~ "Marque os workshops que você vai"
    end
  end

  describe "building the program without leaving the page" do
    test "organizer attaches a loose workshop on the spot", ctx do
      improvised = insert(:workshop, organizer: ctx.owner, title: "Roda improvisada")

      {:ok, lv, html} =
        live(log_in_user(build_conn(), ctx.owner), ~p"/programs/#{ctx.program.slug}")

      assert html =~ "Roda improvisada"

      render_click(lv, "attach_workshop", %{"id" => improvised.id})

      ids = ctx.program |> Workshops.list_program_workshops() |> Enum.map(& &1.id)
      assert improvised.id in ids
    end

    test "organizer detaches one on the spot", ctx do
      {:ok, lv, _} =
        live(log_in_user(build_conn(), ctx.owner), ~p"/programs/#{ctx.program.slug}")

      render_click(lv, "detach_workshop", %{"id" => ctx.friday.id})

      assert [restante] = Workshops.list_program_workshops(ctx.program)
      assert restante.id == ctx.thursday.id
      assert Workshops.get_workshop(ctx.friday.id)
    end

    test "non-organizer sees no panel and cannot change anything", ctx do
      outsider = insert(:user)
      workshop_dele = insert(:workshop, organizer: outsider)

      {:ok, lv, html} =
        live(log_in_user(build_conn(), outsider), ~p"/programs/#{ctx.program.slug}")

      refute html =~ "Montar a programação"

      render_click(lv, "attach_workshop", %{"id" => workshop_dele.id})
      render_click(lv, "detach_workshop", %{"id" => ctx.thursday.id})

      assert length(Workshops.list_program_workshops(ctx.program)) == 2
    end

    test "anonymous visitor sending the event does not crash the page", ctx do
      {:ok, lv, _} = live(build_conn(), ~p"/programs/#{ctx.program.slug}")

      render_click(lv, "attach_workshop", %{"id" => ctx.thursday.id})
      render_click(lv, "detach_workshop", %{"id" => ctx.thursday.id})

      assert render(lv) =~ ctx.program.title
      assert length(Workshops.list_program_workshops(ctx.program)) == 2
    end

    test "made-up id breaks nothing", ctx do
      {:ok, lv, _} =
        live(log_in_user(build_conn(), ctx.owner), ~p"/programs/#{ctx.program.slug}")

      render_click(lv, "attach_workshop", %{"id" => "nao-e-uuid"})

      assert render(lv) =~ ctx.program.title
    end

    test "panel only offers workshops that are not inside yet", ctx do
      fora = insert(:workshop, organizer: ctx.owner, title: "Ainda fora da programação")

      {:ok, lv, html} =
        live(log_in_user(build_conn(), ctx.owner), ~p"/programs/#{ctx.program.slug}")

      assert html =~ "Ainda fora da programação"

      html = render_click(lv, "attach_workshop", %{"id" => fora.id})

      assert html =~ "Tirar"
    end
  end

  describe "creating a workshop already inside the program" do
    test "form knows which program the workshop will join", ctx do
      {:ok, _lv, html} =
        live(
          log_in_user(build_conn(), ctx.owner),
          ~p"/study/workshops/new?#{[program: ctx.program.slug]}"
        )

      assert html =~ ctx.program.title
    end

    test "saving puts the workshop straight inside", ctx do
      {:ok, lv, _} =
        live(
          log_in_user(build_conn(), ctx.owner),
          ~p"/study/workshops/new?#{[program: ctx.program.slug]}"
        )

      lv
      |> form("#workshop-form", %{
        "workshop" => %{
          "title" => "Roda improvisada",
          "description" => "Surgiu na hora.",
          "starts_at" => "2026-12-20T22:00"
        }
      })
      |> render_submit(%{"publish" => "true"})

      titulos = ctx.program |> Workshops.list_program_workshops() |> Enum.map(& &1.title)
      assert "Roda improvisada" in titulos
    end

    test "someone else's program is ignored and the workshop is born loose", ctx do
      alheia = ctx.program
      other = insert(:user)

      {:ok, lv, _} =
        live(
          log_in_user(build_conn(), other),
          ~p"/study/workshops/new?#{[program: alheia.slug]}"
        )

      lv
      |> form("#workshop-form", %{
        "workshop" => %{
          "title" => "Tentando entrar",
          "description" => "Sem permissão.",
          "starts_at" => "2026-12-20T22:00"
        }
      })
      |> render_submit(%{"publish" => "true"})

      titulos = alheia |> Workshops.list_program_workshops() |> Enum.map(& &1.title)
      refute "Tentando entrar" in titulos
    end
  end

  describe "creating and editing a program" do
    test "creates it picking the workshops at once", %{
      owner: owner,
      thursday: thursday,
      friday: friday
    } do
      {:ok, lv, _} = live(log_in_user(build_conn(), owner), ~p"/study/programs/new")

      render_click(lv, "toggle_workshop", %{"id" => thursday.id})
      render_click(lv, "toggle_workshop", %{"id" => friday.id})

      assert {:error, {:redirect, %{to: destination}}} =
               lv
               |> form("#program-form", %{
                 "program" => %{"title" => "Meu fim de semana", "description" => "Dois dias."}
               })
               |> render_submit()

      assert destination =~ "/programs/meu-fim-de-semana-"

      new_program =
        Enum.find(Workshops.list_programs_for_owner(owner.id), &(&1.title == "Meu fim de semana"))

      assert length(Workshops.list_program_workshops(new_program)) == 2
    end

    test "only lists workshops the user administers", %{owner: owner} do
      alheio = insert(:workshop, title: "Workshop de outra pessoa")

      {:ok, _lv, html} = live(log_in_user(build_conn(), owner), ~p"/study/programs/new")

      refute html =~ alheio.title
    end

    test "unchecking releases the workshop from the program", ctx do
      {:ok, lv, _} =
        live(
          log_in_user(build_conn(), ctx.owner),
          ~p"/study/programs/#{ctx.program.slug}/edit"
        )

      render_click(lv, "toggle_workshop", %{"id" => ctx.friday.id})

      lv
      |> form("#program-form", %{"program" => %{"title" => ctx.program.title}})
      |> render_submit()

      assert [restante] = Workshops.list_program_workshops(ctx.program)
      assert restante.id == ctx.thursday.id
    end

    test "outsider does not edit someone else's program", ctx do
      assert {:error, {:redirect, _}} =
               live(
                 log_in_user(build_conn(), insert(:user)),
                 ~p"/study/programs/#{ctx.program.slug}/edit"
               )
    end

    test "empty title shows an error instead of creating", %{owner: owner} do
      {:ok, lv, _} = live(log_in_user(build_conn(), owner), ~p"/study/programs/new")

      html =
        lv
        |> form("#program-form", %{"program" => %{"title" => "", "description" => "algo"}})
        |> render_submit()

      assert html =~ "Título"
      assert Workshops.list_programs_for_owner(owner.id) |> Enum.all?(&(&1.title != ""))
      assert length(Workshops.list_programs_for_owner(owner.id)) == 1
    end
  end
end
