defmodule Forrozin.EngagementTest do
  use Forrozin.DataCase, async: true

  import Forrozin.Factory

  alias Forrozin.Engagement

  setup do
    user = insert(:user)
    step = insert(:step)
    sequence = insert(:sequence, user: user)
    %{user: user, step: step, sequence: sequence}
  end

  describe "toggle_like/3" do
    test "creates a like when none exists", %{user: user, step: step} do
      assert {:ok, :liked} = Engagement.toggle_like(user.id, "step", step.id)
      assert Engagement.liked?(user.id, "step", step.id)
    end

    test "removes the like when one already exists", %{user: user, step: step} do
      {:ok, :liked} = Engagement.toggle_like(user.id, "step", step.id)
      assert {:ok, :unliked} = Engagement.toggle_like(user.id, "step", step.id)
      refute Engagement.liked?(user.id, "step", step.id)
    end

    test "is idempotent for unlike — a second unlike is a new like", %{user: user, step: step} do
      {:ok, :liked} = Engagement.toggle_like(user.id, "step", step.id)
      {:ok, :unliked} = Engagement.toggle_like(user.id, "step", step.id)
      assert {:ok, :liked} = Engagement.toggle_like(user.id, "step", step.id)
    end

    test "works for sequence likeable_type", %{user: user, sequence: sequence} do
      assert {:ok, :liked} = Engagement.toggle_like(user.id, "sequence", sequence.id)
      assert Engagement.liked?(user.id, "sequence", sequence.id)
    end
  end

  describe "liked?/3" do
    test "returns false when the user has not liked", %{user: user, step: step} do
      refute Engagement.liked?(user.id, "step", step.id)
    end

    test "returns true after a like is created", %{user: user, step: step} do
      {:ok, :liked} = Engagement.toggle_like(user.id, "step", step.id)
      assert Engagement.liked?(user.id, "step", step.id)
    end

    test "returns false after like is removed", %{user: user, step: step} do
      {:ok, :liked} = Engagement.toggle_like(user.id, "step", step.id)
      {:ok, :unliked} = Engagement.toggle_like(user.id, "step", step.id)
      refute Engagement.liked?(user.id, "step", step.id)
    end
  end

  describe "count_likes/2" do
    test "returns 0 when no likes exist", %{step: step} do
      assert 0 == Engagement.count_likes("step", step.id)
    end

    test "returns correct count after multiple users like the same entity", %{step: step} do
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)

      Engagement.toggle_like(user1.id, "step", step.id)
      Engagement.toggle_like(user2.id, "step", step.id)
      Engagement.toggle_like(user3.id, "step", step.id)

      assert 3 == Engagement.count_likes("step", step.id)
    end

    test "decreases after unlike", %{user: user, step: step} do
      Engagement.toggle_like(user.id, "step", step.id)
      assert 1 == Engagement.count_likes("step", step.id)

      Engagement.toggle_like(user.id, "step", step.id)
      assert 0 == Engagement.count_likes("step", step.id)
    end
  end

  describe "likes_map/3" do
    test "returns empty liked_ids and counts when nothing liked", %{user: user, step: step} do
      result = Engagement.likes_map(user.id, "step", [step.id])

      assert %{liked_ids: liked_ids, counts: counts} = result
      assert MapSet.size(liked_ids) == 0
      assert map_size(counts) == 0
    end

    test "marks liked entities in liked_ids and tracks counts", %{user: user, step: step} do
      other_step = insert(:step)
      other_user = insert(:user)

      Engagement.toggle_like(user.id, "step", step.id)
      Engagement.toggle_like(other_user.id, "step", step.id)

      result = Engagement.likes_map(user.id, "step", [step.id, other_step.id])

      assert %{liked_ids: liked_ids, counts: counts} = result
      assert MapSet.member?(liked_ids, step.id)
      refute MapSet.member?(liked_ids, other_step.id)
      assert Map.get(counts, step.id) == 2
      assert Map.get(counts, other_step.id, 0) == 0
    end

    test "does not leak likes across likeable_types", %{
      user: user,
      step: step,
      sequence: sequence
    } do
      Engagement.toggle_like(user.id, "step", step.id)

      result = Engagement.likes_map(user.id, "sequence", [sequence.id])

      assert %{liked_ids: liked_ids} = result
      refute MapSet.member?(liked_ids, sequence.id)
    end
  end
end
