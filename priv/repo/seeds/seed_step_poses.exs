# Seeds: specific 3D poses for BF, SC, BL, GP
#
# These are hand-crafted keyframes for the most basic forró steps.
# Leader at origin facing +Z, follower at z=0.35 facing -Z (towards leader).

alias OGrupoDeEstudos.{Media, Repo}
alias OGrupoDeEstudos.Encyclopedia.Step
import Ecto.Query

# Fetch step IDs
steps = Repo.all(from s in Step, where: s.code in ["BF", "SC", "BL", "GP"], select: {s.code, s.id})
step_map = Map.new(steps)

IO.puts("Found steps: #{inspect(Map.keys(step_map))}")

# ── Helpers ──────────────────────────────────────────────────────────

oz = 0.35  # follower z offset

# Base neutral poses (dance hold, face to face)
nl = %{
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

nf = %{
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

# Apply delta to a pose
apply = fn base, deltas ->
  Enum.reduce(deltas, base, fn {joint, changes}, acc ->
    case Map.get(acc, joint) do
      nil -> acc
      current ->
        updated = Enum.reduce(changes, current, fn {k, v}, j ->
          Map.update!(j, k, &(&1 + v))
        end)
        Map.put(acc, joint, updated)
    end
  end)
end

# ── BF: Base Frontal ─────────────────────────────────────────────────
# Leader: left foot forward → center → right foot back → center
# Follower mirrors: right foot back → center → left foot forward → center
# Subtle weight transfer, knees bending, center of mass moving

# Centro de massa: when foot moves, EVERYTHING moves together
# (hip, torso, neck, head, shoulders, elbows, hands)
fwd = 0.08  # forward displacement
bck = -0.08  # backward displacement
dip = -0.025  # slight drop when weight transfers

# All upper body joints that follow the center of mass
cm_fwd = %{
  "hip" => %{"z" => fwd, "y" => dip},
  "torso" => %{"z" => fwd * 0.9, "y" => dip * 0.7},
  "neck" => %{"z" => fwd * 0.85},
  "head" => %{"z" => fwd * 0.8},
  "shoulder_l" => %{"z" => fwd * 0.85},
  "shoulder_r" => %{"z" => fwd * 0.85},
  "elbow_l" => %{"z" => fwd * 0.7},
  "elbow_r" => %{"z" => fwd * 0.7},
  "hand_l" => %{"z" => fwd * 0.6},
  "hand_r" => %{"z" => fwd * 0.6}
}

cm_bck = %{
  "hip" => %{"z" => bck, "y" => dip},
  "torso" => %{"z" => bck * 0.9, "y" => dip * 0.7},
  "neck" => %{"z" => bck * 0.85},
  "head" => %{"z" => bck * 0.8},
  "shoulder_l" => %{"z" => bck * 0.85},
  "shoulder_r" => %{"z" => bck * 0.85},
  "elbow_l" => %{"z" => bck * 0.7},
  "elbow_r" => %{"z" => bck * 0.7},
  "hand_l" => %{"z" => bck * 0.6},
  "hand_r" => %{"z" => bck * 0.6}
}

# BF repeats 2x for better observation
bf_fwd_leader = apply.(apply.(nl, cm_fwd), %{
  "knee_l" => %{"z" => 0.12, "y" => -0.05},
  "foot_l" => %{"z" => 0.16},
  "knee_r" => %{"y" => -0.02}
})

bf_fwd_follower = apply.(apply.(nf, %{
  "hip" => %{"z" => fwd, "y" => dip},
  "torso" => %{"z" => fwd * 0.9},
  "neck" => %{"z" => fwd * 0.85},
  "head" => %{"z" => fwd * 0.8},
  "shoulder_l" => %{"z" => fwd * 0.85},
  "shoulder_r" => %{"z" => fwd * 0.85},
  "elbow_l" => %{"z" => fwd * 0.7},
  "elbow_r" => %{"z" => fwd * 0.7},
  "hand_l" => %{"z" => fwd * 0.6},
  "hand_r" => %{"z" => fwd * 0.6}
}), %{
  "knee_r" => %{"z" => 0.12, "y" => -0.05},
  "foot_r" => %{"z" => 0.16},
  "knee_l" => %{"y" => -0.02}
})

bf_bck_leader = apply.(apply.(nl, cm_bck), %{
  "knee_r" => %{"z" => -0.12, "y" => -0.05},
  "foot_r" => %{"z" => -0.16},
  "knee_l" => %{"y" => -0.02}
})

bf_bck_follower = apply.(apply.(nf, %{
  "hip" => %{"z" => bck, "y" => dip},
  "torso" => %{"z" => bck * 0.9},
  "neck" => %{"z" => bck * 0.85},
  "head" => %{"z" => bck * 0.8},
  "shoulder_l" => %{"z" => bck * 0.85},
  "shoulder_r" => %{"z" => bck * 0.85},
  "elbow_l" => %{"z" => bck * 0.7},
  "elbow_r" => %{"z" => bck * 0.7},
  "hand_l" => %{"z" => bck * 0.6},
  "hand_r" => %{"z" => bck * 0.6}
}), %{
  "knee_l" => %{"z" => -0.12, "y" => -0.05},
  "foot_l" => %{"z" => -0.16},
  "knee_r" => %{"y" => -0.02}
})

bf_keyframes = [
  %{"t" => 0.0, "leader" => nl, "follower" => nf},
  # Rep 1
  %{"t" => 0.12, "leader" => bf_fwd_leader, "follower" => bf_fwd_follower},
  %{"t" => 0.25, "leader" => nl, "follower" => nf},
  %{"t" => 0.37, "leader" => bf_bck_leader, "follower" => bf_bck_follower},
  %{"t" => 0.5, "leader" => nl, "follower" => nf},
  # Rep 2
  %{"t" => 0.62, "leader" => bf_fwd_leader, "follower" => bf_fwd_follower},
  %{"t" => 0.75, "leader" => nl, "follower" => nf},
  %{"t" => 0.87, "leader" => bf_bck_leader, "follower" => bf_bck_follower},
  %{"t" => 1.0, "leader" => nl, "follower" => nf}
]

# ── SC: Sacada Simples ───────────────────────────────────────────────
# Leader opens hip creating space, foot goes under/through follower's space
# The "sacada" is a displacement — leader's leg enters follower's space

# SC: full body moves with center of mass during sacada
sc_cm_side = fn dir ->
  d = dir * 0.06
  %{
    "hip" => %{"x" => d, "y" => -0.03},
    "torso" => %{"x" => d * 0.9},
    "neck" => %{"x" => d * 0.85},
    "head" => %{"x" => d * 0.8},
    "shoulder_l" => %{"x" => d * 0.85},
    "shoulder_r" => %{"x" => d * 0.85},
    "elbow_l" => %{"x" => d * 0.7},
    "elbow_r" => %{"x" => d * 0.7},
    "hand_l" => %{"x" => d * 0.5},
    "hand_r" => %{"x" => d * 0.5}
  }
end

sc_keyframes = [
  %{"t" => 0.0, "leader" => nl, "follower" => nf},

  # Leader creates intention: body shifts left, weight on left leg
  %{"t" => 0.2, "leader" => apply.(apply.(nl, sc_cm_side.(-1)), %{
    "knee_l" => %{"x" => -0.04, "y" => -0.06},
    "knee_r" => %{"y" => -0.03}
  }), "follower" => apply.(nf, sc_cm_side.(-0.5))},

  # Sacada: leader's body advances forward+left, right leg enters follower's space
  %{"t" => 0.5, "leader" => apply.(apply.(nl, %{
    "hip" => %{"x" => -0.08, "y" => -0.04, "z" => 0.06},
    "torso" => %{"x" => -0.06, "z" => 0.05},
    "neck" => %{"x" => -0.05, "z" => 0.04},
    "head" => %{"x" => -0.04, "z" => 0.03},
    "shoulder_l" => %{"x" => -0.05, "z" => 0.04},
    "shoulder_r" => %{"x" => -0.05, "z" => 0.04},
    "elbow_l" => %{"x" => -0.04, "z" => 0.03},
    "elbow_r" => %{"x" => -0.04, "z" => 0.03}
  }), %{
    "knee_r" => %{"z" => 0.18, "x" => 0.02, "y" => -0.06},
    "foot_r" => %{"z" => 0.25, "x" => 0.04},
    "knee_l" => %{"y" => -0.06}
  }), "follower" => apply.(apply.(nf, %{
    "hip" => %{"x" => -0.08, "y" => -0.02},
    "torso" => %{"x" => -0.06},
    "neck" => %{"x" => -0.05},
    "head" => %{"x" => -0.04},
    "shoulder_l" => %{"x" => -0.05},
    "shoulder_r" => %{"x" => -0.05}
  }), %{
    "knee_l" => %{"x" => -0.06, "z" => -0.08, "y" => -0.05},
    "foot_l" => %{"x" => -0.10, "z" => -0.12}
  })},

  # Recovery
  %{"t" => 0.8, "leader" => apply.(nl, %{
    "hip" => %{"x" => -0.03, "z" => 0.03},
    "torso" => %{"x" => -0.02, "z" => 0.02},
    "knee_r" => %{"z" => 0.08, "y" => -0.03}
  }), "follower" => apply.(nf, %{
    "hip" => %{"x" => -0.03},
    "torso" => %{"x" => -0.02}
  })},

  %{"t" => 1.0, "leader" => nl, "follower" => nf}
]

# ── BL: Abertura Lateral ──────────────────────────────────────────────
# V opening: both dancers rotate in the SAME visual direction.
# Top-down: they both rotate clockwise for right V, counter-clockwise for left V.
# Hands stay connected at center. Bodies angle away creating the V shape.
# Repeats 2x for better observation.
#
# Coordinate reminder:
# - Leader at z=0 facing +Z, Follower at z=0.35 facing -Z
# - +X = screen right, -X = screen left
# - Leader's "back" = -Z, Follower's "back" = +Z

# Hand-to-hand position (released from embrace)
hh_l = apply.(nl, %{
  "elbow_l" => %{"x" => 0.04, "z" => 0.06},
  "hand_l" => %{"x" => 0.0, "y" => 0.03, "z" => 0.10},
  "elbow_r" => %{"x" => -0.04, "z" => 0.02},
  "hand_r" => %{"x" => -0.02, "y" => -0.06, "z" => 0.04}
})

hh_f = apply.(nf, %{
  "elbow_l" => %{"x" => 0.04, "z" => -0.06},
  "hand_l" => %{"x" => 0.0, "y" => -0.12, "z" => -0.08},
  "elbow_r" => %{"x" => -0.04, "z" => -0.02},
  "hand_r" => %{"x" => 0.02, "y" => -0.02, "z" => -0.04}
})

# V opening RIGHT (+X side):
# Leader: body shifts +X, left leg goes back (-Z) and to +X side
# Follower: body shifts +X too (same visual dir), right leg goes back (+Z) and to +X side
# Both rotate clockwise from top view
vr_l = apply.(hh_l, %{
  "hip" => %{"x" => 0.06, "y" => -0.02},
  "torso" => %{"x" => 0.06},
  "neck" => %{"x" => 0.05},
  "head" => %{"x" => 0.05},
  "shoulder_l" => %{"x" => 0.08, "z" => -0.04},
  "shoulder_r" => %{"x" => 0.03, "z" => 0.04},
  "elbow_l" => %{"x" => 0.08, "z" => -0.06},
  "hand_l" => %{"x" => 0.0, "z" => 0.0},         # stays connected
  "knee_l" => %{"x" => 0.10, "z" => -0.14, "y" => -0.04},
  "foot_l" => %{"x" => 0.14, "z" => -0.20},
  "knee_r" => %{"x" => 0.03, "y" => -0.05}
})

vr_f = apply.(hh_f, %{
  "hip" => %{"x" => 0.06, "y" => -0.02},
  "torso" => %{"x" => 0.06},
  "neck" => %{"x" => 0.05},
  "head" => %{"x" => 0.05},
  "shoulder_l" => %{"x" => 0.03, "z" => -0.04},
  "shoulder_r" => %{"x" => 0.08, "z" => 0.04},
  "elbow_r" => %{"x" => 0.08, "z" => 0.06},
  "hand_r" => %{"x" => 0.0, "z" => 0.0},          # stays connected
  "knee_r" => %{"x" => 0.10, "z" => 0.14, "y" => -0.04},
  "foot_r" => %{"x" => 0.14, "z" => 0.20},
  "knee_l" => %{"x" => 0.03, "y" => -0.05}
})

# V opening LEFT (-X side): mirror of right
vl_l = apply.(hh_l, %{
  "hip" => %{"x" => -0.06, "y" => -0.02},
  "torso" => %{"x" => -0.06},
  "neck" => %{"x" => -0.05},
  "head" => %{"x" => -0.05},
  "shoulder_l" => %{"x" => -0.03, "z" => 0.04},
  "shoulder_r" => %{"x" => -0.08, "z" => -0.04},
  "elbow_r" => %{"x" => -0.08, "z" => -0.06},
  "hand_r" => %{"x" => 0.0, "z" => 0.0},
  "knee_r" => %{"x" => -0.10, "z" => -0.14, "y" => -0.04},
  "foot_r" => %{"x" => -0.14, "z" => -0.20},
  "knee_l" => %{"x" => -0.03, "y" => -0.05}
})

vl_f = apply.(hh_f, %{
  "hip" => %{"x" => -0.06, "y" => -0.02},
  "torso" => %{"x" => -0.06},
  "neck" => %{"x" => -0.05},
  "head" => %{"x" => -0.05},
  "shoulder_l" => %{"x" => -0.08, "z" => -0.04},
  "shoulder_r" => %{"x" => -0.03, "z" => 0.04},
  "elbow_l" => %{"x" => -0.08, "z" => 0.06},
  "hand_l" => %{"x" => 0.0, "z" => 0.0},
  "knee_l" => %{"x" => -0.10, "z" => 0.14, "y" => -0.04},
  "foot_l" => %{"x" => -0.14, "z" => 0.20},
  "knee_r" => %{"x" => -0.03, "y" => -0.05}
})

# BL keyframes: embrace → hand-hold → V right → center → V left → center → V right → center → V left → embrace
bl_keyframes = [
  %{"t" => 0.0, "leader" => nl, "follower" => nf},
  %{"t" => 0.05, "leader" => hh_l, "follower" => hh_f},
  # Rep 1
  %{"t" => 0.15, "leader" => vr_l, "follower" => vr_f},
  %{"t" => 0.27, "leader" => hh_l, "follower" => hh_f},
  %{"t" => 0.37, "leader" => vl_l, "follower" => vl_f},
  %{"t" => 0.49, "leader" => hh_l, "follower" => hh_f},
  # Rep 2
  %{"t" => 0.55, "leader" => vr_l, "follower" => vr_f},
  %{"t" => 0.67, "leader" => hh_l, "follower" => hh_f},
  %{"t" => 0.77, "leader" => vl_l, "follower" => vl_f},
  %{"t" => 0.89, "leader" => hh_l, "follower" => hh_f},
  %{"t" => 1.0, "leader" => nl, "follower" => nf}
]

# ── GP: Giro Paulista ────────────────────────────────────────────────
# Leader raises right arm, follower turns 360° under it
# Follower's body rotates while leader stays mostly stable

# Follower mid-turn: she's sideways (90° turn), still connected
gp_follower_90 = apply.(nf, %{
  "hip" => %{"x" => 0.08},
  "torso" => %{"x" => 0.06},
  "head" => %{"x" => 0.05},
  "neck" => %{"x" => 0.06},
  "shoulder_l" => %{"x" => 0.05, "z" => 0.10},
  "shoulder_r" => %{"x" => 0.05, "z" => -0.10},
  "elbow_l" => %{"x" => 0.15, "z" => 0.15},
  "hand_l" => %{"x" => 0.20, "z" => 0.15},
  "elbow_r" => %{"x" => -0.10, "z" => -0.10},
  "hand_r" => %{"x" => -0.10, "z" => -0.08},
  "knee_l" => %{"x" => 0.04},
  "knee_r" => %{"x" => 0.04},
  "foot_l" => %{"x" => 0.04},
  "foot_r" => %{"x" => 0.04}
})

# Follower at 180°: she faces away from leader
gp_follower_180 = apply.(nf, %{
  "hip" => %{"z" => 0.10},
  "torso" => %{"z" => 0.08},
  "head" => %{"z" => 0.06},
  "neck" => %{"z" => 0.07},
  "shoulder_l" => %{"z" => 0.06},
  "shoulder_r" => %{"z" => 0.06},
  "elbow_l" => %{"z" => 0.12},
  "hand_l" => %{"z" => 0.15},
  "elbow_r" => %{"z" => 0.12},
  "hand_r" => %{"z" => 0.10}
})

# Follower at 270°: coming back around
gp_follower_270 = apply.(nf, %{
  "hip" => %{"x" => -0.08},
  "torso" => %{"x" => -0.06},
  "head" => %{"x" => -0.05},
  "neck" => %{"x" => -0.06},
  "shoulder_l" => %{"x" => -0.05, "z" => -0.10},
  "shoulder_r" => %{"x" => -0.05, "z" => 0.10},
  "elbow_l" => %{"x" => -0.15, "z" => -0.10},
  "hand_l" => %{"x" => -0.18, "z" => -0.08},
  "elbow_r" => %{"x" => 0.10, "z" => 0.12},
  "hand_r" => %{"x" => 0.15, "z" => 0.15}
})

gp_keyframes = [
  # Start
  %{"t" => 0.0, "leader" => nl, "follower" => nf},

  # Leader raises right arm, signals turn
  %{"t" => 0.15, "leader" => apply.(nl, %{
    "elbow_r" => %{"y" => 0.25, "z" => 0.05},
    "hand_r" => %{"y" => 0.50, "z" => 0.10}
  }), "follower" => nf},

  # Follower at 90° (sideways)
  %{"t" => 0.35, "leader" => apply.(nl, %{
    "elbow_r" => %{"y" => 0.30, "z" => 0.05},
    "hand_r" => %{"y" => 0.55, "z" => 0.08}
  }), "follower" => gp_follower_90},

  # Follower at 180° (facing away)
  %{"t" => 0.55, "leader" => apply.(nl, %{
    "elbow_r" => %{"y" => 0.28, "z" => 0.03},
    "hand_r" => %{"y" => 0.50, "z" => 0.06}
  }), "follower" => gp_follower_180},

  # Follower at 270° (coming back)
  %{"t" => 0.75, "leader" => apply.(nl, %{
    "elbow_r" => %{"y" => 0.22, "z" => 0.04},
    "hand_r" => %{"y" => 0.40, "z" => 0.08}
  }), "follower" => gp_follower_270},

  # Back to dance hold
  %{"t" => 1.0, "leader" => nl, "follower" => nf}
]

# ── Insert step-specific poses ───────────────────────────────────────

poses = %{
  "BF" => %{keyframes: bf_keyframes, duration_ms: 3200},
  "SC" => %{keyframes: sc_keyframes, duration_ms: 3000},
  "BL" => %{keyframes: bl_keyframes, duration_ms: 5000},
  "GP" => %{keyframes: gp_keyframes, duration_ms: 3500}
}

for {code, pose_data} <- poses do
  case Map.get(step_map, code) do
    nil ->
      IO.puts("  Skipping #{code} (step not found)")

    step_id ->
      case Media.upsert_step_animation(step_id, pose_data.keyframes, pose_data.duration_ms) do
        {:ok, _} -> IO.puts("  ✓ #{code}")
        {:error, cs} -> IO.puts("  ✗ #{code}: #{inspect(cs.errors)}")
      end
  end
end

IO.puts("\nStep-specific poses seeded!")
