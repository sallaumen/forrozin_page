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
end
