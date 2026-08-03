defmodule OGrupoDeEstudos.Engagement.WorkshopCommentsTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Engagement.Comments.{WorkshopComment, WorkshopCommentQuery}
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops

  defp workshop_publicado(organizer) do
    {:ok, workshop} =
      Workshops.create_workshop(organizer, %{
        title: "Aulão de forró",
        description: "Vamos dançar.",
        starts_at: DateTime.add(DateTime.utc_now(), 10, :day) |> DateTime.truncate(:second)
      })

    {:ok, workshop} = Workshops.publish_workshop(organizer, workshop)
    workshop
  end

  setup do
    organizer = insert(:user)
    %{organizer: organizer, workshop: workshop_publicado(organizer)}
  end

  describe "create_workshop_comment/3" do
    test "cria comentário raiz", %{workshop: workshop} do
      autor = insert(:user)

      assert {:ok, comment} =
               Engagement.create_workshop_comment(autor, workshop.id, %{body: "Vou sim!"})

      assert comment.body == "Vou sim!"
      assert comment.workshop_id == workshop.id
      assert comment.user_id == autor.id
      assert is_nil(comment.parent_workshop_comment_id)
    end

    test "corpo vazio não passa", %{workshop: workshop} do
      assert {:error, %Ecto.Changeset{}} =
               Engagement.create_workshop_comment(insert(:user), workshop.id, %{body: ""})
    end

    test "resposta incrementa o reply_count do pai pelo trigger", %{workshop: workshop} do
      {:ok, raiz} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{body: "Que horas?"})

      {:ok, _resposta} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{
          body: "14h",
          parent_workshop_comment_id: raiz.id
        })

      assert Repo.get!(WorkshopComment, raiz.id).reply_count == 1
    end
  end

  describe "list_workshop_comments/2" do
    test "traz só as raízes do workshop, mais curtido primeiro", %{workshop: workshop} do
      outro = workshop_publicado(insert(:user))

      {:ok, popular} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{body: "popular"})

      {:ok, _simples} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{body: "simples"})

      {:ok, _resposta} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{
          body: "resposta",
          parent_workshop_comment_id: popular.id
        })

      {:ok, _alheio} =
        Engagement.create_workshop_comment(insert(:user), outro.id, %{body: "alheio"})

      Engagement.toggle_like(insert(:user).id, "workshop_comment", popular.id)

      corpos = workshop.id |> Engagement.list_workshop_comments() |> Enum.map(& &1.body)

      assert corpos == ["popular", "simples"]
    end
  end

  describe "like em comentário de workshop" do
    test "o trigger mantém o like_count da linha", %{workshop: workshop} do
      {:ok, comment} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{body: "boa!"})

      quem_curte = insert(:user)

      assert {:ok, :liked} =
               Engagement.toggle_like(quem_curte.id, "workshop_comment", comment.id)

      assert Repo.get!(WorkshopComment, comment.id).like_count == 1

      assert {:ok, :unliked} =
               Engagement.toggle_like(quem_curte.id, "workshop_comment", comment.id)

      assert Repo.get!(WorkshopComment, comment.id).like_count == 0
    end

    test "notifica o autor do comentário, e a notificação tem parent_id", %{workshop: workshop} do
      autor = insert(:user)

      {:ok, comment} =
        Engagement.create_workshop_comment(autor, workshop.id, %{body: "boa!"})

      {:ok, :liked} = Engagement.toggle_like(insert(:user).id, "workshop_comment", comment.id)

      # parent_id é NOT NULL: sem a cláusula no Dispatcher o insert falharia e
      # o SafeDispatch engoliria o erro, deixando o like sem notificação.
      assert [notificacao] = Repo.all(from n in Notification, where: n.user_id == ^autor.id)
      assert notificacao.action == :liked_comment
      assert notificacao.target_type == "workshop_comment"
      assert notificacao.target_id == comment.id
      assert notificacao.parent_type == "workshop"
      assert notificacao.parent_id == workshop.id
    end
  end

  describe "notificação de comentário" do
    test "comentário raiz avisa o organizador", %{organizer: organizer, workshop: workshop} do
      visitante = insert(:user)

      {:ok, comment} =
        Engagement.create_workshop_comment(visitante, workshop.id, %{body: "vou!"})

      assert [notificacao] = Repo.all(from n in Notification, where: n.user_id == ^organizer.id)
      assert notificacao.action == :workshop_commented
      assert notificacao.actor_id == visitante.id
      assert notificacao.target_id == comment.id
      assert notificacao.parent_type == "workshop"
      assert notificacao.parent_id == workshop.id
    end

    test "organizador comentando no próprio workshop não se notifica", %{
      organizer: organizer,
      workshop: workshop
    } do
      {:ok, _} = Engagement.create_workshop_comment(organizer, workshop.id, %{body: "oi"})

      assert Repo.all(from n in Notification, where: n.user_id == ^organizer.id) == []
    end

    test "resposta avisa o autor do comentário, não o organizador", %{
      organizer: organizer,
      workshop: workshop
    } do
      autor = insert(:user)

      {:ok, raiz} =
        Engagement.create_workshop_comment(autor, workshop.id, %{body: "que horas?"})

      Repo.delete_all(Notification)

      {:ok, _resposta} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{
          body: "14h",
          parent_workshop_comment_id: raiz.id
        })

      assert [notificacao] = Repo.all(from n in Notification, where: n.user_id == ^autor.id)
      assert notificacao.action == :replied_comment
      assert Repo.all(from n in Notification, where: n.user_id == ^organizer.id) == []
    end
  end

  describe "delete_workshop_comment/2" do
    test "autor apaga o próprio comentário", %{workshop: workshop} do
      autor = insert(:user)

      {:ok, comment} =
        Engagement.create_workshop_comment(autor, workshop.id, %{body: "erro de digitação"})

      assert {:ok, _} = Engagement.delete_workshop_comment(autor, comment)
      assert Engagement.list_workshop_comments(workshop.id) == []
    end

    test "estranho não apaga comentário alheio", %{workshop: workshop} do
      {:ok, comment} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{body: "meu"})

      assert {:error, :unauthorized} =
               Engagement.delete_workshop_comment(insert(:user), comment)
    end

    test "comentário com resposta vira lápide, e a resposta não vira raiz solta", %{
      workshop: workshop
    } do
      autor = insert(:user)

      {:ok, raiz} = Engagement.create_workshop_comment(autor, workshop.id, %{body: "original"})

      {:ok, resposta} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{
          body: "resposta",
          parent_workshop_comment_id: raiz.id
        })

      assert {:ok, _} = Engagement.delete_workshop_comment(autor, raiz)

      # A raiz continua na tabela como lápide: o hard delete nulificaria o FK
      # da resposta, que reapareceria como raiz sem contexto nenhum.
      lapide = Repo.get!(WorkshopComment, raiz.id)
      assert lapide.body == "[comentário removido]"
      refute is_nil(lapide.deleted_at)

      assert Repo.get!(WorkshopComment, resposta.id).parent_workshop_comment_id == raiz.id
      assert Engagement.list_workshop_comments(workshop.id) == []
    end

    test "o reply_count é lido do banco, não do struct em memória", %{workshop: workshop} do
      autor = insert(:user)

      {:ok, raiz} = Engagement.create_workshop_comment(autor, workshop.id, %{body: "original"})

      # `raiz` foi carregado antes da resposta existir: reply_count == 0 nele.
      {:ok, resposta} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{
          body: "chegou depois",
          parent_workshop_comment_id: raiz.id
        })

      assert raiz.reply_count == 0
      assert {:ok, _} = Engagement.delete_workshop_comment(autor, raiz)

      # Sem a leitura fresca, o hard delete apagaria a raiz e soltaria a resposta.
      assert Repo.get(WorkshopComment, raiz.id)
      assert Repo.get!(WorkshopComment, resposta.id).parent_workshop_comment_id == raiz.id
    end
  end

  describe "list_replies/3" do
    test "traz as respostas de um comentário", %{workshop: workshop} do
      {:ok, raiz} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{body: "?"})

      {:ok, _} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{
          body: "!",
          parent_workshop_comment_id: raiz.id
        })

      assert [resposta] = Engagement.list_replies(WorkshopCommentQuery, raiz.id)
      assert resposta.body == "!"
    end
  end
end
