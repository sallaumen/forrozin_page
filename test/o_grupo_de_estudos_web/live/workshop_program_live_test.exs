defmodule OGrupoDeEstudosWeb.WorkshopProgramLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.{Brazil, Workshops}

  defp em(dias, hora) do
    Brazil.today()
    |> Date.add(dias)
    |> DateTime.new!(Time.new!(hora, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp programacao_publicada(dono, workshops) do
    {:ok, program} = Workshops.create_program(dono, %{title: "Fim de semana de forró"})
    for w <- workshops, do: Workshops.attach_workshop(program, dono, w.id)
    {:ok, program} = Workshops.publish_program(dono, program)
    program
  end

  setup do
    dono = insert(:user, name: "Tavano")

    quinta =
      insert(:workshop, organizer: dono, title: "Básico e intermediário", starts_at: em(7, 19))

    sexta = insert(:workshop, organizer: dono, title: "Avançado", starts_at: em(8, 19))

    %{
      dono: dono,
      quinta: quinta,
      sexta: sexta,
      program: programacao_publicada(dono, [quinta, sexta])
    }
  end

  describe "página pública da programação" do
    test "visitante sem conta abre e vê os dois workshops", ctx do
      {:ok, _lv, html} = live(build_conn(), ~p"/programacao/#{ctx.program.slug}")

      assert html =~ "Fim de semana de forró"
      assert html =~ "Básico e intermediário"
      assert html =~ "Avançado"
      assert html =~ "2 workshops"
    end

    test "agrupa por dia, com o dia por extenso em português", ctx do
      {:ok, _lv, html} = live(build_conn(), ~p"/programacao/#{ctx.program.slug}")

      dia_quinta = ctx.quinta.starts_at |> Brazil.to_local() |> DateTime.to_date()
      assert html =~ Brazil.strftime(dia_quinta, "%A, %d de %B")

      dia_sexta = ctx.sexta.starts_at |> Brazil.to_local() |> DateTime.to_date()
      assert html =~ Brazil.strftime(dia_sexta, "%A, %d de %B")
    end

    test "quem já se inscreveu vê a marca no card", ctx do
      aluna = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.quinta, aluna)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), aluna), ~p"/programacao/#{ctx.program.slug}")

      assert html =~ "Você está inscrito"
    end

    test "rascunho não vaza pelo link", %{dono: dono} do
      {:ok, rascunho} = Workshops.create_program(dono, %{title: "Ainda montando"})

      assert {:error, {:redirect, %{to: destino}}} =
               live(build_conn(), ~p"/programacao/#{rascunho.slug}")

      assert destino == ~p"/study/workshops"
    end

    test "quem criou abre o próprio rascunho e consegue publicar", %{dono: dono} do
      {:ok, rascunho} = Workshops.create_program(dono, %{title: "Ainda montando"})

      {:ok, lv, html} = live(log_in_user(build_conn(), dono), ~p"/programacao/#{rascunho.slug}")
      assert html =~ "Ainda é rascunho"

      html = render_click(lv, "publish", %{})
      assert html =~ "publicada"
      assert Workshops.get_program(rascunho.id).status == :published
    end

    test "workshop em rascunho fica fora para quem só olha", ctx do
      rascunho = insert(:workshop, organizer: ctx.dono, title: "Segredo", status: :draft)
      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.dono, rascunho.id)

      {:ok, _lv, html} = live(build_conn(), ~p"/programacao/#{ctx.program.slug}")
      refute html =~ "Segredo"

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.dono), ~p"/programacao/#{ctx.program.slug}")

      assert html =~ "Segredo"
    end

    test "programação vazia explica o que fazer", %{dono: dono} do
      {:ok, vazia} = Workshops.create_program(dono, %{title: "Sem nada ainda"})
      {:ok, vazia} = Workshops.publish_program(dono, vazia)

      {:ok, _lv, html} = live(build_conn(), ~p"/programacao/#{vazia.slug}")

      assert html =~ "Nenhum workshop nesta programação ainda"
    end
  end

  describe "criar e editar programação" do
    test "cria escolhendo os workshops de uma vez", %{dono: dono, quinta: quinta, sexta: sexta} do
      {:ok, lv, _} = live(log_in_user(build_conn(), dono), ~p"/study/programacoes/nova")

      render_click(lv, "toggle_workshop", %{"id" => quinta.id})
      render_click(lv, "toggle_workshop", %{"id" => sexta.id})

      assert {:error, {:redirect, %{to: destino}}} =
               lv
               |> form("#program-form", %{
                 "program" => %{"title" => "Meu fim de semana", "description" => "Dois dias."}
               })
               |> render_submit()

      assert destino =~ "/programacao/meu-fim-de-semana-"

      nova =
        Enum.find(Workshops.list_programs_for_owner(dono.id), &(&1.title == "Meu fim de semana"))

      assert length(Workshops.list_program_workshops(nova)) == 2
    end

    test "só lista workshops que a pessoa administra", %{dono: dono} do
      alheio = insert(:workshop, title: "Workshop de outra pessoa")

      {:ok, _lv, html} = live(log_in_user(build_conn(), dono), ~p"/study/programacoes/nova")

      refute html =~ alheio.title
    end

    test "desmarcar solta o workshop da programação", ctx do
      {:ok, lv, _} =
        live(
          log_in_user(build_conn(), ctx.dono),
          ~p"/study/programacoes/#{ctx.program.slug}/editar"
        )

      render_click(lv, "toggle_workshop", %{"id" => ctx.sexta.id})

      lv
      |> form("#program-form", %{"program" => %{"title" => ctx.program.title}})
      |> render_submit()

      assert [restante] = Workshops.list_program_workshops(ctx.program)
      assert restante.id == ctx.quinta.id
    end

    test "estranho não edita programação alheia", ctx do
      assert {:error, {:redirect, _}} =
               live(
                 log_in_user(build_conn(), insert(:user)),
                 ~p"/study/programacoes/#{ctx.program.slug}/editar"
               )
    end

    test "título vazio mostra erro em vez de criar", %{dono: dono} do
      {:ok, lv, _} = live(log_in_user(build_conn(), dono), ~p"/study/programacoes/nova")

      html =
        lv
        |> form("#program-form", %{"program" => %{"title" => "", "description" => "algo"}})
        |> render_submit()

      assert html =~ "Título"
      # A do setup continua lá; o que não pode é ter nascido uma sem título.
      assert Workshops.list_programs_for_owner(dono.id) |> Enum.all?(&(&1.title != ""))
      assert length(Workshops.list_programs_for_owner(dono.id)) == 1
    end
  end
end
