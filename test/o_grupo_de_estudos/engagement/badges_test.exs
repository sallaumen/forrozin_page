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

  describe "all_badges/0" do
    test "returns exactly 6 badge definitions" do
      assert length(Badges.all_badges()) == 6
    end

    test "every badge definition has the required keys" do
      for badge <- Badges.all_badges() do
        assert Map.has_key?(badge, :key)
        assert Map.has_key?(badge, :name)
        assert Map.has_key?(badge, :icon)
        assert Map.has_key?(badge, :threshold)
        assert Map.has_key?(badge, :metric)
      end
    end

    test "badge keys are unique" do
      keys = Badges.all_badges() |> Enum.map(& &1.key)
      assert keys == Enum.uniq(keys)
    end
  end

  describe "likes_received badges" do
    test "marks Popular as earned when user received 10+ likes on comments" do
      user = insert(:user)
      step = insert(:step)
      {:ok, comment} = Engagement.create_step_comment(user, step.id, %{body: "Meu comentário"})

      for _ <- 1..10 do
        liker = insert(:user)
        Engagement.toggle_like(liker.id, "step_comment", comment.id)
      end

      badges = Badges.compute(user.id)
      popular = Enum.find(badges, &(&1.key == :popular))
      assert popular.earned
      assert popular.current >= 10
    end

    test "marks Estrela as earned when user received 25+ likes on comments" do
      user = insert(:user)
      step = insert(:step)
      {:ok, comment} = Engagement.create_step_comment(user, step.id, %{body: "Meu comentário"})

      for _ <- 1..25 do
        liker = insert(:user)
        Engagement.toggle_like(liker.id, "step_comment", comment.id)
      end

      badges = Badges.compute(user.id)
      estrela = Enum.find(badges, &(&1.key == :estrela))
      assert estrela.earned
      assert estrela.current >= 25
      assert estrela.progress == 1.0
    end
  end

  describe "comments_count badges" do
    test "marks Voz Ativa as earned when user made 15+ comments" do
      user = insert(:user)
      step = insert(:step)

      for i <- 1..15 do
        Engagement.create_step_comment(user, step.id, %{body: "Comentário #{i}"})
      end

      badges = Badges.compute(user.id)
      voz_ativa = Enum.find(badges, &(&1.key == :voz_ativa))
      assert voz_ativa.earned
      assert voz_ativa.current >= 15
    end

    test "Comentarista progress caps at 1.0 even with more than threshold comments" do
      user = insert(:user)
      step = insert(:step)

      for i <- 1..10 do
        Engagement.create_step_comment(user, step.id, %{body: "Comentário #{i}"})
      end

      badges = Badges.compute(user.id)
      comentarista = Enum.find(badges, &(&1.key == :comentarista))
      assert comentarista.earned
      assert comentarista.progress == 1.0
    end
  end

  describe "compute/1 badge structure" do
    test "all computed badges have earned, current and progress fields" do
      user = insert(:user)
      badges = Badges.compute(user.id)

      for badge <- badges do
        assert Map.has_key?(badge, :earned)
        assert Map.has_key?(badge, :current)
        assert Map.has_key?(badge, :progress)
        assert badge.progress >= 0.0
        assert badge.progress <= 1.0
      end
    end

    test "earning a lower-tier badge does not mark higher-tier badge as earned" do
      user = insert(:user)

      # 5 likes — only Explorador (threshold 5) earned, not Curador (threshold 15)
      for _ <- 1..5 do
        step = insert(:step)
        Engagement.toggle_like(user.id, "step", step.id)
      end

      badges = Badges.compute(user.id)
      explorador = Enum.find(badges, &(&1.key == :explorador))
      curador = Enum.find(badges, &(&1.key == :curador))
      assert explorador.earned
      refute curador.earned
    end
  end
end
