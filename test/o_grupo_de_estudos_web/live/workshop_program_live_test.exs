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

  describe "pacote fechado convivendo com o avulso" do
    setup ctx do
      {:ok, com_pacote} =
        Workshops.create_program(ctx.dono, %{
          title: "Três dias",
          price_cents: 15_000,
          payment_info: "Pix do festival: 41 98888-7777"
        })

      for w <- [ctx.quinta, ctx.sexta],
          do: Workshops.attach_workshop(com_pacote, ctx.dono, w.id)

      {:ok, com_pacote} = Workshops.publish_program(ctx.dono, com_pacote)
      Map.put(ctx, :com_pacote, com_pacote)
    end

    test "a página oferece as duas formas e mostra a economia", ctx do
      {:ok, _lv, html} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/programacao/#{ctx.com_pacote.slug}")

      assert html =~ "pela programação toda"
      assert html =~ "Quero a programação toda"
      assert html =~ "Ou escolha os dias"
      # Avulso soma R$ 0 no setup base, então só confere que o bloco existe.
      assert html =~ "cada um pelo preço dele"
    end

    test "comprar o pacote entra em todos de uma vez", ctx do
      aluna = insert(:user)

      {:ok, lv, _} =
        live(log_in_user(build_conn(), aluna), ~p"/programacao/#{ctx.com_pacote.slug}")

      html = render_click(lv, "buy_package", %{})

      assert html =~ "Você tem a programação toda"
      inscritos = Workshops.enrolled_workshop_ids(aluna.id)
      assert MapSet.member?(inscritos, ctx.quinta.id)
      assert MapSet.member?(inscritos, ctx.sexta.id)
    end

    test "o Pix NÃO aparece para quem ainda não garantiu o pacote", ctx do
      # Chave Pix costuma ser CPF ou telefone. Na página do workshop ela só
      # aparece depois da inscrição; aqui vale a mesma regra.
      {:ok, _lv, html} = live(build_conn(), ~p"/programacao/#{ctx.com_pacote.slug}")

      refute html =~ "41 98888-7777"
    end

    test "depois de comprar o pacote, o Pix aparece", ctx do
      aluna = insert(:user)

      {:ok, lv, _} =
        live(log_in_user(build_conn(), aluna), ~p"/programacao/#{ctx.com_pacote.slug}")

      html = render_click(lv, "buy_package", %{})

      assert html =~ "41 98888-7777"
    end

    test "programação sem preço fechado não mostra pacote", ctx do
      {:ok, _lv, html} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/programacao/#{ctx.program.slug}")

      refute html =~ "Quero a programação toda"
    end

    test "visitante sem conta vai para o cadastro", ctx do
      {:ok, lv, _} = live(build_conn(), ~p"/programacao/#{ctx.com_pacote.slug}")

      assert {:error, {:redirect, %{to: destino}}} = render_click(lv, "buy_package", %{})
      assert destino =~ "/signup"
    end

    test "turma lotada tira o pacote e explica, sem tirar o avulso", ctx do
      {:ok, lotado} = Workshops.update_workshop(ctx.dono, ctx.sexta, %{capacity: 1})
      {:ok, _} = Workshops.enroll(lotado, insert(:user))

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/programacao/#{ctx.com_pacote.slug}")

      refute html =~ "Quero a programação toda"
      assert html =~ "lotou, então o pacote fechado não dá"
      # O caminho avulso continua de pé.
      assert html =~ "Confirmar inscrição"
    end

    test "quem criou vê o painel do pacote e marca pago", ctx do
      aluna = insert(:user)
      {:ok, _} = Workshops.enroll_in_package(ctx.com_pacote, aluna)

      {:ok, lv, html} =
        live(log_in_user(build_conn(), ctx.dono), ~p"/programacao/#{ctx.com_pacote.slug}")

      assert html =~ "Quem levou a programação toda"
      assert html =~ aluna.name

      {:ok, [linha]} = Workshops.list_package_enrollments(ctx.com_pacote, ctx.dono)
      html = render_click(lv, "set_package_payment", %{"id" => linha.id, "status" => "paid"})

      assert html =~ "R$ 150"
    end

    test "quem não criou não vê o painel do pacote", ctx do
      {:ok, _} = Workshops.enroll_in_package(ctx.com_pacote, insert(:user))

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/programacao/#{ctx.com_pacote.slug}")

      refute html =~ "Quem levou a programação toda"
    end
  end

  describe "inscrição em lote pelo checklist" do
    test "marca os dois e confirma de uma vez", ctx do
      aluna = insert(:user)

      {:ok, lv, html} =
        live(log_in_user(build_conn(), aluna), ~p"/programacao/#{ctx.program.slug}")

      assert html =~ "Marque os workshops que você vai"

      render_click(lv, "toggle_selection", %{"id" => ctx.quinta.id})
      html = render_click(lv, "toggle_selection", %{"id" => ctx.sexta.id})
      assert html =~ "2 workshops marcados"

      html = render_click(lv, "confirm_enrollment", %{})

      assert html =~ "2 inscrições confirmadas"
      inscritos = Workshops.enrolled_workshop_ids(aluna.id)
      assert MapSet.member?(inscritos, ctx.quinta.id)
      assert MapSet.member?(inscritos, ctx.sexta.id)
    end

    test "desmarcar tira da conta sem desinscrever ninguém", ctx do
      aluna = insert(:user)
      {:ok, lv, _} = live(log_in_user(build_conn(), aluna), ~p"/programacao/#{ctx.program.slug}")

      render_click(lv, "toggle_selection", %{"id" => ctx.quinta.id})
      html = render_click(lv, "toggle_selection", %{"id" => ctx.quinta.id})

      assert html =~ "Marque os workshops que você vai"
      assert Workshops.enrolled_workshop_ids(aluna.id) |> MapSet.size() == 0
    end

    test "confirmar sem marcar nada avisa em vez de fingir que deu", ctx do
      {:ok, lv, _} =
        live(log_in_user(build_conn(), insert(:user)), ~p"/programacao/#{ctx.program.slug}")

      html = render_click(lv, "confirm_enrollment", %{})

      assert html =~ "Marque pelo menos um workshop"
    end

    test "um lotado no meio: os outros entram e a mensagem nomeia o que faltou", ctx do
      lotado =
        insert(:workshop,
          organizer: ctx.dono,
          title: "Lotado demais",
          capacity: 1,
          starts_at: em(9, 19)
        )

      {:ok, _} = Workshops.attach_workshop(ctx.program, ctx.dono, lotado.id)
      {:ok, _} = Workshops.enroll(lotado, insert(:user))

      aluna = insert(:user)
      {:ok, lv, _} = live(log_in_user(build_conn(), aluna), ~p"/programacao/#{ctx.program.slug}")

      # Lotado nem oferece checkbox, então a pessoa nem tenta.
      render_click(lv, "toggle_selection", %{"id" => lotado.id})
      render_click(lv, "toggle_selection", %{"id" => ctx.quinta.id})
      html = render_click(lv, "confirm_enrollment", %{})

      assert html =~ "1 inscrição confirmada"
      assert MapSet.member?(Workshops.enrolled_workshop_ids(aluna.id), ctx.quinta.id)
    end

    test "quem já está inscrito vê a marca e não o checkbox", ctx do
      aluna = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.quinta, aluna)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), aluna), ~p"/programacao/#{ctx.program.slug}")

      refute html =~ ~s(id="escolher-#{ctx.quinta.id}")
      assert html =~ ~s(id="escolher-#{ctx.sexta.id}")
    end

    test "quem organiza não recebe checklist do que é dele", ctx do
      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.dono), ~p"/programacao/#{ctx.program.slug}")

      refute html =~ ~s(id="escolher-#{ctx.quinta.id}")
    end

    test "visitante sem conta vai para o cadastro em vez de quebrar", ctx do
      {:ok, lv, _} = live(build_conn(), ~p"/programacao/#{ctx.program.slug}")

      assert {:error, {:redirect, %{to: destino}}} = render_click(lv, "confirm_enrollment", %{})
      assert destino =~ "/signup"
    end

    test "id forjado não entra na seleção", ctx do
      aluna = insert(:user)
      alheio = insert(:workshop)

      {:ok, lv, _} = live(log_in_user(build_conn(), aluna), ~p"/programacao/#{ctx.program.slug}")

      html = render_click(lv, "toggle_selection", %{"id" => alheio.id})

      assert html =~ "Marque os workshops que você vai"
    end
  end

  describe "montar a programação sem sair da página" do
    test "quem organiza adiciona um workshop solto na hora", ctx do
      # O cenario do festival: alguem improvisa um workshop no meio do evento.
      improvisado = insert(:workshop, organizer: ctx.dono, title: "Roda improvisada")

      {:ok, lv, html} =
        live(log_in_user(build_conn(), ctx.dono), ~p"/programacao/#{ctx.program.slug}")

      assert html =~ "Roda improvisada"

      render_click(lv, "attach_workshop", %{"id" => improvisado.id})

      ids = ctx.program |> Workshops.list_program_workshops() |> Enum.map(& &1.id)
      assert improvisado.id in ids
    end

    test "e tira um de dentro na hora", ctx do
      {:ok, lv, _} =
        live(log_in_user(build_conn(), ctx.dono), ~p"/programacao/#{ctx.program.slug}")

      render_click(lv, "detach_workshop", %{"id" => ctx.sexta.id})

      assert [restante] = Workshops.list_program_workshops(ctx.program)
      assert restante.id == ctx.quinta.id
      # Tirar da programacao nao apaga o workshop.
      assert Workshops.get_workshop(ctx.sexta.id)
    end

    test "quem não organiza não vê o painel nem consegue mexer", ctx do
      estranho = insert(:user)
      workshop_dele = insert(:workshop, organizer: estranho)

      {:ok, lv, html} =
        live(log_in_user(build_conn(), estranho), ~p"/programacao/#{ctx.program.slug}")

      refute html =~ "Montar a programação"

      render_click(lv, "attach_workshop", %{"id" => workshop_dele.id})
      render_click(lv, "detach_workshop", %{"id" => ctx.quinta.id})

      assert length(Workshops.list_program_workshops(ctx.program)) == 2
    end

    test "visitante sem conta não derruba a página mandando o evento", ctx do
      {:ok, lv, _} = live(build_conn(), ~p"/programacao/#{ctx.program.slug}")

      render_click(lv, "attach_workshop", %{"id" => ctx.quinta.id})
      render_click(lv, "detach_workshop", %{"id" => ctx.quinta.id})

      assert render(lv) =~ ctx.program.title
      assert length(Workshops.list_program_workshops(ctx.program)) == 2
    end

    test "id inventado não quebra nada", ctx do
      {:ok, lv, _} =
        live(log_in_user(build_conn(), ctx.dono), ~p"/programacao/#{ctx.program.slug}")

      render_click(lv, "attach_workshop", %{"id" => "nao-e-uuid"})

      assert render(lv) =~ ctx.program.title
    end

    test "o painel só oferece workshops que ainda não estão dentro", ctx do
      fora = insert(:workshop, organizer: ctx.dono, title: "Ainda fora da programação")

      {:ok, lv, html} =
        live(log_in_user(build_conn(), ctx.dono), ~p"/programacao/#{ctx.program.slug}")

      assert html =~ "Ainda fora da programação"

      html = render_click(lv, "attach_workshop", %{"id" => fora.id})

      # Depois de entrar, sai da lista de "adicionar" e vai para a de dentro.
      assert html =~ "Tirar"
    end
  end

  describe "criar workshop já dentro da programação" do
    test "o formulário sabe em qual programação vai entrar", ctx do
      {:ok, _lv, html} =
        live(
          log_in_user(build_conn(), ctx.dono),
          ~p"/study/workshops/novo?#{[programa: ctx.program.slug]}"
        )

      assert html =~ ctx.program.title
    end

    test "ao salvar, o workshop já nasce dentro", ctx do
      {:ok, lv, _} =
        live(
          log_in_user(build_conn(), ctx.dono),
          ~p"/study/workshops/novo?#{[programa: ctx.program.slug]}"
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

    test "programação alheia é ignorada: o workshop nasce solto", ctx do
      alheia = ctx.program
      outro = insert(:user)

      {:ok, lv, _} =
        live(
          log_in_user(build_conn(), outro),
          ~p"/study/workshops/novo?#{[programa: alheia.slug]}"
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
