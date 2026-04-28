defmodule OGrupoDeEstudos.Media do
  @moduledoc """
  Media context — 3D animations for steps and category pose defaults.

  Provides animation keyframes for the Three.js dance visualization.
  Each step can have custom keyframes; if not, falls back to the
  category's default pose.
  """

  import Ecto.Query
  alias OGrupoDeEstudos.Media.{CategoryPoseDefault, StepAnimation}
  alias OGrupoDeEstudos.Repo

  # ── Step Animations ──────────────────────────────────────────────────

  @doc "Get animation for a specific step."
  def get_step_animation(step_id) do
    Repo.get_by(StepAnimation, step_id: step_id)
  end

  @doc "Get animations for multiple steps at once."
  def get_step_animations(step_ids) when is_list(step_ids) do
    from(a in StepAnimation, where: a.step_id in ^step_ids)
    |> Repo.all()
    |> Map.new(&{&1.step_id, &1})
  end

  @doc "Create or update animation for a step."
  def upsert_step_animation(step_id, keyframes, duration_ms \\ 2000) do
    case get_step_animation(step_id) do
      nil ->
        %StepAnimation{}
        |> StepAnimation.changeset(%{
          step_id: step_id,
          keyframes: keyframes,
          duration_ms: duration_ms
        })
        |> Repo.insert()

      existing ->
        existing
        |> StepAnimation.changeset(%{keyframes: keyframes, duration_ms: duration_ms})
        |> Repo.update()
    end
  end

  # ── Category Pose Defaults ──────────────────────────────────────────

  @doc "Get default pose for a category."
  def get_category_pose(category_id) do
    Repo.get_by(CategoryPoseDefault, category_id: category_id)
  end

  @doc "Get all category pose defaults as a map of category_id => pose."
  def all_category_poses do
    from(p in CategoryPoseDefault)
    |> Repo.all()
    |> Map.new(&{&1.category_id, &1})
  end

  @doc "Create or update default pose for a category."
  def upsert_category_pose(category_id, keyframes, duration_ms \\ 2000) do
    case get_category_pose(category_id) do
      nil ->
        %CategoryPoseDefault{}
        |> CategoryPoseDefault.changeset(%{
          category_id: category_id,
          keyframes: keyframes,
          duration_ms: duration_ms
        })
        |> Repo.insert()

      existing ->
        existing
        |> CategoryPoseDefault.changeset(%{keyframes: keyframes, duration_ms: duration_ms})
        |> Repo.update()
    end
  end

  # ── Animation Data for Sequences ────────────────────────────────────

  @doc """
  Build animation data for a sequence of steps.

  Returns a list of maps with step info + keyframes.
  Falls back to category default if step has no custom animation.
  Falls back to a neutral standing pose if category has no default either.
  """
  def build_sequence_animation(steps) when is_list(steps) do
    step_ids = Enum.map(steps, & &1.id)
    step_anims = get_step_animations(step_ids)
    category_poses = all_category_poses()

    Enum.map(steps, fn step ->
      anim = Map.get(step_anims, step.id)
      cat_pose = Map.get(category_poses, step.category_id)

      {keyframes, duration_ms} =
        cond do
          anim -> {anim.keyframes, anim.duration_ms}
          cat_pose -> {cat_pose.keyframes, cat_pose.duration_ms}
          true -> {neutral_pose(), 2000}
        end

      %{
        code: step.code,
        name: step.name,
        category: step.category.name,
        keyframes: keyframes,
        duration_ms: duration_ms
      }
    end)
  end

  @doc "A neutral dance hold pose — couple facing each other."
  def neutral_pose do
    [
      %{"t" => 0.0, "leader" => neutral_leader(), "follower" => neutral_follower()},
      %{"t" => 1.0, "leader" => neutral_leader(), "follower" => neutral_follower()}
    ]
  end

  # face-to-face distance
  @oz 0.35

  def neutral_leader do
    %{
      "hip" => %{"x" => 0, "y" => 0.92, "z" => 0},
      "torso" => %{"x" => 0, "y" => 1.22, "z" => 0},
      "neck" => %{"x" => 0, "y" => 1.42, "z" => 0},
      "head" => %{"x" => 0, "y" => 1.55, "z" => 0},
      "shoulder_l" => %{"x" => -0.17, "y" => 1.32, "z" => 0},
      "shoulder_r" => %{"x" => 0.17, "y" => 1.32, "z" => 0},
      "elbow_l" => %{"x" => -0.24, "y" => 1.10, "z" => 0.06},
      "hand_l" => %{"x" => -0.22, "y" => 0.95, "z" => 0.14},
      "elbow_r" => %{"x" => 0.14, "y" => 1.12, "z" => 0.16},
      "hand_r" => %{"x" => 0.06, "y" => 1.08, "z" => 0.30},
      "knee_l" => %{"x" => -0.09, "y" => 0.48, "z" => 0.02},
      "knee_r" => %{"x" => 0.09, "y" => 0.48, "z" => -0.02},
      "foot_l" => %{"x" => -0.09, "y" => 0.03, "z" => 0.04},
      "foot_r" => %{"x" => 0.09, "y" => 0.03, "z" => -0.04}
    }
  end

  def neutral_follower do
    oz = @oz

    %{
      "hip" => %{"x" => 0, "y" => 0.88, "z" => oz},
      "torso" => %{"x" => 0, "y" => 1.16, "z" => oz},
      "neck" => %{"x" => 0, "y" => 1.35, "z" => oz},
      "head" => %{"x" => 0, "y" => 1.47, "z" => oz},
      "shoulder_l" => %{"x" => -0.16, "y" => 1.26, "z" => oz},
      "shoulder_r" => %{"x" => 0.16, "y" => 1.26, "z" => oz},
      "elbow_l" => %{"x" => -0.10, "y" => 1.12, "z" => oz - 0.10},
      "hand_l" => %{"x" => -0.04, "y" => 1.22, "z" => oz - 0.22},
      "elbow_r" => %{"x" => 0.20, "y" => 1.04, "z" => oz - 0.04},
      "hand_r" => %{"x" => 0.22, "y" => 0.95, "z" => oz - 0.12},
      "knee_l" => %{"x" => -0.08, "y" => 0.46, "z" => oz - 0.02},
      "knee_r" => %{"x" => 0.08, "y" => 0.46, "z" => oz + 0.02},
      "foot_l" => %{"x" => -0.08, "y" => 0.03, "z" => oz - 0.04},
      "foot_r" => %{"x" => 0.08, "y" => 0.03, "z" => oz + 0.04}
    }
  end
end
