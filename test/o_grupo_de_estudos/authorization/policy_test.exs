defmodule OGrupoDeEstudos.Authorization.PolicyTest do
  use OGrupoDeEstudos.DataCase, async: true
  import OGrupoDeEstudos.Factory
  alias OGrupoDeEstudos.Authorization.Policy

  describe "authorize(:delete_comment, user, comment)" do
    test "admin can delete any comment" do
      admin = insert(:admin)
      comment = insert(:step_comment)
      assert :ok = Policy.authorize(:delete_comment, admin, comment)
    end

    test "author can delete own comment" do
      user = insert(:user)
      comment = insert(:step_comment, user: user)
      assert :ok = Policy.authorize(:delete_comment, user, comment)
    end

    test "other user cannot delete someone else's comment" do
      user = insert(:user)
      comment = insert(:step_comment)
      assert {:error, :unauthorized} = Policy.authorize(:delete_comment, user, comment)
    end
  end

  describe "authorize(:create_comment, user, _)" do
    test "authenticated user can create comments" do
      user = insert(:user)
      assert :ok = Policy.authorize(:create_comment, user, nil)
    end

    test "nil user cannot create comments" do
      assert {:error, :unauthenticated} = Policy.authorize(:create_comment, nil, nil)
    end
  end

  describe "authorize(:edit_step, user, step)" do
    test "admin can edit any step" do
      admin = insert(:admin)
      step = insert(:step)
      assert :ok = Policy.authorize(:edit_step, admin, step)
    end

    test "suggester can edit the step they suggested" do
      user = insert(:user)
      step = insert(:step, suggested_by: user)
      assert :ok = Policy.authorize(:edit_step, user, step)
    end

    test "other user cannot edit a step" do
      user = insert(:user)
      step = insert(:step)
      assert {:error, :unauthorized} = Policy.authorize(:edit_step, user, step)
    end
  end

  describe "authorize(:delete_step, user, step)" do
    test "admin can delete a step" do
      admin = insert(:admin)
      step = insert(:step)
      assert :ok = Policy.authorize(:delete_step, admin, step)
    end

    test "suggester cannot delete the step they suggested" do
      user = insert(:user)
      step = insert(:step, suggested_by: user)
      assert {:error, :unauthorized} = Policy.authorize(:delete_step, user, step)
    end
  end

  describe "authorize(:approve_step, user, step)" do
    test "admin can approve a step" do
      admin = insert(:admin)
      step = insert(:step)
      assert :ok = Policy.authorize(:approve_step, admin, step)
    end

    test "regular user cannot approve a step" do
      user = insert(:user)
      step = insert(:step)
      assert {:error, :unauthorized} = Policy.authorize(:approve_step, user, step)
    end
  end

  describe "authorize(:manage_section, user, _)" do
    test "admin can manage sections and categories" do
      admin = insert(:admin)
      assert :ok = Policy.authorize(:manage_section, admin, nil)
    end

    test "regular user cannot manage sections" do
      user = insert(:user)
      assert {:error, :unauthorized} = Policy.authorize(:manage_section, user, nil)
    end
  end

  describe "authorize(:manage_step_link, user, link)" do
    test "admin can manage any link" do
      admin = insert(:admin)
      link = insert(:step_link)
      assert :ok = Policy.authorize(:manage_step_link, admin, link)
    end

    test "submitter can manage the link they submitted" do
      user = insert(:user)
      link = insert(:step_link, submitted_by: user)
      assert :ok = Policy.authorize(:manage_step_link, user, link)
    end

    test "other user cannot manage someone else's link" do
      user = insert(:user)
      link = insert(:step_link)
      assert {:error, :unauthorized} = Policy.authorize(:manage_step_link, user, link)
    end

    test "nil link is unauthorized" do
      user = insert(:user)
      assert {:error, :unauthorized} = Policy.authorize(:manage_step_link, user, nil)
    end
  end

  describe "authorize(:manage_sequence, user, sequence)" do
    test "admin can manage any sequence" do
      admin = insert(:admin)
      sequence = insert(:sequence)
      assert :ok = Policy.authorize(:manage_sequence, admin, sequence)
    end

    test "owner can manage their own sequence" do
      user = insert(:user)
      sequence = insert(:sequence, user: user)
      assert :ok = Policy.authorize(:manage_sequence, user, sequence)
    end

    test "other user cannot manage someone else's sequence" do
      user = insert(:user)
      sequence = insert(:sequence)
      assert {:error, :unauthorized} = Policy.authorize(:manage_sequence, user, sequence)
    end

    test "nil sequence is unauthorized" do
      user = insert(:user)
      assert {:error, :unauthorized} = Policy.authorize(:manage_sequence, user, nil)
    end
  end

  describe "authorized?/3" do
    test "mirrors authorize/3 as a boolean" do
      admin = insert(:admin)
      user = insert(:user)
      step = insert(:step)

      assert Policy.authorized?(:delete_step, admin, step)
      refute Policy.authorized?(:delete_step, user, step)
    end
  end
end
