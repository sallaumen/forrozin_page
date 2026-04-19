// ---------------------------------------------------------------------------
// ThreeCanvas — 3D forró dance visualization
//
// Geometric mannequin couple facing each other in close embrace.
// Leader (gold) at origin facing +Z, Follower (coral) at z=0.35 facing -Z.
// ---------------------------------------------------------------------------

let THREE = null
let OrbitControls = null

const JOINTS = [
  "hip", "torso", "neck", "head",
  "shoulder_l", "shoulder_r",
  "elbow_l", "elbow_r",
  "hand_l", "hand_r",
  "knee_l", "knee_r",
  "foot_l", "foot_r"
]

// Limb connections for drawing capsules between joints
const LIMBS = [
  ["hip", "torso"],
  ["torso", "neck"],
  ["neck", "head"],
  ["torso", "shoulder_l"],
  ["torso", "shoulder_r"],
  ["shoulder_l", "elbow_l"],
  ["shoulder_r", "elbow_r"],
  ["elbow_l", "hand_l"],
  ["elbow_r", "hand_r"],
  ["hip", "knee_l"],
  ["hip", "knee_r"],
  ["knee_l", "foot_l"],
  ["knee_r", "foot_r"]
]

// Limb thickness — chunkier for friendly look
const LIMB_RADIUS = {
  "hip-torso": 0.075,       // thick torso
  "torso-neck": 0.05,       // neck
  "neck-head": 0.001,       // invisible (head sits on neck)
  "torso-shoulder_l": 0.045, // shoulder area
  "torso-shoulder_r": 0.045,
  "shoulder_l-elbow_l": 0.038, // upper arm
  "shoulder_r-elbow_r": 0.038,
  "elbow_l-hand_l": 0.032,    // forearm
  "elbow_r-hand_r": 0.032,
  "hip-knee_l": 0.05,         // thick thigh
  "hip-knee_r": 0.05,
  "knee_l-foot_l": 0.04,      // calf
  "knee_r-foot_r": 0.04
}

// Joint visual sizes — Human Fall Flat style: round, chunky, friendly
const JOINT_VIS = {
  head:       { type: "sphere", r: 0.11 },       // big round head
  neck:       { type: "sphere", r: 0.001 },       // invisible pivot
  torso:      { type: "sphere", r: 0.001 },       // invisible pivot
  hip:        { type: "sphere", r: 0.001 },        // invisible pivot
  shoulder_l: { type: "sphere", r: 0.04 },        // rounded shoulder
  shoulder_r: { type: "sphere", r: 0.04 },
  elbow_l:    { type: "sphere", r: 0.035 },       // smooth elbow
  elbow_r:    { type: "sphere", r: 0.035 },
  hand_l:     { type: "sphere", r: 0.038 },       // chubby hands
  hand_r:     { type: "sphere", r: 0.038 },
  knee_l:     { type: "sphere", r: 0.038 },       // smooth knee
  knee_r:     { type: "sphere", r: 0.038 },
  foot_l:     { type: "capsule", r: 0.04, l: 0.06 },  // rounded feet
  foot_r:     { type: "capsule", r: 0.04, l: 0.06 }
}

function easeInOutCubic(t) {
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2
}

function lerp(a, b, t) { return a + (b - a) * t }

function interpolatePose(keyframes, t) {
  if (!keyframes || keyframes.length === 0) return null
  if (keyframes.length === 1) return keyframes[0]
  t = Math.max(0, Math.min(1, t))

  let k0 = keyframes[0], k1 = keyframes[keyframes.length - 1]
  for (let i = 0; i < keyframes.length - 1; i++) {
    if (t >= keyframes[i].t && t <= keyframes[i + 1].t) {
      k0 = keyframes[i]; k1 = keyframes[i + 1]; break
    }
  }

  const seg = k1.t - k0.t
  const lt = seg > 0 ? (t - k0.t) / seg : 0
  const et = easeInOutCubic(lt)

  const result = { leader: {}, follower: {} }
  for (const role of ["leader", "follower"]) {
    if (!k0[role] || !k1[role]) continue
    for (const j of JOINTS) {
      if (!k0[role][j] || !k1[role][j]) continue
      const a = k0[role][j], b = k1[role][j]
      result[role][j] = {
        x: lerp(a.x, b.x, et), y: lerp(a.y, b.y, et), z: lerp(a.z, b.z, et)
      }
    }
  }
  return result
}

// ── Mannequin builder ────────────────────────────────────────────────

function createMannequin(color) {
  const group = new THREE.Group()
  // Smooth clay material — bright, warm, friendly
  const mat = new THREE.MeshStandardMaterial({
    color: new THREE.Color(color),
    roughness: 0.55,
    metalness: 0.02,
    emissive: new THREE.Color(color),
    emissiveIntensity: 0.12
  })

  const joints = {}
  for (const [name, def] of Object.entries(JOINT_VIS)) {
    let mesh
    if (def.type === "sphere") {
      mesh = new THREE.Mesh(new THREE.SphereGeometry(def.r, 20, 16), mat.clone())
    } else if (def.type === "capsule") {
      mesh = new THREE.Mesh(new THREE.CapsuleGeometry(def.r, def.l, 8, 12), mat.clone())
    } else {
      mesh = new THREE.Mesh(new THREE.BoxGeometry(def.w, def.h, def.d), mat.clone())
    }
    mesh.castShadow = true
    mesh.receiveShadow = true
    group.add(mesh)
    joints[name] = mesh
  }

  const limbs = {}
  for (const [parent, child] of LIMBS) {
    const key = `${parent}-${child}`
    const r = LIMB_RADIUS[key] || 0.03
    const limbMesh = new THREE.Mesh(
      new THREE.CapsuleGeometry(r, 1, 6, 10),
      mat.clone()
    )
    limbMesh.castShadow = true
    group.add(limbMesh)
    limbs[key] = limbMesh
  }

  return { group, joints, limbs }
}

function positionLimb(mesh, pA, pB) {
  const a = new THREE.Vector3(pA.x, pA.y, pA.z)
  const b = new THREE.Vector3(pB.x, pB.y, pB.z)
  const mid = a.clone().add(b).multiplyScalar(0.5)
  const dist = a.distanceTo(b)
  mesh.position.copy(mid)
  mesh.scale.set(1, dist, 1)
  const dir = b.clone().sub(a).normalize()
  mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir)
}

function applyPose(mannequin, pose) {
  if (!pose) return
  for (const [name, mesh] of Object.entries(mannequin.joints)) {
    const p = pose[name]
    if (p) mesh.position.set(p.x, p.y, p.z)
  }
  for (const [key, mesh] of Object.entries(mannequin.limbs)) {
    const [pn, cn] = key.split("-")
    if (pose[pn] && pose[cn]) positionLimb(mesh, pose[pn], pose[cn])
  }
}

// ── Scene setup ──────────────────────────────────────────────────────

function createFloor() {
  const group = new THREE.Group()

  // Warm wooden floor — lighter, more visible
  const planeGeo = new THREE.PlaneGeometry(6, 6)
  const planeMat = new THREE.MeshStandardMaterial({
    color: 0x3d2e1e,
    roughness: 0.8,
    metalness: 0.0
  })
  const plane = new THREE.Mesh(planeGeo, planeMat)
  plane.rotation.x = -Math.PI / 2
  plane.receiveShadow = true
  group.add(plane)

  // Subtle grid
  const grid = new THREE.GridHelper(4, 16, 0x3d2e1e, 0x3d2e1e)
  grid.position.y = 0.001
  grid.material.opacity = 0.15
  grid.material.transparent = true
  group.add(grid)

  // Dance floor circle
  const ring = new THREE.Mesh(
    new THREE.RingGeometry(0.6, 0.62, 64),
    new THREE.MeshBasicMaterial({ color: 0xc0941a, transparent: true, opacity: 0.2, side: THREE.DoubleSide })
  )
  ring.rotation.x = -Math.PI / 2
  ring.position.y = 0.002
  group.add(ring)

  return group
}

// ── Neutral pose (face to face, dance hold) ──────────────────────────

function neutralLeader() {
  // Dance hold: right hand on follower's back, left hand low at side holding her right hand
  return {
    hip:        { x: 0, y: 0.92, z: 0 },
    torso:      { x: 0, y: 1.22, z: 0 },
    neck:       { x: 0, y: 1.42, z: 0 },
    head:       { x: 0, y: 1.55, z: 0 },
    shoulder_l: { x: -0.17, y: 1.32, z: 0 },    // lower, more natural
    shoulder_r: { x: 0.17, y: 1.32, z: 0 },
    // Left arm: at side, hand low holding follower's right hand
    elbow_l:    { x: -0.24, y: 1.10, z: 0.06 },
    hand_l:     { x: -0.22, y: 0.95, z: 0.14 },
    // Right arm: wraps around follower's back
    elbow_r:    { x: 0.14, y: 1.12, z: 0.16 },
    hand_r:     { x: 0.06, y: 1.08, z: 0.30 },
    // Legs slightly apart
    knee_l:     { x: -0.09, y: 0.48, z: 0.02 },
    knee_r:     { x: 0.09, y: 0.48, z: -0.02 },
    foot_l:     { x: -0.09, y: 0.03, z: 0.04 },
    foot_r:     { x: 0.09, y: 0.03, z: -0.04 }
  }
}

function neutralFollower() {
  // Faces leader at z=0.35. Left hand on leader's shoulder/upper back.
  // Right hand low, held by leader's left hand.
  const oz = 0.35
  return {
    hip:        { x: 0, y: 0.88, z: oz },
    torso:      { x: 0, y: 1.16, z: oz },
    neck:       { x: 0, y: 1.35, z: oz },
    head:       { x: 0, y: 1.47, z: oz },
    shoulder_l: { x: -0.16, y: 1.26, z: oz },    // lower, proportional
    shoulder_r: { x: 0.16, y: 1.26, z: oz },
    // Left arm: reaches to leader's shoulder/upper back
    elbow_l:    { x: -0.10, y: 1.12, z: oz - 0.10 },
    hand_l:     { x: -0.04, y: 1.22, z: oz - 0.22 },  // on leader's shoulder
    // Right arm: low, hand held by leader's left hand
    elbow_r:    { x: 0.20, y: 1.04, z: oz - 0.04 },
    hand_r:     { x: 0.22, y: 0.95, z: oz - 0.12 },   // meets leader's left hand
    // Legs
    knee_l:     { x: -0.08, y: 0.46, z: oz - 0.02 },
    knee_r:     { x: 0.08, y: 0.46, z: oz + 0.02 },
    foot_l:     { x: -0.08, y: 0.03, z: oz - 0.04 },
    foot_r:     { x: 0.08, y: 0.03, z: oz + 0.04 }
  }
}

// ── ThreeCanvas LiveView Hook ────────────────────────────────────────

const ThreeCanvas = {
  async mounted() {
    this._pendingAnimation = null

    this.handleEvent("load_animation", ({ steps }) => {
      if (this._scene) {
        this._loadAnimation(steps)
      } else {
        this._pendingAnimation = steps
      }
    })

    this.handleEvent("exit_3d_mode", () => {
      this._cleanup()
    })

    try {
      const threeModule = await import("three")
      THREE = threeModule
      const { OrbitControls: OC } = await import("three/examples/jsm/controls/OrbitControls.js")
      OrbitControls = OC
    } catch (err) {
      console.error("Failed to load Three.js:", err)
      return
    }

    this._initScene()

    if (this._pendingAnimation) {
      this._loadAnimation(this._pendingAnimation)
      this._pendingAnimation = null
    }
  },

  destroyed() {
    this._cleanup()
  },

  _initScene() {
    const container = this.el
    let width = container.clientWidth || window.innerWidth
    let height = container.clientHeight || (window.innerHeight - 86)

    // Renderer
    this._renderer = new THREE.WebGLRenderer({ antialias: true })
    this._renderer.setSize(width, height)
    this._renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    this._renderer.shadowMap.enabled = true
    this._renderer.shadowMap.type = THREE.PCFSoftShadowMap
    this._renderer.setClearColor(0x2c2218) // warm brown
    container.appendChild(this._renderer.domElement)

    // Scene
    this._scene = new THREE.Scene()
    this._scene.fog = new THREE.FogExp2(0x2c2218, 0.06)

    // Camera — slightly elevated, looking at the couple
    this._camera = new THREE.PerspectiveCamera(40, width / height, 0.1, 50)
    this._camera.position.set(1.2, 1.6, 2.2)

    // Controls
    this._controls = new OrbitControls(this._camera, this._renderer.domElement)
    this._controls.target.set(0, 1.0, 0.17)
    this._controls.enableDamping = true
    this._controls.dampingFactor = 0.08
    this._controls.minDistance = 1.0
    this._controls.maxDistance = 6
    this._controls.maxPolarAngle = Math.PI * 0.8
    this._controls.autoRotate = true
    this._controls.autoRotateSpeed = 0.8
    this._controls.update()

    // Lights — warm and inviting
    // Bright, warm lighting — like a dance floor spotlight
    this._scene.add(new THREE.AmbientLight(0xfff5e8, 0.9))

    const spot = new THREE.SpotLight(0xfff0d0, 2.2, 15, Math.PI / 3, 0.4, 0.6)
    spot.position.set(0.5, 5, 2)
    spot.castShadow = true
    spot.shadow.mapSize.set(1024, 1024)
    this._scene.add(spot)

    // Warm fill from left
    const fill = new THREE.PointLight(0xf0c080, 0.6, 10)
    fill.position.set(-2.5, 2, 0.5)
    this._scene.add(fill)

    // Cool rim from behind for depth
    const rim = new THREE.PointLight(0x8090b0, 0.3, 8)
    rim.position.set(0, 2.5, -3)
    this._scene.add(rim)

    // Low warm bounce from floor
    const bounce = new THREE.PointLight(0xd4a040, 0.2, 5)
    bounce.position.set(0, 0.1, 0.2)
    this._scene.add(bounce)

    // Floor
    this._scene.add(createFloor())

    // Mannequins — warm gold leader, warm coral follower
    this._leader = createMannequin(0xf0c850)    // vivid gold
    this._follower = createMannequin(0xe87060)  // vivid coral/rose
    this._scene.add(this._leader.group)
    this._scene.add(this._follower.group)

    // Apply neutral dance hold pose
    applyPose(this._leader, neutralLeader())
    applyPose(this._follower, neutralFollower())

    // Animation state
    this._steps = []
    this._currentStepIndex = 0
    this._stepStartTime = 0
    this._playing = false
    this._speed = 1.0
    this._loop = true

    // Resize
    this._onResize = () => {
      const w = container.clientWidth || window.innerWidth
      const h = container.clientHeight || (window.innerHeight - 86)
      this._camera.aspect = w / h
      this._camera.updateProjectionMatrix()
      this._renderer.setSize(w, h)
    }
    window.addEventListener("resize", this._onResize)

    // Playback controls from DOM buttons
    this.el.addEventListener("click", (e) => {
      const btn = e.target.closest("[data-3d-action]")
      if (!btn) return
      const action = btn.dataset["3dAction"]
      if (action === "play") { this._playing = true; this._stepStartTime = performance.now() }
      if (action === "pause") { this._playing = false }
      if (action === "toggle") {
        if (this._playing) { this._playing = false }
        else { this._playing = true; this._stepStartTime = performance.now() }
      }
      if (action === "next") this._advanceStep(1)
      if (action === "prev") this._advanceStep(-1)
      if (action === "speed") {
        this._speed = parseFloat(btn.dataset.speed) || 1.0
      }
    })

    this._animate()
  },

  _animate() {
    this._animFrame = requestAnimationFrame(() => this._animate())
    this._controls.update()

    if (this._playing && this._steps.length > 0) {
      const step = this._steps[this._currentStepIndex]
      if (!step) return

      const elapsed = (performance.now() - this._stepStartTime) * this._speed
      const dur = step.duration_ms || 2000
      let t = elapsed / dur

      if (t >= 1.0) {
        t = 1.0
        this._advanceStep(1)
      }

      const pose = interpolatePose(step.keyframes, t)
      if (pose) {
        applyPose(this._leader, pose.leader)
        applyPose(this._follower, pose.follower)
      }
    }

    this._renderer.render(this._scene, this._camera)
  },

  _advanceStep(dir) {
    const next = this._currentStepIndex + dir
    if (next >= 0 && next < this._steps.length) {
      this._currentStepIndex = next
    } else if (this._loop) {
      this._currentStepIndex = dir > 0 ? 0 : this._steps.length - 1
    } else {
      this._playing = false
      this.pushEvent("playback_ended", {})
      return
    }
    this._stepStartTime = performance.now()
    this.pushEvent("step_changed", { index: this._currentStepIndex })
  },

  _loadAnimation(steps) {
    this._steps = steps
    this._currentStepIndex = 0
    this._stepStartTime = performance.now()
    this._playing = true
  },

  _cleanup() {
    if (this._animFrame) cancelAnimationFrame(this._animFrame)
    if (this._onResize) window.removeEventListener("resize", this._onResize)
    if (this._renderer) {
      this._renderer.dispose()
      const dom = this._renderer.domElement
      if (dom && dom.parentNode) dom.parentNode.removeChild(dom)
    }
    if (this._controls) this._controls.dispose()
    this._scene = null
    this._camera = null
    this._renderer = null
  }
}

export default ThreeCanvas
