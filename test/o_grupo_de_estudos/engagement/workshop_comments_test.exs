defmodule OGrupoDeEstudos.Engagement.WorkshopCommentsTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Engagement.Comments.WorkshopComment
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops

  defp published_workshop(organizer) do
    {:ok, workshop} =
      Workshops.create_workshop(organizer, %{
        title: "Aulão de forró",
        description: "Vamos dançar.",
        starts_at: DateTime.add(DateTime.utc_now(), 10, :day) |> DateTime.truncate(:second)
      })

    {:ok, workshop} = Workshops.publish_workshop(organizer, workshop)
    workshop
  end

  defp access(workshop, user), do: Workshops.access_for(workshop, user)

  setup do
    organizer = insert(:user)
    %{organizer: organizer, workshop: published_workshop(organizer)}
  end

  describe "create_workshop_comment/3" do
    test "creates a root comment", %{workshop: workshop} do
      author = insert(:user)

      assert {:ok, comment} =
               Engagement.create_workshop_comment(author, workshop.id, %{body: "Vou sim!"})

      assert comment.body == "Vou sim!"
      assert comment.workshop_id == workshop.id
      assert comment.user_id == author.id
      assert is_nil(comment.parent_workshop_comment_id)
    end

    test "rejects an empty body", %{workshop: workshop} do
      assert {:error, %Ecto.Changeset{}} =
               Engagement.create_workshop_comment(insert(:user), workshop.id, %{body: ""})
    end

    test "reply increments the parent reply_count through the trigger", %{workshop: workshop} do
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
    test "returns only the workshop roots, most liked first", %{workshop: workshop} do
      other = published_workshop(insert(:user))

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
        Engagement.create_workshop_comment(insert(:user), other.id, %{body: "alheio"})

      Engagement.toggle_like(insert(:user).id, "workshop_comment", popular.id)

      corpos = workshop.id |> Engagement.list_workshop_comments() |> Enum.map(& &1.body)

      assert corpos == ["popular", "simples"]
    end
  end

  describe "liking a workshop comment" do
    test "trigger keeps the like_count of the row", %{workshop: workshop} do
      {:ok, comment} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{body: "boa!"})

      liker = insert(:user)

      assert {:ok, :liked} =
               Engagement.toggle_like(liker.id, "workshop_comment", comment.id)

      assert Repo.get!(WorkshopComment, comment.id).like_count == 1

      assert {:ok, :unliked} =
               Engagement.toggle_like(liker.id, "workshop_comment", comment.id)

      assert Repo.get!(WorkshopComment, comment.id).like_count == 0
    end

    test "notifies the comment author and the notification carries parent_id", %{
      workshop: workshop
    } do
      author = insert(:user)

      {:ok, comment} =
        Engagement.create_workshop_comment(author, workshop.id, %{body: "boa!"})

      {:ok, :liked} = Engagement.toggle_like(insert(:user).id, "workshop_comment", comment.id)

      assert [notification] = Repo.all(from n in Notification, where: n.user_id == ^author.id)
      assert notification.action == :liked_comment
      assert notification.target_type == "workshop_comment"
      assert notification.target_id == comment.id
      assert notification.parent_type == "workshop"
      assert notification.parent_id == workshop.id
    end
  end

  describe "comment notification" do
    test "root comment notifies the organizer", %{organizer: organizer, workshop: workshop} do
      visitante = insert(:user)

      {:ok, comment} =
        Engagement.create_workshop_comment(visitante, workshop.id, %{body: "vou!"})

      assert [notification] = Repo.all(from n in Notification, where: n.user_id == ^organizer.id)
      assert notification.action == :workshop_commented
      assert notification.actor_id == visitante.id
      assert notification.target_id == comment.id
      assert notification.parent_type == "workshop"
      assert notification.parent_id == workshop.id
    end

    test "organizer commenting on their own workshop does not notify themselves", %{
      organizer: organizer,
      workshop: workshop
    } do
      {:ok, _} = Engagement.create_workshop_comment(organizer, workshop.id, %{body: "oi"})

      assert Repo.all(from n in Notification, where: n.user_id == ^organizer.id) == []
    end

    test "reply notifies the comment author, not the organizer", %{
      organizer: organizer,
      workshop: workshop
    } do
      author = insert(:user)

      {:ok, raiz} =
        Engagement.create_workshop_comment(author, workshop.id, %{body: "que horas?"})

      Repo.delete_all(Notification)

      {:ok, _resposta} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{
          body: "14h",
          parent_workshop_comment_id: raiz.id
        })

      assert [notification] = Repo.all(from n in Notification, where: n.user_id == ^author.id)
      assert notification.action == :replied_comment
      assert Repo.all(from n in Notification, where: n.user_id == ^organizer.id) == []
    end
  end

  describe "delete_workshop_comment/3" do
    test "author deletes their own comment", %{workshop: workshop} do
      author = insert(:user)

      {:ok, comment} =
        Engagement.create_workshop_comment(author, workshop.id, %{body: "erro de digitação"})

      assert {:ok, _} =
               Engagement.delete_workshop_comment(author, comment, access(workshop, author))

      assert Engagement.list_workshop_comments(workshop.id) == []
    end

    test "outsider does not delete someone else's comment", %{workshop: workshop} do
      {:ok, comment} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{body: "meu"})

      outsider = insert(:user)

      assert {:error, :unauthorized} =
               Engagement.delete_workshop_comment(outsider, comment, access(workshop, outsider))
    end

    test "whoever organizes takes down what someone else wrote", %{
      organizer: organizer,
      workshop: workshop
    } do
      {:ok, comment} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{body: "propaganda"})

      assert {:ok, _} =
               Engagement.delete_workshop_comment(organizer, comment, access(workshop, organizer))

      assert Engagement.list_workshop_comments(workshop.id) == []
    end

    test "comment with a reply becomes a tombstone and the reply does not turn into a loose root",
         %{
           workshop: workshop
         } do
      author = insert(:user)

      {:ok, raiz} = Engagement.create_workshop_comment(author, workshop.id, %{body: "original"})

      {:ok, resposta} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{
          body: "resposta",
          parent_workshop_comment_id: raiz.id
        })

      assert {:ok, _} = Engagement.delete_workshop_comment(author, raiz, access(workshop, author))

      lapide = Repo.get!(WorkshopComment, raiz.id)
      assert lapide.body == "[comentário removido]"
      refute is_nil(lapide.deleted_at)

      assert Repo.get!(WorkshopComment, resposta.id).parent_workshop_comment_id == raiz.id
      assert Engagement.list_workshop_comments(workshop.id) == []
    end

    test "reply_count is read from the database, not from the in-memory struct", %{
      workshop: workshop
    } do
      author = insert(:user)

      {:ok, raiz} = Engagement.create_workshop_comment(author, workshop.id, %{body: "original"})

      {:ok, resposta} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{
          body: "chegou depois",
          parent_workshop_comment_id: raiz.id
        })

      assert raiz.reply_count == 0
      assert {:ok, _} = Engagement.delete_workshop_comment(author, raiz, access(workshop, author))

      assert Repo.get(WorkshopComment, raiz.id)
      assert Repo.get!(WorkshopComment, resposta.id).parent_workshop_comment_id == raiz.id
    end
  end

  describe "comment replies" do
    test "returns the replies of a comment", %{workshop: workshop} do
      {:ok, raiz} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{body: "?"})

      {:ok, _} =
        Engagement.create_workshop_comment(insert(:user), workshop.id, %{
          body: "!",
          parent_workshop_comment_id: raiz.id
        })

      assert [resposta] = Engagement.list_workshop_comment_replies(raiz.id)
      assert resposta.body == "!"
    end
  end
end
