defmodule OGrupoDeEstudos.Engagement.BadgesTest do
  use OGrupoDeEstudos.DataCase, async: true
  import OGrupoDeEstudos.Factory
  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Engagement.Badges

  describe "compute/1" do
    test "returns all 6 badges with earned: false for new user" do
      user = insert(:user)
      badges = Badges.compute(user.id)
      assert length(badges) == 6
      assert Enum.all?(badges, fn b -> b.earned == false end)
    end

    test "marks Explorador as earned when user liked 5+ steps" do
      user = insert(:user)
      for _ <- 1..5 do
        step = insert(:step)
        Engagement.toggle_like(user.id, "step", step.id)
      end
      badges = Badges.compute(user.id)
      explorador = Enum.find(badges, &(&1.key == :explorador))
      assert explorador.earned
      assert explorador.current == 5
      assert explorador.progress == 1.0
    end

    test "marks Comentarista as earned when user made 5+ comments" do
      user = insert(:user)
      step = insert(:step)
      for i <- 1..5 do
        Engagement.create_step_comment(user, step.id, %{body: "Comment #{i}"})
      end
      badges = Badges.compute(user.id)
      comentarista = Enum.find(badges, &(&1.key == :comentarista))
      assert comentarista.earned
    end

    test "computes progress correctly for partial achievement" do
      user = insert(:user)
      for _ <- 1..3 do
        step = insert(:step)
        Engagement.toggle_like(user.id, "step", step.id)
      end
      badges = Badges.compute(user.id)
      explorador = Enum.find(badges, &(&1.key == :explorador))
      refute explorador.earned
      assert explorador.current == 3
      assert_in_delta explorador.progress, 0.6, 0.01
    end
  end

  describe "primary/1" do
    test "returns nil for new user" do
      user = insert(:user)
      assert is_nil(Badges.primary(user.id))
    end

    test "returns highest-rank earned badge" do
      user = insert(:user)
      for _ <- 1..15 do
        step = insert(:step)
        Engagement.toggle_like(user.id, "step", step.id)
      end
      badge = Badges.primary(user.id)
      # With 15 likes: Curador (15 threshold) is earned AND higher rank than Explorador (5)
      assert badge.key == :curador
    end
  end
end
