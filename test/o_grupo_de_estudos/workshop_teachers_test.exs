defmodule OGrupoDeEstudos.WorkshopTeachersTest do
  @moduledoc """
  Quem dá a aula deixa de ser quem criou por acidente.

  O formulário não tinha campo de professor: o criador virava professor por
  omissão. Isso quebra no caso real de alguém organizar a aula de outra
  pessoa, que é o mais comum quando se produz um evento.

  Workshop de forró quase sempre é dado por duas pessoas, e professor de fora
  nem sempre tem conta no site. As duas coisas precisam caber.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  setup do
    dono = insert(:user, name: "Produtor do Evento")
    %{dono: dono, workshop: insert(:workshop, organizer: dono)}
  end

  describe "quem dá a aula" do
    test "com conta no site, aparece com foto e perfil", ctx do
      professora = insert(:user, name: "Marina Costa", avatar_path: "/uploads/avatars/m/1.jpg")

      assert {:ok, _} =
               Workshops.set_teachers(ctx.workshop, ctx.dono, [%{user_id: professora.id}])

      assert [professor] = Workshops.list_teachers(ctx.workshop.id)
      assert professor.name == "Marina Costa"
      assert professor.username == professora.username
      assert professor.avatar_path == "/uploads/avatars/m/1.jpg"
    end

    test "sem conta, entra só o nome", ctx do
      assert {:ok, _} =
               Workshops.set_teachers(ctx.workshop, ctx.dono, [%{display_name: "Zé de Itaúnas"}])

      assert [professor] = Workshops.list_teachers(ctx.workshop.id)
      assert professor.name == "Zé de Itaúnas"
      assert is_nil(professor.username)
    end

    test "o casal: dois professores, na ordem informada", ctx do
      ela = insert(:user, name: "Marina Costa")

      assert {:ok, _} =
               Workshops.set_teachers(ctx.workshop, ctx.dono, [
                 %{user_id: ela.id},
                 %{display_name: "Zé de Itaúnas"}
               ])

      assert [primeira, segundo] = Workshops.list_teachers(ctx.workshop.id)
      assert primeira.name == "Marina Costa"
      assert segundo.name == "Zé de Itaúnas"
    end

    test "mais de dois é recusado: workshop é de um ou dois", ctx do
      assert {:error, :too_many_teachers} =
               Workshops.set_teachers(ctx.workshop, ctx.dono, [
                 %{display_name: "Um"},
                 %{display_name: "Dois"},
                 %{display_name: "Três"}
               ])
    end

    test "quem organiza NÃO vira professor sozinho", ctx do
      # Produzir a aula de outra pessoa é o caso real; assumir que quem criou
      # dá a aula era o bug.
      assert Workshops.list_teachers(ctx.workshop.id) == []
    end

    test "quem organiza pode se colocar como professor, quando é o caso", ctx do
      assert {:ok, _} = Workshops.set_teachers(ctx.workshop, ctx.dono, [%{user_id: ctx.dono.id}])

      assert [professor] = Workshops.list_teachers(ctx.workshop.id)
      assert professor.name == "Produtor do Evento"
    end
  end

  describe "trocar depois" do
    test "o nome escrito vira conta quando a pessoa se cadastra", ctx do
      {:ok, _} =
        Workshops.set_teachers(ctx.workshop, ctx.dono, [%{display_name: "Zé de Itaúnas"}])

      ze = insert(:user, name: "José de Itaúnas")

      assert {:ok, _} = Workshops.set_teachers(ctx.workshop, ctx.dono, [%{user_id: ze.id}])

      assert [professor] = Workshops.list_teachers(ctx.workshop.id)
      assert professor.username == ze.username
    end

    test "dá para tirar todo mundo", ctx do
      {:ok, _} = Workshops.set_teachers(ctx.workshop, ctx.dono, [%{display_name: "Alguém"}])

      assert {:ok, _} = Workshops.set_teachers(ctx.workshop, ctx.dono, [])
      assert Workshops.list_teachers(ctx.workshop.id) == []
    end

    test "estranho não mexe em quem dá a aula", ctx do
      assert {:error, :unauthorized} =
               Workshops.set_teachers(ctx.workshop, insert(:user), [%{display_name: "Eu"}])
    end

    test "co-organizador mexe", ctx do
      parceiro = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.dono, parceiro.id)

      assert {:ok, _} =
               Workshops.set_teachers(ctx.workshop, parceiro, [%{display_name: "Alguém"}])
    end
  end

  describe "entradas que não fazem sentido" do
    test "sem conta e sem nome não entra", ctx do
      assert {:error, :invalid_teacher} = Workshops.set_teachers(ctx.workshop, ctx.dono, [%{}])
    end

    test "nome em branco não entra", ctx do
      assert {:error, :invalid_teacher} =
               Workshops.set_teachers(ctx.workshop, ctx.dono, [%{display_name: "   "}])
    end

    test "conta que não existe não entra", ctx do
      assert {:error, :invalid_teacher} =
               Workshops.set_teachers(ctx.workshop, ctx.dono, [%{user_id: Ecto.UUID.generate()}])
    end
  end
end
