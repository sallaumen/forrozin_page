# Seeds: default 3D poses for each dance category
#
# Each category gets a set of keyframes defining how the leader
# and follower move during that type of step. These are procedural
# approximations — the admin can refine them later.

alias OGrupoDeEstudos.{Media, Repo}
alias OGrupoDeEstudos.Encyclopedia.Category

categories = Repo.all(Category)
category_map = Map.new(categories, &{&1.name, &1.id})

# Helper to build a body pose with offsets from neutral
defmodule PoseBuilder do
  @neutral_leader %{
    "hip" => %{"x" => 0.0, "y" => 0.95, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "torso" => %{"x" => 0.0, "y" => 1.25, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "neck" => %{"x" => 0.0, "y" => 1.50, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "head" => %{"x" => 0.0, "y" => 1.65, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "shoulder_l" => %{"x" => -0.2, "y" => 1.45, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "shoulder_r" => %{"x" => 0.2, "y" => 1.45, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "elbow_l" => %{"x" => -0.3, "y" => 1.20, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "elbow_r" => %{"x" => 0.3, "y" => 1.20, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "hand_l" => %{"x" => -0.35, "y" => 0.95, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "hand_r" => %{"x" => 0.35, "y" => 0.95, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "knee_l" => %{"x" => -0.1, "y" => 0.50, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "knee_r" => %{"x" => 0.1, "y" => 0.50, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "foot_l" => %{"x" => -0.1, "y" => 0.05, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "foot_r" => %{"x" => 0.1, "y" => 0.05, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0}
  }

  @neutral_follower %{
    "hip" => %{"x" => 0.6, "y" => 0.92, "z" => 0.0, "rx" => 0, "ry" => 3.14, "rz" => 0},
    "torso" => %{"x" => 0.6, "y" => 1.20, "z" => 0.0, "rx" => 0, "ry" => 3.14, "rz" => 0},
    "neck" => %{"x" => 0.6, "y" => 1.44, "z" => 0.0, "rx" => 0, "ry" => 3.14, "rz" => 0},
    "head" => %{"x" => 0.6, "y" => 1.58, "z" => 0.0, "rx" => 0, "ry" => 3.14, "rz" => 0},
    "shoulder_l" => %{"x" => 0.8, "y" => 1.39, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "shoulder_r" => %{"x" => 0.4, "y" => 1.39, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "elbow_l" => %{"x" => 0.9, "y" => 1.15, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "elbow_r" => %{"x" => 0.3, "y" => 1.15, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "hand_l" => %{"x" => 0.95, "y" => 0.92, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "hand_r" => %{"x" => 0.25, "y" => 0.92, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "knee_l" => %{"x" => 0.7, "y" => 0.48, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "knee_r" => %{"x" => 0.5, "y" => 0.48, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "foot_l" => %{"x" => 0.7, "y" => 0.05, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0},
    "foot_r" => %{"x" => 0.5, "y" => 0.05, "z" => 0.0, "rx" => 0, "ry" => 0, "rz" => 0}
  }

  def neutral_leader, do: @neutral_leader
  def neutral_follower, do: @neutral_follower

  # Apply deltas to a base pose
  def apply_deltas(base, deltas) do
    Enum.reduce(deltas, base, fn {joint, changes}, acc ->
      case Map.get(acc, joint) do
        nil -> acc
        current ->
          updated = Enum.reduce(changes, current, fn {key, delta}, j ->
            Map.update!(j, key, &(&1 + delta))
          end)
          Map.put(acc, joint, updated)
      end
    end)
  end
end

# ── Dance connection pose (arms connected in dance hold) ──
dance_hold_leader = PoseBuilder.apply_deltas(PoseBuilder.neutral_leader(), %{
  "elbow_r" => %{"x" => 0.05, "y" => 0.1, "z" => 0.15},
  "hand_r" => %{"x" => 0.15, "y" => 0.15, "z" => 0.1},
  "elbow_l" => %{"x" => 0.05, "y" => 0.0, "z" => 0.05},
  "hand_l" => %{"x" => 0.15, "y" => 0.05, "z" => 0.05}
})

dance_hold_follower = PoseBuilder.apply_deltas(PoseBuilder.neutral_follower(), %{
  "elbow_r" => %{"x" => -0.05, "y" => 0.1, "z" => 0.15},
  "hand_r" => %{"x" => -0.15, "y" => 0.15, "z" => 0.1},
  "elbow_l" => %{"x" => -0.05, "y" => 0.0, "z" => 0.05}
})

# ── Category-specific poses ──────────────────────────────────────────

poses = %{
  # BASES — basic weight transfer, subtle hip movement
  "bases" => %{
    keyframes: [
      %{"t" => 0.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower},
      %{"t" => 0.25, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hip" => %{"x" => -0.05, "z" => 0.03},
        "knee_l" => %{"y" => -0.03, "z" => 0.05},
        "foot_l" => %{"z" => 0.1}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "hip" => %{"x" => 0.05, "z" => -0.03},
        "knee_r" => %{"y" => -0.03, "z" => -0.05}
      })},
      %{"t" => 0.5, "leader" => dance_hold_leader, "follower" => dance_hold_follower},
      %{"t" => 0.75, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hip" => %{"x" => 0.05, "z" => -0.03},
        "knee_r" => %{"y" => -0.03, "z" => -0.05},
        "foot_r" => %{"z" => -0.1}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "hip" => %{"x" => -0.05, "z" => 0.03},
        "knee_l" => %{"y" => -0.03, "z" => 0.05}
      })},
      %{"t" => 1.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower}
    ],
    duration_ms: 2000
  },

  # SACADAS — leader opens space, follower steps into it
  "sacadas" => %{
    keyframes: [
      %{"t" => 0.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower},
      %{"t" => 0.3, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hip" => %{"x" => -0.1, "z" => 0.08},
        "torso" => %{"rx" => 0.1},
        "knee_l" => %{"y" => -0.08, "z" => 0.15},
        "foot_l" => %{"z" => 0.2}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "hip" => %{"x" => 0.08},
        "knee_r" => %{"y" => -0.05, "z" => -0.1}
      })},
      %{"t" => 0.7, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hip" => %{"x" => 0.05, "z" => -0.05},
        "torso" => %{"rx" => -0.05},
        "knee_r" => %{"y" => -0.1, "z" => -0.12},
        "foot_r" => %{"z" => -0.18}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "hip" => %{"x" => -0.1, "z" => 0.05},
        "torso" => %{"rx" => -0.08},
        "knee_l" => %{"y" => -0.08, "z" => 0.12}
      })},
      %{"t" => 1.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower}
    ],
    duration_ms: 2500
  },

  # GIROS — rotation movement
  "giros" => %{
    keyframes: [
      %{"t" => 0.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower},
      %{"t" => 0.3, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hand_r" => %{"y" => 0.4},
        "elbow_r" => %{"y" => 0.3}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "torso" => %{"ry" => 1.57},
        "hip" => %{"ry" => 1.57}
      })},
      %{"t" => 0.7, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hand_r" => %{"y" => 0.3},
        "elbow_r" => %{"y" => 0.2}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "torso" => %{"ry" => 4.71},
        "hip" => %{"ry" => 4.71}
      })},
      %{"t" => 1.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower}
    ],
    duration_ms: 2000
  },

  # TRAVAS — sudden stop/lock movement
  "travas" => %{
    keyframes: [
      %{"t" => 0.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower},
      %{"t" => 0.4, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hip" => %{"x" => -0.08, "z" => 0.06},
        "knee_l" => %{"y" => -0.12, "x" => 0.05, "z" => 0.1},
        "foot_l" => %{"z" => 0.15, "x" => 0.08}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "hip" => %{"x" => 0.06},
        "knee_r" => %{"y" => -0.1, "z" => -0.08}
      })},
      %{"t" => 0.5, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hip" => %{"x" => -0.08, "z" => 0.06},
        "knee_l" => %{"y" => -0.12, "x" => 0.05, "z" => 0.1},
        "foot_l" => %{"z" => 0.15, "x" => 0.08}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "hip" => %{"x" => 0.06},
        "knee_r" => %{"y" => -0.1, "z" => -0.08}
      })},
      %{"t" => 1.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower}
    ],
    duration_ms: 1800
  },

  # CAMINHADAS — walking movement
  "caminhadas" => %{
    keyframes: [
      %{"t" => 0.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower},
      %{"t" => 0.25, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hip" => %{"z" => 0.1},
        "torso" => %{"z" => 0.08},
        "knee_l" => %{"y" => -0.06, "z" => 0.15},
        "foot_l" => %{"z" => 0.25}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "hip" => %{"z" => 0.1},
        "torso" => %{"z" => 0.08},
        "knee_r" => %{"y" => -0.06, "z" => 0.15},
        "foot_r" => %{"z" => 0.25}
      })},
      %{"t" => 0.5, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hip" => %{"z" => 0.2},
        "torso" => %{"z" => 0.18}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "hip" => %{"z" => 0.2},
        "torso" => %{"z" => 0.18}
      })},
      %{"t" => 0.75, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hip" => %{"z" => 0.3},
        "torso" => %{"z" => 0.28},
        "knee_r" => %{"y" => -0.06, "z" => 0.35},
        "foot_r" => %{"z" => 0.45}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "hip" => %{"z" => 0.3},
        "torso" => %{"z" => 0.28},
        "knee_l" => %{"y" => -0.06, "z" => 0.35},
        "foot_l" => %{"z" => 0.45}
      })},
      %{"t" => 1.0, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hip" => %{"z" => 0.4},
        "torso" => %{"z" => 0.38}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "hip" => %{"z" => 0.4},
        "torso" => %{"z" => 0.38}
      })}
    ],
    duration_ms: 3000
  },

  # PESCADAS — quick catch/hook movement
  "pescadas" => %{
    keyframes: [
      %{"t" => 0.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower},
      %{"t" => 0.4, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "knee_l" => %{"y" => -0.15, "z" => 0.05, "x" => 0.15},
        "foot_l" => %{"y" => 0.1, "z" => 0.08, "x" => 0.2}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "knee_r" => %{"y" => -0.08},
        "foot_r" => %{"y" => 0.05}
      })},
      %{"t" => 0.6, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "knee_l" => %{"y" => -0.15, "z" => 0.05, "x" => 0.15},
        "foot_l" => %{"y" => 0.1, "z" => 0.08, "x" => 0.2}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "knee_r" => %{"y" => -0.08},
        "foot_r" => %{"y" => 0.05}
      })},
      %{"t" => 1.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower}
    ],
    duration_ms: 1500
  },

  # INVERSAO — direction reversal
  "inversao" => %{
    keyframes: [
      %{"t" => 0.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower},
      %{"t" => 0.3, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hip" => %{"z" => 0.08},
        "torso" => %{"rx" => 0.08}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "hip" => %{"z" => -0.08},
        "torso" => %{"rx" => -0.08}
      })},
      %{"t" => 0.5, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hip" => %{"ry" => 0.5},
        "torso" => %{"ry" => 0.5}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "hip" => %{"ry" => -0.5},
        "torso" => %{"ry" => -0.5}
      })},
      %{"t" => 1.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower}
    ],
    duration_ms: 2000
  },

  # OUTROS — generic movement
  "outros" => %{
    keyframes: [
      %{"t" => 0.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower},
      %{"t" => 0.5, "leader" => PoseBuilder.apply_deltas(dance_hold_leader, %{
        "hip" => %{"x" => -0.05, "z" => 0.05},
        "knee_l" => %{"y" => -0.05, "z" => 0.08}
      }), "follower" => PoseBuilder.apply_deltas(dance_hold_follower, %{
        "hip" => %{"x" => 0.05, "z" => -0.05},
        "knee_r" => %{"y" => -0.05, "z" => -0.08}
      })},
      %{"t" => 1.0, "leader" => dance_hold_leader, "follower" => dance_hold_follower}
    ],
    duration_ms: 2000
  }
}

# Insert poses for each category
for {cat_name, pose_data} <- poses do
  case Map.get(category_map, cat_name) do
    nil ->
      IO.puts("  Skipping #{cat_name} (category not found)")

    category_id ->
      case Media.upsert_category_pose(category_id, pose_data.keyframes, pose_data.duration_ms) do
        {:ok, _} -> IO.puts("  ✓ #{cat_name}")
        {:error, changeset} -> IO.puts("  ✗ #{cat_name}: #{inspect(changeset.errors)}")
      end
  end
end

IO.puts("\nCategory poses seeded!")
