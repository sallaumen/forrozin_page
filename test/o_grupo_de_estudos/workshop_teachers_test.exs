defmodule OGrupoDeEstudos.WorkshopTeachersTest do
  @moduledoc """
  Teaching and organizing are separate roles: the creator is not a teacher by
  default. A workshop takes one or two teachers, and a teacher may have no
  account on the site.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  setup do
    owner = insert(:user, name: "Produtor do Evento")
    %{owner: owner, workshop: insert(:workshop, organizer: owner)}
  end

  describe "who teaches the class" do
    test "teacher with an account comes with photo and profile", ctx do
      teacher = insert(:user, name: "Marina Costa", avatar_path: "/uploads/avatars/m/1.jpg")

      assert {:ok, _} =
               Workshops.set_teachers(ctx.workshop, ctx.owner, [%{user_id: teacher.id}])

      assert [teacher] = Workshops.list_teachers(ctx.workshop.id)
      assert teacher.name == "Marina Costa"
      assert teacher.username == teacher.username
      assert teacher.avatar_path == "/uploads/avatars/m/1.jpg"
    end

    test "teacher without an account comes as a plain name", ctx do
      assert {:ok, _} =
               Workshops.set_teachers(ctx.workshop, ctx.owner, [%{display_name: "Zé de Itaúnas"}])

      assert [teacher] = Workshops.list_teachers(ctx.workshop.id)
      assert teacher.name == "Zé de Itaúnas"
      assert is_nil(teacher.username)
    end

    test "two teachers are kept in the given order", ctx do
      ela = insert(:user, name: "Marina Costa")

      assert {:ok, _} =
               Workshops.set_teachers(ctx.workshop, ctx.owner, [
                 %{user_id: ela.id},
                 %{display_name: "Zé de Itaúnas"}
               ])

      assert [first, second] = Workshops.list_teachers(ctx.workshop.id)
      assert first.name == "Marina Costa"
      assert second.name == "Zé de Itaúnas"
    end

    test "more than two teachers is rejected", ctx do
      assert {:error, :too_many_teachers} =
               Workshops.set_teachers(ctx.workshop, ctx.owner, [
                 %{display_name: "Um"},
                 %{display_name: "Dois"},
                 %{display_name: "Três"}
               ])
    end

    test "organizer does not become a teacher by default", ctx do
      assert Workshops.list_teachers(ctx.workshop.id) == []
    end

    test "organizer can list themselves as a teacher", ctx do
      assert {:ok, _} =
               Workshops.set_teachers(ctx.workshop, ctx.owner, [%{user_id: ctx.owner.id}])

      assert [teacher] = Workshops.list_teachers(ctx.workshop.id)
      assert teacher.name == "Produtor do Evento"
    end
  end

  describe "changing teachers later" do
    test "plain name becomes an account when the person signs up", ctx do
      {:ok, _} =
        Workshops.set_teachers(ctx.workshop, ctx.owner, [%{display_name: "Zé de Itaúnas"}])

      ze = insert(:user, name: "José de Itaúnas")

      assert {:ok, _} = Workshops.set_teachers(ctx.workshop, ctx.owner, [%{user_id: ze.id}])

      assert [teacher] = Workshops.list_teachers(ctx.workshop.id)
      assert teacher.username == ze.username
    end

    test "removes every teacher", ctx do
      {:ok, _} = Workshops.set_teachers(ctx.workshop, ctx.owner, [%{display_name: "Alguém"}])

      assert {:ok, _} = Workshops.set_teachers(ctx.workshop, ctx.owner, [])
      assert Workshops.list_teachers(ctx.workshop.id) == []
    end

    test "outsider does not change the teachers", ctx do
      assert {:error, :unauthorized} =
               Workshops.set_teachers(ctx.workshop, insert(:user), [%{display_name: "Eu"}])
    end

    test "co-organizer changes the teachers", ctx do
      partner = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.owner, partner.id)

      assert {:ok, _} =
               Workshops.set_teachers(ctx.workshop, partner, [%{display_name: "Alguém"}])
    end
  end

  describe "entries that make no sense" do
    test "entry with neither account nor name is rejected", ctx do
      assert {:error, :invalid_teacher} = Workshops.set_teachers(ctx.workshop, ctx.owner, [%{}])
    end

    test "blank name is rejected", ctx do
      assert {:error, :invalid_teacher} =
               Workshops.set_teachers(ctx.workshop, ctx.owner, [%{display_name: "   "}])
    end

    test "account that does not exist is rejected", ctx do
      assert {:error, :invalid_teacher} =
               Workshops.set_teachers(ctx.workshop, ctx.owner, [%{user_id: Ecto.UUID.generate()}])
    end
  end
end
