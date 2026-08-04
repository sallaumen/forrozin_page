defmodule OGrupoDeEstudos.WorkshopStepsTest do
  @moduledoc """
  The steps taught in a workshop, which is what connects a workshop back to
  the collection. The admin curates the list; like-based ordering was
  considered and dropped as more machinery than the permission already is.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Workshops

  setup do
    owner = insert(:user)

    %{
      owner: owner,
      workshop: insert(:workshop, organizer: owner),
      step: insert(:step, code: "IV", name: "Inversão base"),
      other_step: insert(:step, code: "SC", name: "Sacada simples")
    }
  end

  describe "building the list" do
    test "organizer adds a step", ctx do
      assert {:ok, _} = Workshops.add_step(ctx.workshop, ctx.owner, ctx.step.id)

      assert [step] = Workshops.list_steps(ctx.workshop.id)
      assert step.code == "IV"
      assert step.name == "Inversão base"
    end

    test "keeps the order the teacher built, not the alphabetical one", ctx do
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.owner, ctx.other_step.id)
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.owner, ctx.step.id)

      assert ["SC", "IV"] = Enum.map(Workshops.list_steps(ctx.workshop.id), & &1.code)
    end

    test "same step does not go in twice", ctx do
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.owner, ctx.step.id)

      assert {:error, :already_added} = Workshops.add_step(ctx.workshop, ctx.owner, ctx.step.id)
      assert length(Workshops.list_steps(ctx.workshop.id)) == 1
    end

    test "co-organizer also builds the list", ctx do
      partner = insert(:user)
      {:ok, _} = Workshops.add_admin(ctx.workshop, ctx.owner, partner.id)

      assert {:ok, _} = Workshops.add_step(ctx.workshop, partner, ctx.step.id)
    end

    test "enrolled user does not change the list", ctx do
      student = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, student)

      assert {:error, :unauthorized} = Workshops.add_step(ctx.workshop, student, ctx.step.id)
    end

    test "removes a step from the list", ctx do
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.owner, ctx.step.id)

      assert {:ok, _} = Workshops.remove_step(ctx.workshop, ctx.owner, ctx.step.id)
      assert Workshops.list_steps(ctx.workshop.id) == []
    end

    test "outsider does not remove", ctx do
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.owner, ctx.step.id)

      assert {:error, :unauthorized} =
               Workshops.remove_step(ctx.workshop, insert(:user), ctx.step.id)
    end

    test "step that does not exist is not added", ctx do
      assert {:error, :not_found} =
               Workshops.add_step(ctx.workshop, ctx.owner, Ecto.UUID.generate())
    end

    test "invalid id does not crash", ctx do
      assert {:error, :not_found} = Workshops.add_step(ctx.workshop, ctx.owner, "nao-e-uuid")
    end
  end

  describe "the way back to the collection" do
    test "reports in which workshops the user saw this step", ctx do
      student = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, student)
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.owner, ctx.step.id)

      assert [visto] = Workshops.workshops_where_seen(student.id, ctx.step.id)
      assert visto.title == ctx.workshop.title
      assert visto.slug == ctx.workshop.slug
    end

    test "counts only workshops the user attended", ctx do
      estranha = insert(:user)
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.owner, ctx.step.id)

      assert Workshops.workshops_where_seen(estranha.id, ctx.step.id) == []
    end

    test "organizer also sees their own workshop in the way back", ctx do
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.owner, ctx.step.id)

      assert [_visto] = Workshops.workshops_where_seen(ctx.owner.id, ctx.step.id)
    end

    test "anonymous visitor has no history", ctx do
      {:ok, _} = Workshops.add_step(ctx.workshop, ctx.owner, ctx.step.id)

      assert Workshops.workshops_where_seen(nil, ctx.step.id) == []
    end
  end
end
