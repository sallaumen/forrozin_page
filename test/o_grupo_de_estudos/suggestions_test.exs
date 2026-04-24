defmodule OGrupoDeEstudos.SuggestionsTest do
  @moduledoc """
  TDD tests for the Suggestions context.

  Each describe block covers one public function:
  - create/2: validates all three action types + error paths
  - approve/2: atomic apply for edit_field, create_connection, remove_connection
  - reject/2: updates status without touching the step
  - list_pending/1: filters by status
  - list_by_user/2: filters by user
  - count_pending/0: counts pending
  """
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Suggestions
  alias OGrupoDeEstudos.Encyclopedia.{Connection, Step}

  setup do
    user = insert(:user)
    admin = insert(:admin)
    step = insert(:step)
    %{user: user, admin: admin, step: step}
  end

  # ── create/2 ──────────────────────────────────────────────

  describe "create/2" do
    test "creates a pending suggestion for edit_field", %{user: user, step: step} do
      {:ok, suggestion} =
        Suggestions.create(user, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "name",
          old_value: step.name,
          new_value: "Novo Nome"
        })

      assert suggestion.status == "pending"
      assert suggestion.user_id == user.id
      assert suggestion.new_value == "Novo Nome"
    end

    test "creates suggestion for create_connection", %{user: user, step: step} do
      other = insert(:step)

      {:ok, suggestion} =
        Suggestions.create(user, %{
          target_type: "connection",
          target_id: step.id,
          action: "create_connection",
          new_value: "#{step.code}→#{other.code}"
        })

      assert suggestion.action == "create_connection"
      assert suggestion.status == "pending"
    end

    test "creates suggestion for remove_connection", %{user: user, step: step} do
      connection = insert(:connection, source_step: step)

      {:ok, suggestion} =
        Suggestions.create(user, %{
          target_type: "connection",
          target_id: connection.id,
          action: "remove_connection",
          old_value: "#{step.code}→#{connection.target_step.code}"
        })

      assert suggestion.action == "remove_connection"
      assert suggestion.status == "pending"
    end

    test "rejects invalid action", %{user: user, step: step} do
      {:error, changeset} =
        Suggestions.create(user, %{
          target_type: "step",
          target_id: step.id,
          action: "hack_system"
        })

      assert errors_on(changeset).action
    end

    test "requires field for edit_field action", %{user: user, step: step} do
      {:error, changeset} =
        Suggestions.create(user, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          new_value: "test"
        })

      assert errors_on(changeset).field
    end
  end

  # ── approve/2 ─────────────────────────────────────────────

  describe "approve/2" do
    test "approves and applies edit_field suggestion — step name updated + last_edited_by set",
         %{user: user, admin: admin, step: step} do
      {:ok, suggestion} =
        Suggestions.create(user, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "name",
          old_value: step.name,
          new_value: "Nome Atualizado"
        })

      {:ok, approved} = Suggestions.approve(suggestion, admin)

      assert approved.status == "approved"
      assert approved.reviewed_by_id == admin.id
      assert approved.reviewed_at != nil

      # Step should be updated
      updated_step = Repo.get!(Step, step.id)
      assert updated_step.name == "Nome Atualizado"
      assert updated_step.last_edited_by_id == user.id
      assert updated_step.last_edited_at != nil
    end

    test "approves and applies create_connection suggestion — connection exists",
         %{user: user, admin: admin} do
      source = insert(:step)
      target = insert(:step)

      {:ok, suggestion} =
        Suggestions.create(user, %{
          target_type: "connection",
          target_id: source.id,
          action: "create_connection",
          new_value: "#{source.code}→#{target.code}"
        })

      {:ok, _approved} = Suggestions.approve(suggestion, admin)

      # Connection should exist
      conn =
        OGrupoDeEstudos.Encyclopedia.ConnectionQuery.get_by(
          source_step_id: source.id,
          target_step_id: target.id
        )

      assert conn != nil
    end

    test "approves and applies remove_connection suggestion — connection soft-deleted",
         %{user: user, admin: admin} do
      connection = insert(:connection)

      {:ok, suggestion} =
        Suggestions.create(user, %{
          target_type: "connection",
          target_id: connection.id,
          action: "remove_connection",
          old_value: "#{connection.source_step.code}→#{connection.target_step.code}"
        })

      {:ok, _approved} = Suggestions.approve(suggestion, admin)

      # Connection should be soft-deleted
      deleted_conn = Repo.get(Connection, connection.id)
      assert deleted_conn.deleted_at != nil
    end
  end

  # ── reject/2 ──────────────────────────────────────────────

  describe "reject/2" do
    test "rejects a suggestion without changing the step",
         %{user: user, admin: admin, step: step} do
      {:ok, suggestion} =
        Suggestions.create(user, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "name",
          old_value: step.name,
          new_value: "Rejected Name"
        })

      {:ok, rejected} = Suggestions.reject(suggestion, admin)

      assert rejected.status == "rejected"
      assert rejected.reviewed_by_id == admin.id

      # Step should NOT be updated
      unchanged = Repo.get!(Step, step.id)
      assert unchanged.name == step.name
    end
  end

  # ── list_pending/1 ────────────────────────────────────────

  describe "list_pending/1" do
    test "returns only pending suggestions", %{user: user, admin: admin, step: step} do
      {:ok, s1} =
        Suggestions.create(user, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "name",
          old_value: step.name,
          new_value: "A"
        })

      {:ok, s2} =
        Suggestions.create(user, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "note",
          old_value: step.note || "",
          new_value: "B"
        })

      Suggestions.approve(s1, admin)

      pending = Suggestions.list_pending()
      assert length(pending) == 1
      assert hd(pending).id == s2.id
    end
  end

  # ── list_by_user/2 ───────────────────────────────────────

  describe "list_by_user/2" do
    test "returns suggestions filtered by user", %{user: user, step: step} do
      {:ok, _} =
        Suggestions.create(user, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "name",
          old_value: step.name,
          new_value: "Test"
        })

      other = insert(:user)

      {:ok, _} =
        Suggestions.create(other, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "name",
          old_value: step.name,
          new_value: "Other"
        })

      result = Suggestions.list_by_user(user.id)
      assert length(result) == 1
    end
  end

  # ── count_pending/0 ──────────────────────────────────────

  describe "count_pending/0" do
    test "counts pending suggestions", %{user: user, step: step} do
      {:ok, _} =
        Suggestions.create(user, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "name",
          old_value: step.name,
          new_value: "X"
        })

      assert Suggestions.count_pending() == 1
    end
  end

  # ── Admin notifications on create ───────────────────────

  describe "admin notification on create" do
    test "notifies admins when a user creates a suggestion", %{user: user, admin: admin, step: step} do
      alias OGrupoDeEstudos.Engagement.Notifications.Notification

      {:ok, _} =
        Suggestions.create(user, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "name",
          old_value: step.name,
          new_value: "Notificação Test"
        })

      notifications =
        Repo.all(
          from n in Notification,
            where: n.user_id == ^admin.id and n.action == "suggestion_created"
        )

      assert length(notifications) == 1
      assert hd(notifications).actor_id == user.id
    end

    test "does not notify the author when they are admin", %{admin: admin, step: step} do
      alias OGrupoDeEstudos.Engagement.Notifications.Notification

      {:ok, _} =
        Suggestions.create(admin, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "name",
          old_value: step.name,
          new_value: "Admin Self"
        })

      notifications =
        Repo.all(
          from n in Notification,
            where: n.user_id == ^admin.id and n.action == "suggestion_created"
        )

      assert notifications == []
    end
  end

  # ── list_user_pending_for_step/2 ────────────────────────

  describe "list_user_pending_for_step/2" do
    test "returns only user's pending suggestions for the step", %{user: user, admin: admin, step: step} do
      {:ok, _} =
        Suggestions.create(user, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "name",
          old_value: step.name,
          new_value: "Pending"
        })

      # Approved suggestion (should not appear)
      {:ok, s2} =
        Suggestions.create(user, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "note",
          old_value: "",
          new_value: "Approved"
        })

      Suggestions.approve(s2, admin)

      result = Suggestions.list_user_pending_for_step(user.id, step.id)
      assert length(result) == 1
      assert hd(result).new_value == "Pending"
    end

    test "does not return other user's suggestions", %{user: user, step: step} do
      other = insert(:user)

      {:ok, _} =
        Suggestions.create(other, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "name",
          old_value: step.name,
          new_value: "Other User"
        })

      result = Suggestions.list_user_pending_for_step(user.id, step.id)
      assert result == []
    end
  end
end
