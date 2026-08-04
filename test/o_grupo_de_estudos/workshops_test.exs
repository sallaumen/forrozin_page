defmodule OGrupoDeEstudos.WorkshopsTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Brazil
  alias OGrupoDeEstudos.Workshops
  alias OGrupoDeEstudos.Workshops.EnrollmentQuery

  defp at_day(days, hour \\ 14) do
    Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(Time.new!(hour, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp attrs(overrides \\ %{}) do
    Map.merge(
      %{
        title: "Workshop de sacadas",
        description: "Quatro horas de sacadas e conduções.",
        location: "Curitiba, Juvevê",
        starts_at: at_day(7),
        ends_at: at_day(7, 18)
      },
      overrides
    )
  end

  describe "create_workshop/2" do
    test "creates as draft, with a readable and unique slug" do
      organizer = insert(:user)

      assert {:ok, workshop} = Workshops.create_workshop(organizer, attrs())
      assert workshop.status == :draft
      assert workshop.organizer_id == organizer.id
      assert workshop.slug =~ ~r/^workshop-de-sacadas-[a-z0-9]+$/

      {:ok, other} = Workshops.create_workshop(organizer, attrs())
      assert other.slug != workshop.slug
    end

    test "requires title, description and start" do
      organizer = insert(:user)

      assert {:error, changeset} =
               Workshops.create_workshop(organizer, %{title: "", description: ""})

      errors = errors_on(changeset)
      assert errors.title != []
      assert errors.description != []
      assert errors.starts_at != []
    end

    test "end must be after the start" do
      organizer = insert(:user)

      assert {:error, changeset} =
               Workshops.create_workshop(
                 organizer,
                 attrs(%{starts_at: at_day(7, 18), ends_at: at_day(7, 9)})
               )

      assert errors_on(changeset).ends_at != []
    end

    test "any user creates a workshop, not only a teacher" do
      student = insert(:user, is_teacher: false)
      assert {:ok, _} = Workshops.create_workshop(student, attrs())
    end
  end

  describe "publish_workshop/2 e cancel_workshop/2" do
    test "publishing puts it on the agenda and cancelling preserves the record" do
      organizer = insert(:user)
      {:ok, workshop} = Workshops.create_workshop(organizer, attrs())

      assert {:ok, published} = Workshops.publish_workshop(organizer, workshop)
      assert published.status == :published

      assert {:ok, cancelled} = Workshops.cancel_workshop(organizer, published)
      assert cancelled.status == :cancelled
      assert Workshops.get_by_slug(workshop.slug)
    end

    test "another user neither publishes nor cancels" do
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

    test "organizer does not enroll in their own workshop", %{
      organizer: organizer,
      workshop: workshop
    } do
      assert {:error, :organizer} = Workshops.enroll(workshop, organizer)
      assert EnrollmentQuery.count(workshop.id) == 0
    end

    test "enrolls and counts", %{workshop: workshop} do
      student = insert(:user)

      assert {:ok, enrollment} = Workshops.enroll(workshop, student)
      assert enrollment.payment_status == :pending
      assert Workshops.count_enrollments(workshop.id) == 1
    end

    test "enrolling twice does not duplicate", %{workshop: workshop} do
      student = insert(:user)
      {:ok, _} = Workshops.enroll(workshop, student)

      assert {:error, :already_enrolled} = Workshops.enroll(workshop, student)
      assert Workshops.count_enrollments(workshop.id) == 1
    end

    test "cannot enroll in a draft", %{organizer: organizer} do
      {:ok, draft} = Workshops.create_workshop(organizer, attrs())
      student = insert(:user)

      assert {:error, :not_open} = Workshops.enroll(draft, student)
    end

    test "cannot enroll in a cancelled workshop", %{
      organizer: organizer,
      workshop: workshop
    } do
      {:ok, cancelled} = Workshops.cancel_workshop(organizer, workshop)
      student = insert(:user)

      assert {:error, :not_open} = Workshops.enroll(cancelled, student)
    end

    test "respects the capacity", %{organizer: organizer} do
      {:ok, w} = Workshops.create_workshop(organizer, attrs(%{capacity: 1}))
      {:ok, w} = Workshops.publish_workshop(organizer, w)

      {:ok, _} = Workshops.enroll(w, insert(:user))
      assert {:error, :full} = Workshops.enroll(w, insert(:user))
      assert Workshops.count_enrollments(w.id) == 1
    end

    test "without a capacity, never gets full", %{workshop: workshop} do
      for _ <- 1..5, do: {:ok, _} = Workshops.enroll(workshop, insert(:user))
      assert Workshops.count_enrollments(workshop.id) == 5
    end

    test "cancelling an enrollment frees the seat", %{organizer: organizer} do
      {:ok, w} = Workshops.create_workshop(organizer, attrs(%{capacity: 1}))
      {:ok, w} = Workshops.publish_workshop(organizer, w)
      student = insert(:user)

      {:ok, _} = Workshops.enroll(w, student)
      assert {:ok, _} = Workshops.cancel_enrollment(w, student)
      assert Workshops.count_enrollments(w.id) == 0

      assert {:ok, _} = Workshops.enroll(w, insert(:user))
    end
  end

  describe "payment privacy" do
    setup do
      organizer = insert(:user)
      {:ok, w} = Workshops.create_workshop(organizer, attrs())
      {:ok, w} = Workshops.publish_workshop(organizer, w)
      student = insert(:user, name: "Ana Souza")
      {:ok, _} = Workshops.enroll(w, student)
      %{organizer: organizer, workshop: w, student: student}
    end

    test "public list does not expose payment", %{workshop: w} do
      assert [participante] = Workshops.list_participants(w.id)

      assert Map.has_key?(participante, :name)
      refute Map.has_key?(participante, :payment_status)
      refute Map.has_key?(participante, :paid_at)
    end

    test "only the organizer sees the list with payment", %{
      organizer: organizer,
      workshop: w,
      student: student
    } do
      assert {:ok, [row]} = Workshops.list_enrollments_for_organizer(w, organizer)
      assert row.payment_status == :pending
      assert row.user.name == "Ana Souza"

      assert {:error, :unauthorized} = Workshops.list_enrollments_for_organizer(w, student)
    end

    test "organizador marca pago e desfaz", %{organizer: organizer, workshop: w} do
      {:ok, [row]} = Workshops.list_enrollments_for_organizer(w, organizer)

      assert {:ok, paid_class} = Workshops.set_payment_status(w, organizer, row.id, :paid)
      assert paid_class.payment_status == :paid
      assert paid_class.paid_at

      assert {:ok, voltou} = Workshops.set_payment_status(w, organizer, row.id, :pending)
      assert voltou.payment_status == :pending
      assert voltou.paid_at == nil
    end

    test "non-organizer does not change the payment", %{
      organizer: organizer,
      workshop: w,
      student: student
    } do
      {:ok, [row]} = Workshops.list_enrollments_for_organizer(w, organizer)

      assert {:error, :unauthorized} =
               Workshops.set_payment_status(w, student, row.id, :paid)
    end

    test "organizer does not mark payment of an enrollment from another workshop", %{
      organizer: organizer,
      workshop: w
    } do
      other_owner = insert(:user)
      {:ok, other} = Workshops.create_workshop(other_owner, attrs())
      {:ok, other} = Workshops.publish_workshop(other_owner, other)
      {:ok, alheia} = Workshops.enroll(other, insert(:user))

      assert {:error, :not_found} = Workshops.set_payment_status(w, organizer, alheia.id, :paid)
    end
  end

  describe "list_feed/1 agenda with filters" do
    setup do
      organizer = insert(:user, name: "Tavano Silva")
      other = insert(:user, name: "Marina Prado")

      publish = fn owner, title, starts_at ->
        {:ok, w} =
          Workshops.create_workshop(
            owner,
            attrs(%{title: title, starts_at: starts_at, ends_at: nil})
          )

        {:ok, w} = Workshops.publish_workshop(owner, w)
        w
      end

      %{
        tomorrow: publish.(organizer, "Sacadas avançadas", at_day(1)),
        next_month: publish.(other, "Intensivo de inversão", at_day(40)),
        past_workshop: publish.(organizer, "Roda de forró antiga", at_day(-10)),
        organizer: organizer
      }
    end

    test "shows upcoming workshops by default, ordered by date", %{
      tomorrow: tomorrow,
      next_month: month
    } do
      ids = Workshops.list_feed() |> Enum.map(& &1.id)

      assert ids == [tomorrow.id, month.id]
    end

    test "past filter shows the ones that already happened", %{past_workshop: past_workshop} do
      assert [%{id: id}] = Workshops.list_feed(period: :past)
      assert id == past_workshop.id
    end

    test "week and month filters respect the timezone", %{tomorrow: tomorrow} do
      week_ids = Workshops.list_feed(period: :week) |> Enum.map(& &1.id)
      month_ids = Workshops.list_feed(period: :month) |> Enum.map(& &1.id)

      assert tomorrow.id in month_ids or tomorrow.id in week_ids
    end

    test "searches by workshop title", %{tomorrow: tomorrow} do
      assert [%{id: id}] = Workshops.list_feed(search: "sacadas")
      assert id == tomorrow.id
    end

    test "searches by organizer name", %{next_month: month} do
      assert [%{id: id}] = Workshops.list_feed(search: "marina")
      assert id == month.id
    end

    test "draft and cancelled do not show up on the agenda", %{organizer: organizer} do
      {:ok, _draft} = Workshops.create_workshop(organizer, attrs(%{title: "Escondido"}))

      {:ok, published} = Workshops.create_workshop(organizer, attrs(%{title: "Vai sumir"}))
      {:ok, published} = Workshops.publish_workshop(organizer, published)
      {:ok, _} = Workshops.cancel_workshop(organizer, published)

      titulos = Workshops.list_feed() |> Enum.map(& &1.title)
      refute "Escondido" in titulos
      refute "Vai sumir" in titulos
    end
  end

  describe "list_for_organizer/1 e enrolled_workshop_ids/1" do
    test "organizer sees their own workshops, drafts included" do
      organizer = insert(:user)
      {:ok, _} = Workshops.create_workshop(organizer, attrs(%{title: "Meu rascunho"}))

      assert [%{title: "Meu rascunho"}] = Workshops.list_for_organizer(organizer.id)
    end

    test "returns ids the user is enrolled in, batched for the list" do
      organizer = insert(:user)
      {:ok, w} = Workshops.create_workshop(organizer, attrs())
      {:ok, w} = Workshops.publish_workshop(organizer, w)
      student = insert(:user)
      {:ok, _} = Workshops.enroll(w, student)

      assert Workshops.enrolled_workshop_ids(student.id) == MapSet.new([w.id])
      assert Workshops.enrolled_workshop_ids(organizer.id) == MapSet.new()
    end
  end
end
