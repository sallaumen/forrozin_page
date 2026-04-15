defmodule OGrupoDeEstudos.Encyclopedia.StepLinkQueryTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Encyclopedia.StepLinkQuery

  describe "list_by/1 — step_id filter" do
    test "returns only links for the given step" do
      step_a = insert(:step, code: "SA")
      step_b = insert(:step, code: "SB")
      user = insert(:user)

      link_a = insert(:step_link, step: step_a, submitted_by: user, approved: true)
      _link_b = insert(:step_link, step: step_b, submitted_by: user, approved: true)

      result = StepLinkQuery.list_by(step_id: step_a.id)

      assert length(result) == 1
      assert hd(result).id == link_a.id
    end
  end

  describe "list_by/1 — approved filter" do
    test "returns only approved links when approved: true" do
      step = insert(:step, code: "SC")
      user = insert(:user)

      approved = insert(:step_link, step: step, submitted_by: user, approved: true)
      _pending = insert(:step_link, step: step, submitted_by: user, approved: false)

      result = StepLinkQuery.list_by(approved: true)

      ids = Enum.map(result, & &1.id)
      assert approved.id in ids
      assert length(result) == 1
    end

    test "returns only pending links when approved: false" do
      step = insert(:step, code: "SD")
      user = insert(:user)

      _approved = insert(:step_link, step: step, submitted_by: user, approved: true)
      pending = insert(:step_link, step: step, submitted_by: user, approved: false)

      result = StepLinkQuery.list_by(approved: false)

      ids = Enum.map(result, & &1.id)
      assert pending.id in ids
      assert length(result) == 1
    end
  end

  describe "list_by/1 — soft delete exclusion" do
    test "excludes soft-deleted links by default" do
      step = insert(:step, code: "SE")
      user = insert(:user)

      _deleted =
        insert(:step_link,
          step: step,
          submitted_by: user,
          approved: true,
          deleted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        )

      live_link = insert(:step_link, step: step, submitted_by: user, approved: true)

      result = StepLinkQuery.list_by(step_id: step.id)

      ids = Enum.map(result, & &1.id)
      assert live_link.id in ids
      assert length(result) == 1
    end

    test "includes soft-deleted links when include_deleted: true" do
      step = insert(:step, code: "SF")
      user = insert(:user)

      deleted =
        insert(:step_link,
          step: step,
          submitted_by: user,
          approved: true,
          deleted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        )

      result = StepLinkQuery.list_by(step_id: step.id, include_deleted: true)

      ids = Enum.map(result, & &1.id)
      assert deleted.id in ids
    end
  end

  describe "list_by/1 — pending shortcut" do
    test "pending: true returns non-approved, non-deleted links" do
      step = insert(:step, code: "SG")
      user = insert(:user)

      pending = insert(:step_link, step: step, submitted_by: user, approved: false)
      _approved = insert(:step_link, step: step, submitted_by: user, approved: true)

      _deleted_pending =
        insert(:step_link,
          step: step,
          submitted_by: user,
          approved: false,
          deleted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        )

      result = StepLinkQuery.list_by(pending: true, step_id: step.id)

      ids = Enum.map(result, & &1.id)
      assert pending.id in ids
      assert length(result) == 1
    end
  end

  describe "count_by/1" do
    test "counts links matching opts" do
      step = insert(:step, code: "SH")
      user = insert(:user)

      insert(:step_link, step: step, submitted_by: user, approved: true)
      insert(:step_link, step: step, submitted_by: user, approved: true)
      insert(:step_link, step: step, submitted_by: user, approved: false)

      assert StepLinkQuery.count_by(step_id: step.id, approved: true) == 2
      assert StepLinkQuery.count_by(step_id: step.id) == 3
    end
  end
end
