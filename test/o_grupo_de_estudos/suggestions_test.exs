defmodule OGrupoDeEstudos.SuggestionsTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Encyclopedia.{Connection, ConnectionQuery, Step}
  alias OGrupoDeEstudos.Suggestions

  setup do
    user = insert(:user)
    admin = insert(:admin)
    step = insert(:step)
    %{user: user, admin: admin, step: step}
  end

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

      assert suggestion.status == :pending
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

      assert suggestion.action == :create_connection
      assert suggestion.status == :pending
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

      assert suggestion.action == :remove_connection
      assert suggestion.status == :pending
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

  describe "approve/2" do
    test "approving an edit_field suggestion updates the step name and sets last_edited_by",
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

      assert approved.status == :approved
      assert approved.reviewed_by_id == admin.id
      assert approved.reviewed_at != nil

      updated_step = Repo.get!(Step, step.id)
      assert updated_step.name == "Nome Atualizado"
      assert updated_step.last_edited_by_id == user.id
      assert updated_step.last_edited_at != nil
    end

    test "approving a create_connection suggestion creates the connection",
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

      conn =
        ConnectionQuery.get_by(
          source_step_id: source.id,
          target_step_id: target.id
        )

      assert conn != nil
    end

    test "approving a remove_connection suggestion soft-deletes the connection",
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

      deleted_conn = Repo.get(Connection, connection.id)
      assert deleted_conn.deleted_at != nil
    end
  end

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

      assert rejected.status == :rejected
      assert rejected.reviewed_by_id == admin.id

      unchanged = Repo.get!(Step, step.id)
      assert unchanged.name == step.name
    end
  end

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

  describe "admin notification on create" do
    test "notifies admins when a user creates a suggestion", %{
      user: user,
      admin: admin,
      step: step
    } do
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
            where: n.user_id == ^admin.id and n.action == :suggestion_created
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
            where: n.user_id == ^admin.id and n.action == :suggestion_created
        )

      assert notifications == []
    end
  end

  describe "list_user_pending_for_step/2" do
    test "returns only user's pending suggestions for the step", %{
      user: user,
      admin: admin,
      step: step
    } do
      {:ok, _} =
        Suggestions.create(user, %{
          target_type: "step",
          target_id: step.id,
          action: "edit_field",
          field: "name",
          old_value: step.name,
          new_value: "Pending"
        })

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
