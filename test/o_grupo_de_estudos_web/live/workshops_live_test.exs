defmodule OGrupoDeEstudosWeb.WorkshopsLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Brazil, Engagement, Workshops}
  alias OGrupoDeEstudos.Engagement.Comments.WorkshopCommentQuery

  defp at_day(days, hour \\ 14) do
    Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(Time.new!(hour, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp published(organizer, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          title: "Workshop de sacadas",
          description: "Conteúdo do workshop.",
          location: "Curitiba",
          starts_at: at_day(7)
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

    test "lists the published workshops", %{conn: conn} do
      organizer = insert(:user, name: "Tavano Silva")
      published(organizer)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")

      assert html =~ "Workshop de sacadas"
      assert html =~ "Tavano Silva"
    end

    test "draft does not show up for other users", %{conn: conn} do
      organizer = insert(:user)

      {:ok, _} =
        Workshops.create_workshop(organizer, %{
          title: "Rascunho secreto",
          description: "x",
          starts_at: at_day(3)
        })

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")

      refute html =~ "Rascunho secreto"
    end

    test "searches by workshop title and by teacher name", %{conn: conn} do
      tavano = insert(:user, name: "Tavano Silva")
      marina = insert(:user, name: "Marina Prado")
      published(tavano, %{title: "Sacadas avançadas"})
      published(marina, %{title: "Intensivo de inversão"})

      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")

      html = render_change(lv, "search_workshops", %{"term" => "inversão"})
      assert html =~ "Intensivo de inversão"
      refute html =~ "Sacadas avançadas"

      html = render_change(lv, "search_workshops", %{"term" => "tavano"})
      assert html =~ "Sacadas avançadas"
      refute html =~ "Intensivo de inversão"
    end

    test "period filter separates past from future", %{conn: conn} do
      organizer = insert(:user)
      published(organizer, %{title: "Vai acontecer", starts_at: at_day(5)})
      published(organizer, %{title: "Já rolou", starts_at: at_day(-5)})

      {:ok, lv, html} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")
      assert html =~ "Vai acontecer"
      refute html =~ "Já rolou"

      html = render_click(lv, "filter_period", %{"period" => "past"})
      assert html =~ "Já rolou"
    end

    test "forged period is ignored", %{conn: conn} do
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")

      html = render_click(lv, "filter_period", %{"period" => "drop_table"})
      assert html =~ "Workshops"
    end

    test "estado vazio orienta quem chega", %{conn: conn} do
      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/study/workshops")

      assert html =~ "Nada marcado por aqui ainda"
    end
  end

  defp first_enrollment(workshop) do
    workshop.id
    |> OGrupoDeEstudos.Workshops.EnrollmentQuery.list_participants()
    |> hd()
    |> Map.fetch!(:id)
  end

  describe "conversation on the workshop page" do
    setup %{conn: conn} do
      organizer = insert(:user)
      %{organizer: organizer, workshop: published(organizer, %{}), conn: conn}
    end

    test "anonymous visitor reads the conversation but sees no form", %{
      conn: conn,
      workshop: w
    } do
      author = insert(:user)
      {:ok, _} = Engagement.create_workshop_comment(author, w.id, %{body: "que horas começa?"})

      {:ok, _lv, html} = live(conn, ~p"/workshops/#{w.slug}")

      assert html =~ "que horas começa?"
      refute html =~ ~s(phx-submit="create_comment")
      assert html =~ "Entre para comentar"
    end

    test "logged-in user comments and sees the comment right away", %{conn: conn, workshop: w} do
      visitante = insert(:user)
      {:ok, lv, _} = live(log_in_user(conn, visitante), ~p"/workshops/#{w.slug}")

      html = render_submit(lv, "create_comment", %{"body" => "eu vou!"})

      assert html =~ "eu vou!"
      assert [comment] = Engagement.list_workshop_comments(w.id)
      assert comment.user_id == visitante.id
    end

    test "empty comment creates no row", %{conn: conn, workshop: w} do
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      render_submit(lv, "create_comment", %{"body" => "   "})

      assert Engagement.list_workshop_comments(w.id) == []
    end

    test "reply appears indented under the comment", %{conn: conn, workshop: w} do
      {:ok, raiz} = Engagement.create_workshop_comment(insert(:user), w.id, %{body: "e o local?"})
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      html =
        render_submit(lv, "create_reply", %{"body" => "no Batel", "parent-id" => raiz.id})

      assert html =~ "no Batel"
    end

    test "liking a comment counts and unliking takes it back", %{conn: conn, workshop: w} do
      {:ok, comment} = Engagement.create_workshop_comment(insert(:user), w.id, %{body: "boa!"})
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      render_click(lv, "toggle_comment_like", %{"type" => "workshop_comment", "id" => comment.id})
      assert Engagement.count_likes("workshop_comment", comment.id) == 1

      render_click(lv, "toggle_comment_like", %{"type" => "workshop_comment", "id" => comment.id})
      assert Engagement.count_likes("workshop_comment", comment.id) == 0
    end

    test "author deletes their own comment from the page", %{conn: conn, workshop: w} do
      author = insert(:user)
      {:ok, comment} = Engagement.create_workshop_comment(author, w.id, %{body: "removo isso"})

      {:ok, lv, _} = live(log_in_user(conn, author), ~p"/workshops/#{w.slug}")

      html =
        render_click(lv, "delete_comment", %{"id" => comment.id, "type" => "workshop_comment"})

      refute html =~ "removo isso"
      assert Engagement.list_workshop_comments(w.id) == []
    end

    test "nobody deletes someone else's comment from the page", %{conn: conn, workshop: w} do
      {:ok, comment} = Engagement.create_workshop_comment(insert(:user), w.id, %{body: "meu"})

      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")
      render_click(lv, "delete_comment", %{"id" => comment.id, "type" => "workshop_comment"})

      assert [_ainda_la] = Engagement.list_workshop_comments(w.id)
    end

    test "draft explains that the conversation opens on publish", %{
      conn: conn,
      organizer: organizer
    } do
      {:ok, draft} =
        Workshops.create_workshop(organizer, %{
          title: "Ainda rascunho",
          description: "Sem publicar.",
          starts_at: at_day(7)
        })

      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/workshops/#{draft.slug}")

      refute html =~ ~s(phx-submit="create_comment")
      assert html =~ "A conversa abre quando você publicar"
    end

    test "anonymous visitor does not see the reply button", %{conn: conn, workshop: w} do
      {:ok, _} = Engagement.create_workshop_comment(insert(:user), w.id, %{body: "e o local?"})

      {:ok, _lv, html} = live(conn, ~p"/workshops/#{w.slug}")

      refute html =~ "Responder"
      assert html =~ "Entre para comentar"
    end

    test "draft does not accept comments", %{conn: conn, organizer: organizer} do
      {:ok, draft} =
        Workshops.create_workshop(organizer, %{
          title: "Ainda rascunho",
          description: "Sem publicar.",
          starts_at: at_day(7)
        })

      {:ok, lv, _} = live(log_in_user(conn, organizer), ~p"/workshops/#{draft.slug}")

      render_submit(lv, "create_comment", %{"body" => "tentando"})

      assert Engagement.list_workshop_comments(draft.id) == []
    end

    test "cancelled workshop keeps accepting comments", %{
      conn: conn,
      organizer: organizer,
      workshop: w
    } do
      {:ok, cancelled} = Workshops.cancel_workshop(organizer, w)
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{cancelled.slug}")

      render_submit(lv, "create_comment", %{"body" => "que pena, o que houve?"})

      assert [_] = Engagement.list_workshop_comments(cancelled.id)
    end
  end

  describe "co-organizadores no painel" do
    setup %{conn: conn} do
      criador = insert(:user)
      %{criador: criador, workshop: published(criador, %{}), partner: insert(:user), conn: conn}
    end

    test "creator adds a co-organizer by username", ctx do
      {:ok, lv, _} =
        live(log_in_user(ctx.conn, ctx.criador), ~p"/workshops/#{ctx.workshop.slug}/gerenciar")

      html = render_submit(lv, "add_admin", %{"username" => ctx.partner.username})

      assert html =~ ctx.partner.username
      assert Workshops.admin?(ctx.workshop, ctx.partner)
    end

    test "unknown username warns instead of crashing", ctx do
      {:ok, lv, _} =
        live(log_in_user(ctx.conn, ctx.criador), ~p"/workshops/#{ctx.workshop.slug}/gerenciar")

      html = render_submit(lv, "add_admin", %{"username" => "ninguem_com_esse_nome"})

      assert html =~ "Não encontrei esse usuário"
    end

    test "co-organizer opens the panel and sees payment but adds nobody", ctx do
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.partner.id)

      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.partner), ~p"/workshops/#{ctx.workshop.slug}/gerenciar")

      assert html =~ "Inscritos"
      refute html =~ ~s(id="add-admin-form")
      refute html =~ "Cancelar este workshop"
    end

    test "outsider stays out of the panel", ctx do
      assert {:error, {:redirect, _}} =
               live(
                 log_in_user(ctx.conn, insert(:user)),
                 ~p"/workshops/#{ctx.workshop.slug}/gerenciar"
               )
    end

    test "creator removes the co-organizer", ctx do
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.partner.id)

      {:ok, lv, _} =
        live(log_in_user(ctx.conn, ctx.criador), ~p"/workshops/#{ctx.workshop.slug}/gerenciar")

      render_click(lv, "remove_admin", %{"id" => ctx.partner.id})

      refute Workshops.admin?(ctx.workshop, ctx.partner)
    end

    test "co-organizer edits the workshop through the form", ctx do
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.criador, ctx.partner.id)

      {:ok, lv, _} =
        live(
          log_in_user(ctx.conn, ctx.partner),
          ~p"/study/workshops/#{ctx.workshop.slug}/editar"
        )

      assert {:error, {:redirect, _}} =
               lv
               |> form("#workshop-form", %{
                 "workshop" => %{
                   "title" => "Editado a quatro mãos",
                   "description" => "Conteúdo.",
                   "starts_at" => "2026-12-20T14:00"
                 }
               })
               |> render_submit(%{"publish" => "true"})

      assert Workshops.get_workshop(ctx.workshop.id).title == "Editado a quatro mãos"
    end
  end

  describe "private workshop: storefront and entry by approval" do
    setup %{conn: conn} do
      owner = insert(:user)
      private_workshop = published(owner, %{title: "Turma fechada", visibility: :private})
      %{owner: owner, private_workshop: private_workshop, conn: conn}
    end

    test "shows up on the agenda with an entry-by-approval badge", ctx do
      {:ok, _lv, html} = live(log_in_user(ctx.conn, insert(:user)), ~p"/study/workshops")

      assert html =~ "Turma fechada"
      assert html =~ "Por aprovação"
    end

    test "page opens for an outsider, showing the storefront", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, insert(:user)), ~p"/workshops/#{ctx.private_workshop.slug}")

      assert html =~ "Turma fechada"
      assert html =~ "Pedir para entrar"
    end

    test "page opens for an anonymous visitor too", ctx do
      {:ok, _lv, html} = live(ctx.conn, ~p"/workshops/#{ctx.private_workshop.slug}")

      assert html =~ "Turma fechada"
    end

    test "asking swaps the button for a waiting notice", ctx do
      student = insert(:user)

      {:ok, lv, _} =
        live(log_in_user(ctx.conn, student), ~p"/workshops/#{ctx.private_workshop.slug}")

      html = render_click(lv, "request_join", %{})

      assert html =~ "Seu pedido foi enviado"
      refute html =~ "Pedir para entrar"
      assert Workshops.join_status(ctx.private_workshop, student) == :pending
    end

    test "whoever has not entered sees neither the conversation nor who is going", ctx do
      student = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.private_workshop, insert(:user, name: "Ja Inscrita"))

      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, student), ~p"/workshops/#{ctx.private_workshop.slug}")

      refute html =~ "Ja Inscrita"
      assert html =~ "Escrever comentário" == false
    end

    test "the ask button comes back after a rejection", ctx do
      student = insert(:user)
      {:ok, _} = Workshops.request_join(ctx.private_workshop, student)
      [request] = Workshops.list_pending_requests(ctx.private_workshop)
      {:ok, _} = Workshops.reject_join(ctx.private_workshop, ctx.owner, request.id)

      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, student), ~p"/workshops/#{ctx.private_workshop.slug}")

      assert html =~ "Pedir para entrar"
    end

    test "organizer opens everything without asking", ctx do
      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/workshops/#{ctx.private_workshop.slug}")

      assert html =~ "Turma fechada"
      refute html =~ "Pedir para entrar"
    end

    test "panel lists the queue and approving enrolls the person", ctx do
      student = insert(:user, name: "Joana Pediu")
      {:ok, _} = Workshops.request_join(ctx.private_workshop, student)

      {:ok, lv, html} =
        live(
          log_in_user(ctx.conn, ctx.owner),
          ~p"/workshops/#{ctx.private_workshop.slug}/gerenciar"
        )

      assert html =~ "Pedidos para entrar"
      assert html =~ "Joana Pediu"

      [request] = Workshops.list_pending_requests(ctx.private_workshop)
      render_click(lv, "approve_join", %{"id" => request.id})

      assert MapSet.member?(Workshops.enrolled_workshop_ids(student.id), ctx.private_workshop.id)
    end

    test "public workshop shows no request queue", ctx do
      public_workshop = published(ctx.owner, %{title: "Aberto"})

      {:ok, _lv, html} =
        live(log_in_user(ctx.conn, ctx.owner), ~p"/workshops/#{public_workshop.slug}/gerenciar")

      refute html =~ "Pedidos para entrar"
    end
  end

  describe "draft does not leak through the link" do
    setup %{conn: conn} do
      organizer = insert(:user)

      {:ok, draft} =
        Workshops.create_workshop(organizer, %{
          title: "Segredo ainda",
          description: "Preço e local que ninguém deveria ver.",
          starts_at: at_day(7)
        })

      %{organizer: organizer, draft: draft, conn: conn}
    end

    test "anonymous visitor does not open it", %{conn: conn, draft: w} do
      assert {:error, {:redirect, %{to: destination}}} = live(conn, ~p"/workshops/#{w.slug}")
      assert destination == ~p"/study/workshops"
    end

    test "logged-in outsider does not open it", %{conn: conn, draft: w} do
      assert {:error, {:redirect, _}} =
               live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")
    end

    test "site admin does not open someone else's draft either", %{conn: conn, draft: w} do
      assert {:error, {:redirect, _}} =
               live(log_in_user(conn, insert(:admin)), ~p"/workshops/#{w.slug}")
    end

    test "organizer opens it normally", %{conn: conn, organizer: owner, draft: w} do
      {:ok, _lv, html} = live(log_in_user(conn, owner), ~p"/workshops/#{w.slug}")

      assert html =~ "Segredo ainda"
    end

    test "message does not confirm that the workshop exists", %{conn: conn, draft: w} do
      conn = get(conn, ~p"/workshops/#{w.slug}")

      inexistente = get(build_conn(), ~p"/workshops/workshop-que-nao-existe-aaaaaa")
      assert redirected_to(conn) == redirected_to(inexistente)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "não encontrado"
    end
  end

  describe "resistance to invalid ids" do
    setup %{conn: conn} do
      %{workshop: published(insert(:user), %{}), conn: conn}
    end

    test "anonymous visitor does not crash the page with an arbitrary id", %{
      conn: conn,
      workshop: w
    } do
      {:ok, lv, _} = live(conn, ~p"/workshops/#{w.slug}")

      for event <- ~w(toggle_replies start_reply) do
        render_click(lv, event, %{"id" => "; drop table"})
      end

      assert render(lv) =~ "Conversa"
    end

    test "logged-in user does not crash the page with an arbitrary id", %{conn: conn, workshop: w} do
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      render_click(lv, "toggle_comment_like", %{"type" => "workshop_comment", "id" => "nada"})
      render_click(lv, "delete_comment", %{"id" => "nada", "type" => "workshop_comment"})
      render_click(lv, "toggle_replies", %{"id" => "nada"})
      render_submit(lv, "create_reply", %{"body" => "oi", "parent-id" => "nada"})

      assert render(lv) =~ "Conversa"
    end

    test "reply does not attach to a comment of another workshop", %{conn: conn, workshop: w} do
      alheio = published(insert(:user), %{title: "Outro workshop"})
      {:ok, de_fora} = Engagement.create_workshop_comment(insert(:user), alheio.id, %{body: "lá"})

      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")
      render_submit(lv, "create_reply", %{"body" => "invadindo", "parent-id" => de_fora.id})

      assert Engagement.list_workshop_comments(w.id) == []
      assert Engagement.list_replies(WorkshopCommentQuery, de_fora.id) == []
    end
  end

  describe "liking the workshop" do
    test "curte, conta e descurte", %{conn: conn} do
      w = published(insert(:user), %{})
      {:ok, lv, _} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      render_click(lv, "toggle_workshop_like", %{})
      assert Engagement.count_likes("workshop", w.id) == 1

      render_click(lv, "toggle_workshop_like", %{})
      assert Engagement.count_likes("workshop", w.id) == 0
    end

    test "anonymous visitor does not like it and is sent to signup", %{conn: conn} do
      w = published(insert(:user), %{})
      {:ok, lv, _} = live(conn, ~p"/workshops/#{w.slug}")

      assert {:error, {:redirect, %{to: destination}}} =
               render_click(lv, "toggle_workshop_like", %{})

      assert destination =~ "/signup"
      assert Engagement.count_likes("workshop", w.id) == 0
    end
  end

  describe "notification for the organizer" do
    test "enrollment lights the counter and the link leads to the panel", %{conn: conn} do
      organizer = insert(:user)
      w = published(organizer, %{})
      student = insert(:user)

      {:ok, _} = Workshops.enroll(w, student)

      assert Engagement.unread_count(organizer.id) == 1

      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}/gerenciar")
      assert html =~ "hero-bell"
    end

    test "enrollment notification link points to the panel", %{conn: conn} do
      organizer = insert(:user)
      w = published(organizer, %{})
      {:ok, _} = Workshops.enroll(w, insert(:user))

      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/notifications")

      assert html =~ "se inscreveu no seu workshop"
      assert html =~ "/workshops/#{w.slug}/gerenciar"
    end

    test "workshop comment leads to the public page", %{conn: conn} do
      organizer = insert(:user)
      w = published(organizer, %{})
      {:ok, _} = Engagement.create_workshop_comment(insert(:user), w.id, %{body: "e aí?"})

      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/notifications")

      assert html =~ "comentou no seu workshop"
      assert html =~ "/workshops/#{w.slug}"
    end
  end

  describe "agenda collapsed by program" do
    setup %{conn: conn} do
      owner = insert(:user)
      %{owner: owner, conn: conn}
    end

    test "festival becomes one entry instead of fifteen", ctx do
      workshops =
        for i <- 1..15 do
          published(ctx.owner, %{title: "Itaúnas #{i}", starts_at: at_day(20 + i)})
        end

      {:ok, p} = Workshops.create_program(ctx.owner, %{title: "Festival de Itaúnas"})
      for w <- workshops, do: Workshops.attach_workshop(p, ctx.owner, w.id)
      {:ok, p} = Workshops.publish_program(ctx.owner, p)

      {:ok, _lv, html} = live(log_in_user(ctx.conn, insert(:user)), ~p"/study/workshops")

      assert html =~ "Festival de Itaúnas"
      assert html =~ "Ver programação"
      refute html =~ "Itaúnas 7"
      assert html =~ ~s(id="program-card-#{p.id}")
    end

    test "workshop solto continua na agenda", ctx do
      solto = published(ctx.owner, %{title: "Aulão avulso"})

      {:ok, _lv, html} = live(log_in_user(ctx.conn, insert(:user)), ~p"/study/workshops")

      assert html =~ solto.title
    end

    test "search opens the program and finds the workshop inside", ctx do
      dentro = published(ctx.owner, %{title: "Pisada nordestina", starts_at: at_day(20)})
      {:ok, p} = Workshops.create_program(ctx.owner, %{title: "Festival"})
      {:ok, _} = Workshops.attach_workshop(p, ctx.owner, dentro.id)
      {:ok, _} = Workshops.publish_program(ctx.owner, p)

      {:ok, lv, html} = live(log_in_user(ctx.conn, insert(:user)), ~p"/study/workshops")
      refute html =~ "Pisada nordestina"

      html = render_change(lv, "search_workshops", %{"term" => "pisada"})

      assert html =~ "Pisada nordestina"
    end

    test "counter counts both kinds", ctx do
      published(ctx.owner, %{title: "Solto"})
      dentro = published(ctx.owner, %{title: "Dentro", starts_at: at_day(20)})
      {:ok, p} = Workshops.create_program(ctx.owner, %{title: "Festival"})
      {:ok, _} = Workshops.attach_workshop(p, ctx.owner, dentro.id)
      {:ok, _} = Workshops.publish_program(ctx.owner, p)

      {:ok, _lv, html} = live(log_in_user(ctx.conn, insert(:user)), ~p"/study/workshops")

      assert html =~ "1 workshop · 1 programação"
    end
  end

  describe "collapsed agenda edge cases" do
    setup %{conn: conn} do
      %{owner: insert(:user), conn: conn}
    end

    test "workshop in a draft program stays on the agenda", ctx do
      w = published(ctx.owner, %{title: "Já anunciado no grupo"})
      {:ok, p} = Workshops.create_program(ctx.owner, %{title: "Ainda montando"})
      {:ok, _} = Workshops.attach_workshop(p, ctx.owner, w.id)

      {:ok, _lv, html} = live(log_in_user(ctx.conn, insert(:user)), ~p"/study/workshops")

      assert html =~ "Já anunciado no grupo"
    end

    test "organizer card keeps the count even when collapsed", ctx do
      w = published(ctx.owner, %{title: "Com inscritos", capacity: 1, starts_at: at_day(20)})
      {:ok, _} = Workshops.enroll(w, insert(:user))

      {:ok, p} = Workshops.create_program(ctx.owner, %{title: "Festival"})
      {:ok, _} = Workshops.attach_workshop(p, ctx.owner, w.id)
      {:ok, _} = Workshops.publish_program(ctx.owner, p)

      {:ok, _lv, html} = live(log_in_user(ctx.conn, ctx.owner), ~p"/study/workshops")

      assert html =~ "1 inscrito"
      assert html =~ "Esgotado"
    end

    test "user enrolled in a collapsed workshop sees the mark on the program card", ctx do
      w = published(ctx.owner, %{title: "Dentro", starts_at: at_day(20)})
      student = insert(:user)
      {:ok, _} = Workshops.enroll(w, student)

      {:ok, p} = Workshops.create_program(ctx.owner, %{title: "Festival"})
      {:ok, _} = Workshops.attach_workshop(p, ctx.owner, w.id)
      {:ok, _} = Workshops.publish_program(ctx.owner, p)

      {:ok, _lv, html} = live(log_in_user(ctx.conn, student), ~p"/study/workshops")

      assert html =~ "Você está em 1"
    end

    test "in a search, the workshop names the program it belongs to", ctx do
      dentro = published(ctx.owner, %{title: "Xote nordestino", starts_at: at_day(20)})
      {:ok, p} = Workshops.create_program(ctx.owner, %{title: "Festival de Itaúnas"})
      {:ok, _} = Workshops.attach_workshop(p, ctx.owner, dentro.id)
      {:ok, _} = Workshops.publish_program(ctx.owner, p)

      {:ok, lv, _} = live(log_in_user(ctx.conn, insert(:user)), ~p"/study/workshops")
      html = render_change(lv, "search_workshops", %{"term" => "xote"})

      assert html =~ "Xote nordestino"
      assert html =~ "Festival de Itaúnas"
    end
  end

  describe "agenda: ids de DOM" do
    test "workshop present in both sections does not repeat its id", %{conn: conn} do
      organizer = insert(:user)
      w = published(organizer, %{})

      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/study/workshops")

      assert html =~ ~s(id="organiza-#{w.id}")
      assert html =~ ~s(id="workshop-card-#{w.id}")
    end
  end

  describe "organizer panel: charging" do
    test "free workshop shows no payment control", %{conn: conn} do
      organizer = insert(:user)
      student = insert(:user)
      w = published(organizer, %{price_cents: nil})
      {:ok, _} = Workshops.enroll(w, student)

      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}/gerenciar")

      assert html =~ "inscritos"
      assert html =~ student.name
      refute html =~ "Marcar pago"
      refute html =~ "a receber"
      refute html =~ "Aguardando"
    end

    test "paid workshop shows the total received, zero included", %{conn: conn} do
      organizer = insert(:user)
      student = insert(:user)
      w = published(organizer, %{price_cents: 18_000})
      {:ok, _} = Workshops.enroll(w, student)

      {:ok, lv, html} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}/gerenciar")

      assert html =~ "R$ 0"
      refute html =~ "Gratuito"
      assert html =~ "Marcar pago"

      html = render_click(lv, "set_payment", %{"id" => first_enrollment(w), "status" => "paid"})
      assert html =~ "R$ 180"
    end
  end

  describe "public page (/workshops/:slug)" do
    test "payment data only appears for enrolled users", %{conn: conn} do
      organizer = insert(:user)
      student = insert(:user)
      w = published(organizer, %{price_cents: 8000, payment_info: "Pix 41 99999-0000"})

      {:ok, _lv, anonimo} = live(conn, ~p"/workshops/#{w.slug}")
      refute anonimo =~ "41 99999-0000"
      assert anonimo =~ "R$ 80"

      {:ok, _lv, logged_out} = live(log_in_user(conn, student), ~p"/workshops/#{w.slug}")
      refute logged_out =~ "41 99999-0000"

      {:ok, _} = Workshops.enroll(w, student)
      {:ok, _lv, inscrita} = live(log_in_user(conn, student), ~p"/workshops/#{w.slug}")
      assert inscrita =~ "41 99999-0000"

      {:ok, _lv, owner} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}")
      assert owner =~ "41 99999-0000"
    end

    test "organizer sees the manage button instead of the enroll one", %{conn: conn} do
      organizer = insert(:user)
      w = published(organizer, %{})

      {:ok, _lv, html} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}")

      refute html =~ "Fazer inscrição"
      assert html =~ "Gerenciar inscritos"
    end

    test "anonymous visitor sees the essentials", %{conn: conn} do
      organizer = insert(:user, name: "Tavano Silva")
      w = published(organizer, %{price_cents: 8000})

      {:ok, _lv, html} = live(conn, ~p"/workshops/#{w.slug}")

      assert html =~ "Workshop de sacadas"
      assert html =~ "R$ 80"
      assert html =~ "Tavano Silva"
      assert html =~ "Entrar"
    end

    test "anonymous visitor does not see the names of enrolled users", %{conn: conn} do
      organizer = insert(:user)
      w = published(organizer)
      student = insert(:user, name: "Ana Souza")
      {:ok, _} = Workshops.enroll(w, student)

      {:ok, _lv, html} = live(conn, ~p"/workshops/#{w.slug}")

      refute html =~ "Ana Souza"
      assert html =~ "1 inscrito"
    end

    test "logged-in user sees who is going", %{conn: conn} do
      organizer = insert(:user)
      w = published(organizer)
      {:ok, _} = Workshops.enroll(w, insert(:user, name: "Ana Souza"))

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      assert html =~ "Ana Souza"
    end

    test "inscrever e cancelar", %{conn: conn} do
      organizer = insert(:user)
      w = published(organizer)
      student = insert(:user)

      {:ok, lv, _} = live(log_in_user(conn, student), ~p"/workshops/#{w.slug}")

      html = render_click(lv, "enroll", %{})
      assert html =~ "Inscrição confirmada"
      assert html =~ "Você está inscrito"
      assert Workshops.count_enrollments(w.id) == 1

      html = render_click(lv, "cancel_enrollment", %{})
      assert html =~ "Inscrição cancelada"
      assert Workshops.count_enrollments(w.id) == 0
    end

    test "anonymous visitor is taken to signup when trying to enroll", %{conn: conn} do
      w = published(insert(:user))

      {:ok, lv, _} = live(conn, ~p"/workshops/#{w.slug}")

      assert {:error, {:redirect, %{to: destination}}} = render_click(lv, "enroll", %{})
      assert destination =~ "/signup"
      assert destination =~ w.slug
    end

    test "full workshop shows sold out and blocks enrollment", %{conn: conn} do
      organizer = insert(:user)
      w = published(organizer, %{capacity: 1})
      {:ok, _} = Workshops.enroll(w, insert(:user))

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      assert html =~ "Vagas esgotadas"
      refute html =~ "Fazer inscrição"
    end

    test "unknown slug redirects back to the agenda", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/study/workshops"}}} =
               live(log_in_user(conn, insert(:user)), ~p"/workshops/nao-existe")
    end

    test "public page never carries payment data", %{conn: conn} do
      organizer = insert(:user)
      w = published(organizer)
      student = insert(:user)
      {:ok, _} = Workshops.enroll(w, student)
      {:ok, [row]} = Workshops.list_enrollments_for_organizer(w, organizer)
      {:ok, _} = Workshops.set_payment_status(w, organizer, row.id, :paid)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{w.slug}")

      refute html =~ "Pago"
      refute html =~ "Aguardando"
      refute html =~ "Marcar pago"
    end
  end

  describe "organizer panel (/workshops/:slug/gerenciar)" do
    setup %{conn: conn} do
      organizer = insert(:user)
      w = published(organizer, %{price_cents: 8000})
      student = insert(:user, name: "Ana Souza")
      {:ok, _} = Workshops.enroll(w, student)

      %{conn: conn, organizer: organizer, workshop: w, student: student}
    end

    test "non-organizer is blocked", %{conn: conn, workshop: w, student: student} do
      assert {:error, {:redirect, %{to: "/study/workshops"}}} =
               live(log_in_user(conn, student), ~p"/workshops/#{w.slug}/gerenciar")
    end

    test "not even a site admin enters the payment panel", %{conn: conn, workshop: w} do
      assert {:error, {:redirect, %{to: "/study/workshops"}}} =
               live(log_in_user(conn, insert(:admin)), ~p"/workshops/#{w.slug}/gerenciar")
    end

    test "organizer sees enrolled users and marks payment", %{
      conn: conn,
      organizer: organizer,
      workshop: w
    } do
      {:ok, lv, html} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}/gerenciar")

      assert html =~ "Ana Souza"
      assert html =~ "Só você vê esta tela"
      assert html =~ "Aguardando"

      {:ok, [row]} = Workshops.list_enrollments_for_organizer(w, organizer)
      html = render_click(lv, "set_payment", %{"id" => row.id, "status" => "paid"})

      assert html =~ "Pagamento registrado"
      assert html =~ "R$ 80"
    end

    test "enrollment id from another workshop is rejected", %{
      conn: conn,
      organizer: organizer,
      workshop: w
    } do
      other_owner = insert(:user)
      other = published(other_owner, %{title: "Outro"})
      {:ok, alheia} = Workshops.enroll(other, insert(:user))

      {:ok, lv, _} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}/gerenciar")

      html = render_click(lv, "set_payment", %{"id" => alheia.id, "status" => "paid"})
      assert html =~ "Inscrição não encontrada"

      {:ok, [intacta]} = Workshops.list_enrollments_for_organizer(other, other_owner)
      assert intacta.payment_status == :pending
    end

    test "cancelar preserva os inscritos", %{conn: conn, organizer: organizer, workshop: w} do
      {:ok, lv, _} = live(log_in_user(conn, organizer), ~p"/workshops/#{w.slug}/gerenciar")

      html = render_click(lv, "cancel_workshop", %{})

      assert html =~ "Workshop cancelado"
      assert Workshops.count_enrollments(w.id) == 1
    end
  end

  describe "creating a workshop (/study/workshops/novo)" do
    test "creates and publishes", %{conn: conn} do
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

      assert {:error, {:redirect, %{to: destination}}} =
               lv
               |> form("#workshop-form", %{"workshop" => params})
               |> render_submit(%{"publish" => "true"})

      assert destination =~ "/workshops/aulao-de-forro-"

      assert [w] = Workshops.list_for_organizer(user.id)
      assert w.status == :published
      assert w.price_cents == 8000
      assert w.capacity == 50
    end

    test "saving a draft does not publish", %{conn: conn} do
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

    test "validation error shows a message and preserves the typed text", %{conn: conn} do
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

    test "another user does not edit someone else's workshop", %{conn: conn} do
      w = published(insert(:user))

      assert {:error, {:redirect, %{to: "/study/workshops"}}} =
               live(log_in_user(conn, insert(:user)), ~p"/study/workshops/#{w.slug}/editar")
    end
  end
end
