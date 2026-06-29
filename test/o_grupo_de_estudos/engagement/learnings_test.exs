defmodule OGrupoDeEstudos.Engagement.LearningsTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Engagement.{Favorite, Favorites, LearnedStep, Like}

  describe "toggle_learned/2" do
    test "marks a step as learned" do
      user = insert(:user)
      step = insert(:step)

      assert {:ok, :learned} = Engagement.toggle_learned(user.id, step.id)
      assert Engagement.learned?(user.id, step.id)
      assert Repo.get_by(LearnedStep, user_id: user.id, step_id: step.id)
    end

    test "toggling a learned step unlearns it" do
      user = insert(:user)
      step = insert(:step)

      assert {:ok, :learned} = Engagement.toggle_learned(user.id, step.id)
      assert {:ok, :unlearned} = Engagement.toggle_learned(user.id, step.id)

      refute Engagement.learned?(user.id, step.id)
      refute Repo.get_by(LearnedStep, user_id: user.id, step_id: step.id)
    end

    test "marking a step learned also favorites it (and auto-likes)" do
      user = insert(:user)
      step = insert(:step)

      assert {:ok, :learned} = Engagement.toggle_learned(user.id, step.id)

      assert Engagement.favorited?(user.id, "step", step.id)

      assert Repo.get_by(Favorite,
               user_id: user.id,
               favoritable_type: "step",
               favoritable_id: step.id
             )

      assert Repo.get_by(Like, user_id: user.id, likeable_type: "step", likeable_id: step.id)
    end

    test "unlearning preserves the favorite" do
      user = insert(:user)
      step = insert(:step)

      Engagement.toggle_learned(user.id, step.id)
      Engagement.toggle_learned(user.id, step.id)

      refute Engagement.learned?(user.id, step.id)
      assert Engagement.favorited?(user.id, "step", step.id)
    end

    test "learning an already-favorited step does not duplicate the favorite" do
      user = insert(:user)
      step = insert(:step)

      assert {:ok, :favorited} = Engagement.toggle_favorite(user.id, "step", step.id)
      assert {:ok, :learned} = Engagement.toggle_learned(user.id, step.id)

      count = Repo.aggregate(from(f in Favorite, where: f.user_id == ^user.id), :count)
      assert count == 1
    end

    test "learning an already-liked step does not duplicate the like" do
      user = insert(:user)
      step = insert(:step)
      insert(:like, user: user, likeable_type: "step", likeable_id: step.id)

      assert {:ok, :learned} = Engagement.toggle_learned(user.id, step.id)

      count =
        Repo.aggregate(
          from(l in Like, where: l.user_id == ^user.id and l.likeable_id == ^step.id),
          :count
        )

      assert count == 1
    end
  end

  describe "Favorites.ensure_favorited/3 (mecanismo da jornada)" do
    test "favorites on the first call and reports already-favorited on the second" do
      user = insert(:user)
      step = insert(:step)

      assert {:ok, :favorited} = Favorites.ensure_favorited(user.id, "step", step.id)
      assert {:ok, :already_favorited} = Favorites.ensure_favorited(user.id, "step", step.id)

      assert Repo.aggregate(from(f in Favorite, where: f.user_id == ^user.id), :count) == 1
      assert Repo.aggregate(from(l in Like, where: l.user_id == ^user.id), :count) == 1
    end
  end

  describe "learned_step_codes/1" do
    test "returns the codes of the user's learned steps" do
      user = insert(:user)
      bf = insert(:step, code: "BF")
      sc = insert(:step, code: "SC")
      _other = insert(:step, code: "XX")

      Engagement.toggle_learned(user.id, bf.id)
      Engagement.toggle_learned(user.id, sc.id)

      assert Enum.sort(Engagement.learned_step_codes(user.id)) == ["BF", "SC"]
    end

    test "returns [] for a user with no learned steps" do
      assert Engagement.learned_step_codes(insert(:user).id) == []
    end

    test "excludes soft-deleted steps from codes, list and count" do
      user = insert(:user)
      bf = insert(:step, code: "BF")
      sc = insert(:step, code: "SC")
      Engagement.toggle_learned(user.id, bf.id)
      Engagement.toggle_learned(user.id, sc.id)

      bf |> Ecto.Changeset.change(deleted_at: ~N[2026-01-01 00:00:00]) |> Repo.update!()

      assert Engagement.learned_step_codes(user.id) == ["SC"]
      assert Enum.map(Engagement.list_learned_steps(user.id), & &1.code) == ["SC"]
      assert Engagement.count_user_learned(user.id) == 1
    end
  end

  describe "count_user_learned/1" do
    test "counts only the given user's learned steps" do
      user = insert(:user)
      other = insert(:user)
      Engagement.toggle_learned(user.id, insert(:step).id)
      Engagement.toggle_learned(user.id, insert(:step).id)
      Engagement.toggle_learned(other.id, insert(:step).id)

      assert Engagement.count_user_learned(user.id) == 2
    end
  end

  describe "list_learned_steps/1" do
    test "returns the learned Step records, most recently learned first" do
      user = insert(:user)
      bf = insert(:step, code: "BF")
      sc = insert(:step, code: "SC")

      insert(:learned_step, user: user, step: bf, inserted_at: ~N[2026-01-01 10:00:00])
      insert(:learned_step, user: user, step: sc, inserted_at: ~N[2026-01-01 11:00:00])

      assert Enum.map(Engagement.list_learned_steps(user.id), & &1.code) == ["SC", "BF"]
    end
  end
end
