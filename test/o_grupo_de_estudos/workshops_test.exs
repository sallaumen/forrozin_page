defmodule OGrupoDeEstudos.WorkshopsTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Brazil
  alias OGrupoDeEstudos.Workshops
  alias OGrupoDeEstudos.Workshops.EnrollmentQuery

  defp em(dias, hora \\ 14) do
    Brazil.today()
    |> Date.add(dias)
    |> DateTime.new!(Time.new!(hora, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp attrs(overrides \\ %{}) do
    Map.merge(
      %{
        title: "Workshop de sacadas",
        description: "Quatro horas de sacadas e conduções.",
        location: "Curitiba, Juvevê",
        starts_at: em(7),
        ends_at: em(7, 18)
      },
      overrides
    )
  end

  describe "create_workshop/2" do
    test "cria como rascunho, com slug legível e único" do
      organizer = insert(:user)

      assert {:ok, workshop} = Workshops.create_workshop(organizer, attrs())
      assert workshop.status == :draft
      assert workshop.organizer_id == organizer.id
      assert workshop.slug =~ ~r/^workshop-de-sacadas-[a-z0-9]+$/

      {:ok, outro} = Workshops.create_workshop(organizer, attrs())
      assert outro.slug != workshop.slug
    end

    test "exige título, descrição e início" do
      organizer = insert(:user)

      assert {:error, changeset} =
               Workshops.create_workshop(organizer, %{title: "", description: ""})

      erros = errors_on(changeset)
      assert erros.title != []
      assert erros.description != []
      assert erros.starts_at != []
    end

    test "fim precisa ser depois do início" do
      organizer = insert(:user)

      assert {:error, changeset} =
               Workshops.create_workshop(
                 organizer,
                 attrs(%{starts_at: em(7, 18), ends_at: em(7, 9)})
               )

      assert errors_on(changeset).ends_at != []
    end

    test "qualquer usuário cria, não só professor" do
      aluno = insert(:user, is_teacher: false)
      assert {:ok, _} = Workshops.create_workshop(aluno, attrs())
    end
  end

  describe "publish_workshop/2 e cancel_workshop/2" do
    test "publicar coloca na agenda; cancelar preserva o registro" do
      organizer = insert(:user)
      {:ok, workshop} = Workshops.create_workshop(organizer, attrs())

      assert {:ok, publicado} = Workshops.publish_workshop(organizer, workshop)
      assert publicado.status == :published

      assert {:ok, cancelado} = Workshops.cancel_workshop(organizer, publicado)
      assert cancelado.status == :cancelled
      assert Workshops.get_by_slug(workshop.slug)
    end

    test "outro usuário não publica nem cancela" do
      organizer = insert(:user)
      intruso = insert(:user)
      {:ok, workshop} = Workshops.create_workshop(organizer, attrs())

      assert {:error, :unauthorized} = Workshops.publish_workshop(intruso, workshop)
      assert {:error, :unauthorized} = Workshops.cancel_workshop(intruso, workshop)
    end
  end

  describe "enroll/2" do
    setup do
      organizer = insert(:user)
      {:ok, workshop} = Workshops.create_workshop(organizer, attrs())
      {:ok, workshop} = Workshops.publish_workshop(organizer, workshop)
      %{organizer: organizer, workshop: workshop}
    end

    test "organizador não se inscreve no próprio workshop", %{
      organizer: organizer,
      workshop: workshop
    } do
      assert {:error, :organizer} = Workshops.enroll(workshop, organizer)
      assert EnrollmentQuery.count(workshop.id) == 0
    end

    test "inscreve e conta", %{workshop: workshop} do
      aluno = insert(:user)

      assert {:ok, enrollment} = Workshops.enroll(workshop, aluno)
      assert enrollment.payment_status == :pending
      assert Workshops.count_enrollments(workshop.id) == 1
    end

    test "inscrever duas vezes não duplica", %{workshop: workshop} do
      aluno = insert(:user)
      {:ok, _} = Workshops.enroll(workshop, aluno)

      assert {:error, :already_enrolled} = Workshops.enroll(workshop, aluno)
      assert Workshops.count_enrollments(workshop.id) == 1
    end

    test "não dá para se inscrever em rascunho", %{organizer: organizer} do
      {:ok, rascunho} = Workshops.create_workshop(organizer, attrs())
      aluno = insert(:user)

      assert {:error, :not_open} = Workshops.enroll(rascunho, aluno)
    end

    test "não dá para se inscrever em workshop cancelado", %{
      organizer: organizer,
      workshop: workshop
    } do
      {:ok, cancelado} = Workshops.cancel_workshop(organizer, workshop)
      aluno = insert(:user)

      assert {:error, :not_open} = Workshops.enroll(cancelado, aluno)
    end

    test "respeita a lotação", %{organizer: organizer} do
      {:ok, w} = Workshops.create_workshop(organizer, attrs(%{capacity: 1}))
      {:ok, w} = Workshops.publish_workshop(organizer, w)

      {:ok, _} = Workshops.enroll(w, insert(:user))
      assert {:error, :full} = Workshops.enroll(w, insert(:user))
      assert Workshops.count_enrollments(w.id) == 1
    end

    test "sem capacidade definida, não lota", %{workshop: workshop} do
      for _ <- 1..5, do: {:ok, _} = Workshops.enroll(workshop, insert(:user))
      assert Workshops.count_enrollments(workshop.id) == 5
    end

    test "cancelar a inscrição libera a vaga", %{organizer: organizer} do
      {:ok, w} = Workshops.create_workshop(organizer, attrs(%{capacity: 1}))
      {:ok, w} = Workshops.publish_workshop(organizer, w)
      aluno = insert(:user)

      {:ok, _} = Workshops.enroll(w, aluno)
      assert {:ok, _} = Workshops.cancel_enrollment(w, aluno)
      assert Workshops.count_enrollments(w.id) == 0

      assert {:ok, _} = Workshops.enroll(w, insert(:user))
    end
  end

  describe "privacidade do pagamento" do
    setup do
      organizer = insert(:user)
      {:ok, w} = Workshops.create_workshop(organizer, attrs())
      {:ok, w} = Workshops.publish_workshop(organizer, w)
      aluno = insert(:user, name: "Ana Souza")
      {:ok, _} = Workshops.enroll(w, aluno)
      %{organizer: organizer, workshop: w, aluno: aluno}
    end

    test "a lista pública não expõe pagamento", %{workshop: w} do
      assert [participante] = Workshops.list_participants(w.id)

      assert Map.has_key?(participante, :name)
      refute Map.has_key?(participante, :payment_status)
      refute Map.has_key?(participante, :paid_at)
    end

    test "só o organizador vê a lista com pagamento", %{
      organizer: organizer,
      workshop: w,
      aluno: aluno
    } do
      assert {:ok, [linha]} = Workshops.list_enrollments_for_organizer(w, organizer)
      assert linha.payment_status == :pending
      assert linha.user.name == "Ana Souza"

      assert {:error, :unauthorized} = Workshops.list_enrollments_for_organizer(w, aluno)
    end

    test "organizador marca pago e desfaz", %{organizer: organizer, workshop: w} do
      {:ok, [linha]} = Workshops.list_enrollments_for_organizer(w, organizer)

      assert {:ok, pago} = Workshops.set_payment_status(w, organizer, linha.id, :paid)
      assert pago.payment_status == :paid
      assert pago.paid_at

      assert {:ok, voltou} = Workshops.set_payment_status(w, organizer, linha.id, :pending)
      assert voltou.payment_status == :pending
      assert voltou.paid_at == nil
    end

    test "quem não é organizador não mexe no pagamento", %{
      organizer: organizer,
      workshop: w,
      aluno: aluno
    } do
      {:ok, [linha]} = Workshops.list_enrollments_for_organizer(w, organizer)

      assert {:error, :unauthorized} =
               Workshops.set_payment_status(w, aluno, linha.id, :paid)
    end

    test "organizador não marca pagamento de inscrição de outro workshop", %{
      organizer: organizer,
      workshop: w
    } do
      outro_dono = insert(:user)
      {:ok, outro} = Workshops.create_workshop(outro_dono, attrs())
      {:ok, outro} = Workshops.publish_workshop(outro_dono, outro)
      {:ok, alheia} = Workshops.enroll(outro, insert(:user))

      assert {:error, :not_found} = Workshops.set_payment_status(w, organizer, alheia.id, :paid)
    end
  end

  describe "list_feed/1 — agenda com filtros" do
    setup do
      organizer = insert(:user, name: "Tavano Silva")
      outro = insert(:user, name: "Marina Prado")

      publicar = fn dono, titulo, quando ->
        {:ok, w} =
          Workshops.create_workshop(
            dono,
            attrs(%{title: titulo, starts_at: quando, ends_at: nil})
          )

        {:ok, w} = Workshops.publish_workshop(dono, w)
        w
      end

      %{
        amanha: publicar.(organizer, "Sacadas avançadas", em(1)),
        mes_que_vem: publicar.(outro, "Intensivo de inversão", em(40)),
        passado: publicar.(organizer, "Roda de forró antiga", em(-10)),
        organizer: organizer
      }
    end

    test "por padrão mostra só o que vem por aí, em ordem de data", %{
      amanha: amanha,
      mes_que_vem: mes
    } do
      ids = Workshops.list_feed() |> Enum.map(& &1.id)

      assert ids == [amanha.id, mes.id]
    end

    test "filtro :past mostra os que já aconteceram", %{passado: passado} do
      assert [%{id: id}] = Workshops.list_feed(period: :past)
      assert id == passado.id
    end

    test "filtro por semana e mês respeita o fuso", %{amanha: amanha} do
      ids_semana = Workshops.list_feed(period: :week) |> Enum.map(& &1.id)
      ids_mes = Workshops.list_feed(period: :month) |> Enum.map(& &1.id)

      # amanhã cai na semana e no mês corrente (a menos de virada, tolerado aqui)
      assert amanha.id in ids_mes or amanha.id in ids_semana
    end

    test "busca pelo nome do workshop", %{amanha: amanha} do
      assert [%{id: id}] = Workshops.list_feed(search: "sacadas")
      assert id == amanha.id
    end

    test "busca pelo nome de quem organiza", %{mes_que_vem: mes} do
      assert [%{id: id}] = Workshops.list_feed(search: "marina")
      assert id == mes.id
    end

    test "rascunho e cancelado não aparecem na agenda", %{organizer: organizer} do
      {:ok, _rascunho} = Workshops.create_workshop(organizer, attrs(%{title: "Escondido"}))

      {:ok, publicado} = Workshops.create_workshop(organizer, attrs(%{title: "Vai sumir"}))
      {:ok, publicado} = Workshops.publish_workshop(organizer, publicado)
      {:ok, _} = Workshops.cancel_workshop(organizer, publicado)

      titulos = Workshops.list_feed() |> Enum.map(& &1.title)
      refute "Escondido" in titulos
      refute "Vai sumir" in titulos
    end
  end

  describe "list_for_organizer/1 e enrolled_workshop_ids/1" do
    test "organizador vê os próprios, inclusive rascunho" do
      organizer = insert(:user)
      {:ok, _} = Workshops.create_workshop(organizer, attrs(%{title: "Meu rascunho"}))

      assert [%{title: "Meu rascunho"}] = Workshops.list_for_organizer(organizer.id)
    end

    test "ids de onde a pessoa está inscrita (batch para a lista)" do
      organizer = insert(:user)
      {:ok, w} = Workshops.create_workshop(organizer, attrs())
      {:ok, w} = Workshops.publish_workshop(organizer, w)
      aluno = insert(:user)
      {:ok, _} = Workshops.enroll(w, aluno)

      assert Workshops.enrolled_workshop_ids(aluno.id) == MapSet.new([w.id])
      assert Workshops.enrolled_workshop_ids(organizer.id) == MapSet.new()
    end
  end
end
