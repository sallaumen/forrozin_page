defmodule OGrupoDeEstudosWeb.WorkshopsLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Brazil, Engagement, Workshops}
  alias OGrupoDeEstudos.Engagement.Comments.WorkshopCommentQuery

  defp em(dias, hora \\ 14) do
    Brazil.today()
    |> Date.add(dias)
    |> DateTime.new!(Time.new!(hora, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp publicado(organizer, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          title: "Workshop de sacadas",
          description: "Conteúdo do workshop.",
          location: "Curitiba",
          starts_at: em(7)
        },
        overrides
      )

    {:ok, w} = Workshops.create_workshop(organizer, attrs)
    {:ok, w} = Workshops.publish_workshop(organizer, w)
    w
  end

  describe "agenda (/study/workshops)" do
    test "exige login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/study/workshops")
    end

    test "lista os workshops publicados", %{conn: conn} do
      organizer = insert(:user, name: "Tavano Silva")
      publicado(organizer)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")

      assert html =~ "Workshop de sacadas"
      assert html =~ "Tavano Silva"
    end

    test "rascunho não aparece para os outros", %{conn: conn} do
      organizer = insert(:user)

      {:ok, _} =
        Workshops.create_workshop(organizer, %{
          title: "Rascunho secreto",
          description: "x",
          starts_at: em(3)
        })

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")

      refute html =~ "Rascunho secreto"
    end

    test "busca por nome do workshop e do professor", %{conn: conn} do
      tavano = insert(:user, name: "Tavano Silva")
      marina = insert(:user, name: "Marina Prado")
      publicado(tavano, %{title: "Sacadas avançadas"})
      publicado(marina, %{title: "Intensivo de inversão"})

      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")

      html = render_change(lv, "search_workshops", %{"term" => "inversão"})
      assert html =~ "Intensivo de inversão"
      refute html =~ "Sacadas avançadas"

      html = render_change(lv, "search_workshops", %{"term" => "tavano"})
      assert html =~ "Sacadas avançadas"
      refute html =~ "Intensivo de inversão"
    end

    test "filtro de período separa passado de futuro", %{conn: conn} do
      organizer = insert(:user)
      publicado(organizer, %{title: "Vai acontecer", starts_at: em(5)})
      publicado(organizer, %{title: "Já rolou", starts_at: em(-5)})

      {:ok, lv, html} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")
      assert html =~ "Vai acontecer"
      refute html =~ "Já rolou"

      html = render_click(lv, "filter_period", %{"period" => "past"})
      assert html =~ "Já rolou"
    end

    test "período forjado é ignorado", %{conn: conn} do
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")

      html = render_click(lv, "filter_period", %{"period" => "drop_table"})
      assert html =~ "Workshops"
    end

    test "estado vazio orienta quem chega", %{conn: conn} do
      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")

      assert html =~ "Nenhum workshop por aqui ainda"
    end
  end

  defp primeira_inscricao(workshop) do
    workshop.id
    |> OGrupoDeEstudos.Workshops.EnrollmentQuery.list_participants()
    |> hd()
    |> Map.fetch!(:id)
  end

  describe "conversa na página do workshop" do
    setup %{conn: conn} do
      organizer = insert(:user)
      %{organizer: organizer, workshop: publicado(organizer, %{}), conn: conn}
    end

    test "visitante sem conta lê a conversa mas não vê o formulário", %{
      conn: conn,
      workshop: w
    } do
      autor = insert(:user)
      {:ok, _} = Engagement.create_workshop_comment(autor, w.id, %{body: "que horas começa?"})

      {:ok, _lv, html} = live(conn, ~p"/workshops/#{w.slug}")

      assert html =~ "que horas começa?"
      refute html =~ ~s(phx-submit="create_comment")
      assert html =~ "Entre para comentar"
    end

    test "quem tem conta comenta e vê o comentário na hora", %{conn: conn, workshop: w} do
      visitante = insert(:user)
      {:ok, lv, _} = live(log_in_user(conn, visitante), ~p"/workshops/#{w.slug}")

      html = render_submit(lv, "create_comment", %{"body" => "eu vou!"})

      assert html =~ "eu vou!"
      assert [comment] = Engagement.list_workshop_comments(w.id)
      assert comment.user_id == visitante.id
    end

    test "comentário vazio não cria linha nenhuma", %{conn: conn, workshop: w} do
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      render_submit(lv, "create_comment", %{"body" => "   "})

      assert Engagement.list_workshop_comments(w.id) == []
    end

    test "responder aparece indentado sob o comentário", %{conn: conn, workshop: w} do
      {:ok, raiz} = Engagement.create_workshop_comment(insert(:user), w.id, %{body: "e o local?"})
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      html =
        render_submit(lv, "create_reply", %{"body" => "no Batel", "parent-id" => raiz.id})

      assert html =~ "no Batel"
    end

    test "curtir comentário conta e descurte volta", %{conn: conn, workshop: w} do
      {:ok, comment} = Engagement.create_workshop_comment(insert(:user), w.id, %{body: "boa!"})
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      render_click(lv, "toggle_comment_like", %{"type" => "workshop_comment", "id" => comment.id})
      assert Engagement.count_likes("workshop_comment", comment.id) == 1

      render_click(lv, "toggle_comment_like", %{"type" => "workshop_comment", "id" => comment.id})
      assert Engagement.count_likes("workshop_comment", comment.id) == 0
    end

    test "autor apaga o próprio comentário pela página", %{conn: conn, workshop: w} do
      autor = insert(:user)
      {:ok, comment} = Engagement.create_workshop_comment(autor, w.id, %{body: "removo isso"})

      {:ok, lv, _} = live(log_in_user(conn, autor), ~p"/workshops/#{w.slug}")

      html =
        render_click(lv, "delete_comment", %{"id" => comment.id, "type" => "workshop_comment"})

      refute html =~ "removo isso"
      assert Engagement.list_workshop_comments(w.id) == []
    end

    test "ninguém apaga comentário alheio pela página", %{conn: conn, workshop: w} do
      {:ok, comment} = Engagement.create_workshop_comment(insert(:user), w.id, %{body: "meu"})

      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")
      render_click(lv, "delete_comment", %{"id" => comment.id, "type" => "workshop_comment"})

      assert [_ainda_la] = Engagement.list_workshop_comments(w.id)
    end

    test "rascunho explica que a conversa abre ao publicar", %{conn: conn, organizer: organizer} do
      {:ok, rascunho} =
        Workshops.create_workshop(organizer, %{
          title: "Ainda rascunho",
          description: "Sem publicar.",
          starts_at: em(7)
        })

      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/workshops/#{rascunho.slug}")

      # Mostrar um campo que sempre falha no envio seria pior que não mostrar.
      refute html =~ ~s(phx-submit="create_comment")
      assert html =~ "A conversa abre quando você publicar"
    end

    test "visitante anônimo não vê o botão Responder", %{conn: conn, workshop: w} do
      {:ok, _} = Engagement.create_workshop_comment(insert(:user), w.id, %{body: "e o local?"})

      {:ok, _lv, html} = live(conn, ~p"/workshops/#{w.slug}")

      # Deixar clicar e jogar o texto fora no envio é pior que não oferecer.
      refute html =~ "Responder"
      assert html =~ "Entre para comentar"
    end

    test "rascunho não aceita comentário", %{conn: conn, organizer: organizer} do
      {:ok, rascunho} =
        Workshops.create_workshop(organizer, %{
          title: "Ainda rascunho",
          description: "Sem publicar.",
          starts_at: em(7)
        })

      {:ok, lv, _} = live(log_in_user(conn, organizer), ~p"/workshops/#{rascunho.slug}")

      render_submit(lv, "create_comment", %{"body" => "tentando"})

      assert Engagement.list_workshop_comments(rascunho.id) == []
    end

    test "workshop cancelado continua aceitando comentário", %{
      conn: conn,
      organizer: organizer,
      workshop: w
    } do
      {:ok, cancelado} = Workshops.cancel_workshop(organizer, w)
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{cancelado.slug}")

      render_submit(lv, "create_comment", %{"body" => "que pena, o que houve?"})

      assert [_] = Engagement.list_workshop_comments(cancelado.id)
    end
  end

  describe "rascunho não vaza pelo link" do
    setup %{conn: conn} do
      organizer = insert(:user)

      {:ok, rascunho} =
        Workshops.create_workshop(organizer, %{
          title: "Segredo ainda",
          description: "Preço e local que ninguém deveria ver.",
          starts_at: em(7)
        })

      %{organizer: organizer, rascunho: rascunho, conn: conn}
    end

    test "visitante sem conta não abre", %{conn: conn, rascunho: w} do
      assert {:error, {:redirect, %{to: destino}}} = live(conn, ~p"/workshops/#{w.slug}")
      assert destino == ~p"/study/workshops"
    end

    test "estranho logado não abre", %{conn: conn, rascunho: w} do
      assert {:error, {:redirect, _}} =
               live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")
    end

    test "admin do site também não abre rascunho alheio", %{conn: conn, rascunho: w} do
      assert {:error, {:redirect, _}} =
               live(log_in_user(conn, insert(:admin)), ~p"/workshops/#{w.slug}")
    end

    test "quem organiza abre normalmente", %{conn: conn, organizer: dono, rascunho: w} do
      {:ok, _lv, html} = live(log_in_user(conn, dono), ~p"/workshops/#{w.slug}")

      assert html =~ "Segredo ainda"
    end

    test "a mensagem não confirma que o workshop existe", %{conn: conn, rascunho: w} do
      conn = get(conn, ~p"/workshops/#{w.slug}")

      # Mesma resposta de slug inexistente: quem sonda não descobre nada.
      inexistente = get(build_conn(), ~p"/workshops/workshop-que-nao-existe-aaaaaa")
      assert redirected_to(conn) == redirected_to(inexistente)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "não encontrado"
    end
  end

  describe "resistência a id inválido" do
    setup %{conn: conn} do
      %{workshop: publicado(insert(:user), %{}), conn: conn}
    end

    test "visitante anônimo não derruba a página com id qualquer", %{conn: conn, workshop: w} do
      {:ok, lv, _} = live(conn, ~p"/workshops/#{w.slug}")

      # A página é pública: qualquer um manda o evento que quiser pelo socket.
      for evento <- ~w(toggle_replies start_reply) do
        render_click(lv, evento, %{"id" => "; drop table"})
      end

      assert render(lv) =~ "Conversa"
    end

    test "usuário logado não derruba a página com id qualquer", %{conn: conn, workshop: w} do
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      render_click(lv, "toggle_comment_like", %{"type" => "workshop_comment", "id" => "nada"})
      render_click(lv, "delete_comment", %{"id" => "nada", "type" => "workshop_comment"})
      render_click(lv, "toggle_replies", %{"id" => "nada"})
      render_submit(lv, "create_reply", %{"body" => "oi", "parent-id" => "nada"})

      assert render(lv) =~ "Conversa"
    end

    test "resposta não se prende a comentário de outro workshop", %{conn: conn, workshop: w} do
      alheio = publicado(insert(:user), %{title: "Outro workshop"})
      {:ok, de_fora} = Engagement.create_workshop_comment(insert(:user), alheio.id, %{body: "lá"})

      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")
      render_submit(lv, "create_reply", %{"body" => "invadindo", "parent-id" => de_fora.id})

      assert Engagement.list_workshop_comments(w.id) == []
      assert Engagement.list_replies(WorkshopCommentQuery, de_fora.id) == []
    end
  end

  describe "curtir o workshop" do
    test "curte, conta e descurte", %{conn: conn} do
      w = publicado(insert(:user), %{})
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      render_click(lv, "toggle_workshop_like", %{})
      assert Engagement.count_likes("workshop", w.id) == 1

      render_click(lv, "toggle_workshop_like", %{})
      assert Engagement.count_likes("workshop", w.id) == 0
    end

    test "visitante sem conta não curte, vai para o cadastro", %{conn: conn} do
      w = publicado(insert(:user), %{})
      {:ok, lv, _} = live(conn, ~p"/workshops/#{w.slug}")

      assert {:error, {:redirect, %{to: destino}}} =
               render_click(lv, "toggle_workshop_like", %{})

      assert destino =~ "/signup"
      assert Engagement.count_likes("workshop", w.id) == 0
    end
  end

  describe "notificação para o organizador" do
    test "inscrição acende o contador e o link leva ao painel", %{conn: conn} do
      organizer = insert(:user)
      w = publicado(organizer, %{})
      aluna = insert(:user)

      {:ok, _} = Workshops.enroll(w, aluna)

      assert Engagement.unread_count(organizer.id) == 1

      # O painel do organizador é onde a notificação desemboca: precisa do sino.
      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}/gerenciar")
      assert html =~ "hero-bell"
    end

    test "o link da notificação de inscrição aponta para o painel", %{conn: conn} do
      organizer = insert(:user)
      w = publicado(organizer, %{})
      {:ok, _} = Workshops.enroll(w, insert(:user))

      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/notifications")

      assert html =~ "se inscreveu no seu workshop"
      assert html =~ "/workshops/#{w.slug}/gerenciar"
    end

    test "comentário no workshop leva à página pública", %{conn: conn} do
      organizer = insert(:user)
      w = publicado(organizer, %{})
      {:ok, _} = Engagement.create_workshop_comment(insert(:user), w.id, %{body: "e aí?"})

      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/notifications")

      assert html =~ "comentou no seu workshop"
      assert html =~ "/workshops/#{w.slug}"
    end
  end

  describe "agenda: ids de DOM" do
    test "workshop que aparece nas duas seções não repete id", %{conn: conn} do
      organizer = insert(:user)
      w = publicado(organizer, %{})

      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/study/workshops")

      # Ele sai em "Você organiza" e também na agenda: dois ids iguais fariam
      # o LiveView atualizar o card errado.
      assert html =~ ~s(id="organiza-#{w.id}")
      assert html =~ ~s(id="workshop-card-#{w.id}")
    end
  end

  describe "painel do organizador: cobrança" do
    test "workshop gratuito não mostra controle de pagamento", %{conn: conn} do
      organizer = insert(:user)
      aluna = insert(:user)
      w = publicado(organizer, %{price_cents: nil})
      {:ok, _} = Workshops.enroll(w, aluna)

      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}/gerenciar")

      assert html =~ "inscritos"
      assert html =~ aluna.name
      refute html =~ "Marcar pago"
      refute html =~ "a receber"
      refute html =~ "Aguardando"
    end

    test "workshop pago mostra o total recebido em reais, zero incluso", %{conn: conn} do
      organizer = insert(:user)
      aluna = insert(:user)
      w = publicado(organizer, %{price_cents: 18_000})
      {:ok, _} = Workshops.enroll(w, aluna)

      {:ok, lv, html} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}/gerenciar")

      # Ninguém pagou ainda: "R$ 0", nunca "Gratuito".
      assert html =~ "R$ 0"
      refute html =~ "Gratuito"
      assert html =~ "Marcar pago"

      html = render_click(lv, "set_payment", %{"id" => primeira_inscricao(w), "status" => "paid"})
      assert html =~ "R$ 180"
    end
  end

  describe "página pública (/workshops/:slug)" do
    test "dados de pagamento só aparecem para quem se inscreveu", %{conn: conn} do
      organizer = insert(:user)
      aluna = insert(:user)
      w = publicado(organizer, %{price_cents: 8000, payment_info: "Pix 41 99999-0000"})

      {:ok, _lv, anonimo} = live(conn, ~p"/workshops/#{w.slug}")
      refute anonimo =~ "41 99999-0000"
      assert anonimo =~ "R$ 80"

      {:ok, _lv, deslogada} = live(log_in_user(conn, aluna), ~p"/workshops/#{w.slug}")
      refute deslogada =~ "41 99999-0000"

      {:ok, _} = Workshops.enroll(w, aluna)
      {:ok, _lv, inscrita} = live(log_in_user(conn, aluna), ~p"/workshops/#{w.slug}")
      assert inscrita =~ "41 99999-0000"

      {:ok, _lv, dono} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}")
      assert dono =~ "41 99999-0000"
    end

    test "organizador não vê botão de inscrição, e sim o de gerenciar", %{conn: conn} do
      organizer = insert(:user)
      w = publicado(organizer, %{})

      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}")

      refute html =~ "Fazer inscrição"
      assert html =~ "Gerenciar inscritos"
    end

    test "visitante sem conta vê o essencial", %{conn: conn} do
      organizer = insert(:user, name: "Tavano Silva")
      w = publicado(organizer, %{price_cents: 8000})

      {:ok, _lv, html} = live(conn, ~p"/workshops/#{w.slug}")

      assert html =~ "Workshop de sacadas"
      assert html =~ "R$ 80"
      assert html =~ "Tavano Silva"
      assert html =~ "Entrar"
    end

    test "visitante sem conta não vê os nomes dos inscritos", %{conn: conn} do
      organizer = insert(:user)
      w = publicado(organizer)
      aluno = insert(:user, name: "Ana Souza")
      {:ok, _} = Workshops.enroll(w, aluno)

      {:ok, _lv, html} = live(conn, ~p"/workshops/#{w.slug}")

      refute html =~ "Ana Souza"
      assert html =~ "1 inscrito"
    end

    test "quem está logado vê quem vai", %{conn: conn} do
      organizer = insert(:user)
      w = publicado(organizer)
      {:ok, _} = Workshops.enroll(w, insert(:user, name: "Ana Souza"))

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      assert html =~ "Ana Souza"
    end

    test "inscrever e cancelar", %{conn: conn} do
      organizer = insert(:user)
      w = publicado(organizer)
      aluno = insert(:user)

      {:ok, lv, _} = live(log_in_user(conn, aluno), ~p"/workshops/#{w.slug}")

      html = render_click(lv, "enroll", %{})
      assert html =~ "Inscrição confirmada"
      assert html =~ "Você está inscrito"
      assert Workshops.count_enrollments(w.id) == 1

      html = render_click(lv, "cancel_enrollment", %{})
      assert html =~ "Inscrição cancelada"
      assert Workshops.count_enrollments(w.id) == 0
    end

    test "visitante sem conta é levado ao cadastro ao tentar se inscrever", %{conn: conn} do
      w = publicado(insert(:user))

      {:ok, lv, _} = live(conn, ~p"/workshops/#{w.slug}")

      assert {:error, {:redirect, %{to: destino}}} = render_click(lv, "enroll", %{})
      assert destino =~ "/signup"
      assert destino =~ w.slug
    end

    test "lotado mostra esgotado e não deixa inscrever", %{conn: conn} do
      organizer = insert(:user)
      w = publicado(organizer, %{capacity: 1})
      {:ok, _} = Workshops.enroll(w, insert(:user))

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      assert html =~ "Vagas esgotadas"
      refute html =~ "Fazer inscrição"
    end

    test "slug inexistente volta para a agenda", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/study/workshops"}}} =
               live(log_in_user(conn, insert(:user)), ~p"/workshops/nao-existe")
    end

    test "a página pública nunca traz dado de pagamento", %{conn: conn} do
      organizer = insert(:user)
      w = publicado(organizer)
      aluno = insert(:user)
      {:ok, _} = Workshops.enroll(w, aluno)
      {:ok, [linha]} = Workshops.list_enrollments_for_organizer(w, organizer)
      {:ok, _} = Workshops.set_payment_status(w, organizer, linha.id, :paid)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      refute html =~ "Pago"
      refute html =~ "Aguardando"
      refute html =~ "Marcar pago"
    end
  end

  describe "painel do organizador (/workshops/:slug/gerenciar)" do
    setup %{conn: conn} do
      organizer = insert(:user)
      w = publicado(organizer, %{price_cents: 8000})
      aluno = insert(:user, name: "Ana Souza")
      {:ok, _} = Workshops.enroll(w, aluno)

      %{conn: conn, organizer: organizer, workshop: w, aluno: aluno}
    end

    test "quem não organiza é barrado", %{conn: conn, workshop: w, aluno: aluno} do
      assert {:error, {:redirect, %{to: "/study/workshops"}}} =
               live(log_in_user(conn, aluno), ~p"/workshops/#{w.slug}/gerenciar")
    end

    test "nem admin entra no painel de pagamento", %{conn: conn, workshop: w} do
      assert {:error, {:redirect, %{to: "/study/workshops"}}} =
               live(log_in_user(conn, insert(:admin)), ~p"/workshops/#{w.slug}/gerenciar")
    end

    test "organizador vê inscritos e marca pagamento", %{
      conn: conn,
      organizer: organizer,
      workshop: w
    } do
      {:ok, lv, html} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}/gerenciar")

      assert html =~ "Ana Souza"
      assert html =~ "Só você vê esta tela"
      assert html =~ "Aguardando"

      {:ok, [linha]} = Workshops.list_enrollments_for_organizer(w, organizer)
      html = render_click(lv, "set_payment", %{"id" => linha.id, "status" => "paid"})

      assert html =~ "Pagamento registrado"
      assert html =~ "R$ 80"
    end

    test "id de inscrição de outro workshop não passa", %{
      conn: conn,
      organizer: organizer,
      workshop: w
    } do
      outro_dono = insert(:user)
      outro = publicado(outro_dono, %{title: "Outro"})
      {:ok, alheia} = Workshops.enroll(outro, insert(:user))

      {:ok, lv, _} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}/gerenciar")

      html = render_click(lv, "set_payment", %{"id" => alheia.id, "status" => "paid"})
      assert html =~ "Inscrição não encontrada"

      {:ok, [intacta]} = Workshops.list_enrollments_for_organizer(outro, outro_dono)
      assert intacta.payment_status == :pending
    end

    test "cancelar preserva os inscritos", %{conn: conn, organizer: organizer, workshop: w} do
      {:ok, lv, _} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}/gerenciar")

      html = render_click(lv, "cancel_workshop", %{})

      assert html =~ "Workshop cancelado"
      assert Workshops.count_enrollments(w.id) == 1
    end
  end

  describe "criar workshop (/study/workshops/novo)" do
    test "cria e publica", %{conn: conn} do
      user = insert(:user)
      {:ok, lv, _} = live(log_in_user(conn, user), ~p"/study/workshops/novo")

      params = %{
        "title" => "Aulão de forró",
        "description" => "Vamos dançar muito.",
        "location" => "Curitiba",
        "starts_at" => "2026-12-20T14:00",
        "ends_at" => "2026-12-20T18:00",
        "price" => "80,00",
        "capacity" => "50",
        "payment_info" => "Pix na inscrição"
      }

      render_change(lv, "validate", %{"workshop" => params})

      # Pelo form de verdade: assim o teste quebra se algum campo sumir do HTML.
      assert {:error, {:redirect, %{to: destino}}} =
               lv
               |> form("#workshop-form", %{"workshop" => params})
               |> render_submit(%{"publish" => "true"})

      assert destino =~ "/workshops/aulao-de-forro-"

      assert [w] = Workshops.list_for_organizer(user.id)
      assert w.status == :published
      assert w.price_cents == 8000
      assert w.capacity == 50
    end

    test "salvar rascunho não publica", %{conn: conn} do
      user = insert(:user)
      {:ok, lv, _} = live(log_in_user(conn, user), ~p"/study/workshops/novo")

      params = %{
        "title" => "Só um rascunho",
        "description" => "Ainda pensando.",
        "starts_at" => "2026-12-20T14:00"
      }

      assert {:error, {:redirect, _}} =
               lv
               |> form("#workshop-form", %{"workshop" => params})
               |> render_submit(%{"publish" => "false"})

      assert [w] = Workshops.list_for_organizer(user.id)
      assert w.status == :draft
    end

    test "erro de validação mostra mensagem e preserva o texto", %{conn: conn} do
      user = insert(:user)
      {:ok, lv, _} = live(log_in_user(conn, user), ~p"/study/workshops/novo")

      params = %{"title" => "", "description" => "Escrevi isso aqui", "starts_at" => ""}

      html =
        lv
        |> form("#workshop-form", %{"workshop" => params})
        |> render_submit(%{"publish" => "true"})

      assert html =~ "Título"
      assert html =~ "Escrevi isso aqui"
      assert Workshops.list_for_organizer(user.id) == []
    end

    test "outro usuário não edita workshop alheio", %{conn: conn} do
      w = publicado(insert(:user))

      assert {:error, {:redirect, %{to: "/study/workshops"}}} =
               live(log_in_user(conn, insert(:user)), ~p"/study/workshops/#{w.slug}/editar")
    end
  end
end
