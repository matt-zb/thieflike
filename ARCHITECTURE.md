# ARCHITECTURE.md — Technical Architecture (Godot 4.7.2)

Status: v1, Session 1. Implements DESIGN.md. If code has to deviate from this
document, the implementer stops and reports the conflict. The architecture
changes first, then the code.

---

## 1. Engine and project configuration

| Setting | Value | Why |
|---|---|---|
| Godot | 4.7.2, pinned | Reproducible builds and tests. |
| Renderer | Forward+ | Required for SDFGI. |
| Physics | Jolt (set explicitly in Project Settings) | Stable CharacterBody3D and ShapeCast behaviour. |
| Physics tick | 60 Hz | Movement tuning assumes 60. |
| Global illumination | SDFGI on the WorldEnvironment, `use_occlusion = true` | Brief: everything real-time. |
| Tonemap | Filmic or AgX, **fixed exposure** (auto-exposure off, or clamped to a narrow range) | Auto-exposure would brighten darkness and defeat the stealth mechanic. |
| Lights | Every `Light3D` has `light_bake_mode = DYNAMIC` | So SDFGI updates when a light changes energy (power cuts). |
| Addons | GUT (tests) and func_godot (TrenchBroom import), each on the latest release that supports 4.7 | The only allowed addons. Versions are pinned in M0. |

**SDFGI rules for level authoring (for the developer's TrenchBroom work):**
- Interior walls and floors must be at least 0.25 m thick. SDFGI leaks light
  through thin geometry.
- Every emissive surface that should light the player (TV, monitor, phone)
  must be paired with a real `Light3D`. The light sensor (§5) reads real
  lights only.
- When power drops, SDFGI takes a few frames to converge. That's acceptable:
  a real power cut has a flicker and a beat of adjustment.

**Recommended additional addons:** none. Everything below is built in-house
on engine features.

---

## 2. Project layout

```
res://
├── addons/            gut/, func_godot/
├── autoload/          game_state.gd, timeline_manager.gd
├── main/              main.tscn, main.gd
├── player/            player.tscn, player_controller.gd, states/, rig/, inventory/
├── npc/               npc.tscn, npc.gd, perception/, states/, activities/
├── systems/           lighting/, noise/, power/, water/, network/, disruption/, mission/
├── interactables/     door, window, switch, pickup, carriable, container, device, breaker, manhole
├── ui/                watch/, phone/, fail_screen/, debug_overlay/
├── data/              resource classes (*.gd) and mission data (*.tres)
│   └── missions/mission_01/
├── levels/            gym/ (CSG test rooms), greybox_townhouse/ (.map), mission_01/ (developer's map)
├── trenchbroom/       FGD, func_godot game config, entity definition resources
└── tests/             unit/, integration/
```

One class per file, and the filename matches the class name in snake_case.

---

## 3. Scene hierarchy

```
Main (Node, main.gd)
├── World (Node3D, level.gd — class Level; the current level root, swapped on retry)
│   ├── Geometry            func_godot map output (or CSG in gyms); worldspawn, brush entities
│   ├── Lights              every sensed Light3D (+ LightSource child) and AmbientZones
│   ├── NPCs                Npc instances, spawned by MissionDirector from mission data
│   ├── Interactables       doors, windows, switches, pickups, devices, breaker, manhole
│   ├── NavigationRegion3D  navmesh (baked in-editor, runtime-bake fallback)
│   └── Systems (Node)
│       ├── LightSampler
│       ├── NoiseBus
│       ├── PowerGrid
│       ├── WaterSupply
│       ├── NetworkGrid
│       ├── DisruptionCoordinator
│       └── MissionDirector
├── Player (always present; Main moves it to the level's player start)
└── UI (CanvasLayer)
    ├── FailScreen          full-screen phone for leak / arrest / success / retry
    └── DebugOverlay        dev only (F3)
```

The watch and the phone **viewmodels** are children of the player's camera
rig, not of UI. They are 3D objects lit by the real scene (DESIGN §2.2).
The phone's screen is a `SubViewport` rendering a 2D `PhoneScreen` control.
The same `PhoneScreen` scene is reused full-screen by `FailScreen`.

### 3.1 How components reach systems

Autoloads are limited to `GameState` and `TimelineManager`. Level-scoped
systems live under `World/Systems`. The rule:

- **Queries and reports (component → system):** a component resolves the
  system once in `_ready()` with `Level.of(self).noise_bus` (or
  `.light_sampler`, `.power_grid`, and so on). `Level.of()` walks up to the
  nearest `Level` ancestor. No component uses `get_node("../../..")` paths.
- **Notifications (system → many):** always signals. `Level._ready()` wires
  level-wide connections. Components that are spawned later (thrown props,
  NPCs) connect in their own `_ready()` through `Level.of()`.
- **Tests** construct a bare `Level` with only the systems under test, or
  inject a stub system directly into the component's typed property.
  Every component exposes its system dependencies as typed vars (for example
  `var noise_bus: NoiseBus`) that `_ready()` fills only if they're still
  null.

---

## 4. Player controller

### 4.1 Nodes

```
Player (CharacterBody3D, player_controller.gd — class PlayerController)
├── Collider (CollisionShape3D, CapsuleShape3D; height animated by the rig)
├── StandCheck (ShapeCast3D, upward; blocks uncrouch)
├── MantleProbe (Node3D)
│   ├── WallCast (ShapeCast3D, forward at chest)
│   └── LedgeCast (ShapeCast3D, downward from above the ledge)
├── StateMachine (Node, state_machine.gd) — movement states
│   ├── Grounded, Airborne, Mantling, Climbing
├── Rig (Node3D)                         ← all camera motion is on these nodes
│   └── CrouchPivot (Node3D)             height: stand 1.65 → crouch 1.05
│       └── LeanPivot (Node3D)           at the hips; lean = rotation + offset
│           └── BobPivot (Node3D)        head bob and landing dip
│               └── Camera3D
│                   ├── LeanClearance (ShapeCast3D) keeps the lean out of walls
│                   ├── InteractRay (RayCast3D, 1.8 m)
│                   ├── HandRight (Node3D) selected item viewmodel, carried prop anchor
│                   └── HandLeft (Node3D)  watch
├── RigAnimator (AnimationTree + AnimationPlayer driving the pivots above)
├── BodySamplePoints (Node3D) → Feet, Chest, Head (Marker3D; Head follows LeanPivot)
├── Footsteps (Node, footstep_emitter.gd) + AudioStreamPlayer3D
├── Interactor (Node, interactor.gd)
├── Inventory (Node, inventory.gd)
└── PhoneLight (OmniLight3D, small, energy 0 until the phone is raised; has LightSource)
```

### 4.2 Movement state machine

A small generic `StateMachine` node (shared with the NPC brain) with child
`State` nodes. Each state implements `enter(msg: Dictionary)`, `exit()`,
`physics_update(delta: float)` and `handle_input(event)`, and requests
transitions through the `transition_requested(to: StringName, msg: Dictionary)`
signal.

| State | Responsibility | Exits |
|---|---|---|
| Grounded | Gait selection (creep, walk, run), crouch toggle, acceleration and deceleration toward the target velocity, jump. | Airborne (no floor or jump), Mantling (jump plus a valid ledge), Climbing (forward into a climbable) |
| Airborne | Gravity, 15% air control, landing noise and dip on floor contact. | Grounded, Mantling (ledge caught while rising or falling near an edge) |
| Mantling | Input locked. Moves the body along a 2-segment path (up, then forward) with a tween over 0.6–0.9 s, scaled by ledge height. | Grounded |
| Climbing | Vertical movement along the climbable axis. Auto-mantle at the top. Jump detaches. | Grounded, Airborne, Mantling |

Crouch is a **flag**, not a state. It's orthogonal to Grounded and Airborne
and affects speed, the capsule and the rig.

**Movement math** is a pure static helper, `MovementMath` (tested). It
computes the new horizontal velocity given current velocity, wish direction,
target speed, and accel/decel rates:
`v = v.move_toward(wish * target_speed, rate * delta)`, where `rate` is accel
when the wish aligns with the current velocity and decel otherwise (the
reversal skid in DESIGN §2.1). All rates are exports under
`@export_group("Movement")`.

**Stairs:** the player and NPCs walk on **invisible ramp colliders**
(func_godot clip brushes). The visual steps have no collision. That's more
robust than a step-up algorithm and matches Thief's feel.

### 4.3 Rig: crouch, lean, bob (node-driven, not code-driven transforms)

`RigAnimator` is an `AnimationTree` whose animations key the pivot transforms.
Code only sets blend parameters:

- `parameters/crouch/blend_amount` (0–1). Interpolated in code for smoothing,
  and it drives CrouchPivot height and the capsule height track.
- `parameters/lean/blend_position` (−1…1), BlendSpace1D left, centre, right on
  LeanPivot (rotation plus offset). Code clamps the target by the
  `LeanClearance` hit fraction before writing it.
- `parameters/bob/blend_position` (speed 0…run), BlendSpace1D of looping bob
  cycles, with `bob_timescale` matched to step cadence. **Bob animations
  carry method-call tracks at foot-plant frames** that call
  `Footsteps.plant()`, so sound and motion stay in sync (DESIGN §2.1).
- A `land` OneShot for the landing dip, with intensity from fall speed.

### 4.4 Input map

`move_forward/back/left/right`, `run`, `creep`, `crouch`, `lean_left`,
`lean_right`, `jump`, `interact`, `use_item`, `throw`, `item_next`,
`item_prev`, `holster`, `check_watch`, `debug_overlay`, `debug_restart`,
using the keyboard and mouse bindings in DESIGN §2.6. They're defined in
`project.godot`. Nothing reads raw keycodes.

### 4.5 Viewmodels

Hands, watch, phone and carried props use a shared **viewmodel shader** that
compresses depth so they always draw in front of world geometry without
clipping. They stay in the main viewport, so they are **lit by the real
scene lighting**, which is the diegetic visibility cue. Don't use a separate
SubViewport camera: it would lose the scene lighting.

---

## 5. Light-level sensor

### 5.1 Options considered

| Option | How | Pros | Cons |
|---|---|---|---|
| **A. Analytic light sampling** | Register every gameplay light. For each sample point, sum each light's attenuated contribution, occlusion-tested with raycasts, plus a zone ambient term. | Deterministic. Unit-testable math. Cheap at 10 Hz. Can query **any** point (NPC search picks dark corners). Power cuts are exact. | Ignores true GI bounce and emissive surfaces, which are approximated by ambient zones and paired lights. |
| B. Viewport readback | Render a small probe mesh at the player from 2–6 low-res cameras in a SubViewport. Read the pixels back and average the luminance. | "What you see is what counts": includes SDFGI, shadows and emissives. | GPU→CPU readback stall or 1–2 frame latency. Not unit-testable. Player-only (you can't cheaply probe arbitrary points). Results depend on the probe material and exposure. Fragile. |
| C. LightmapProbe query | Query baked light probes. | Cheap. | **Not applicable.** No baked lighting (brief). |

### 5.2 Decision: A (analytic), with B as a dev-only calibration tool

The mechanic has to be **predictable and consistent** more than it has to be
photometrically exact. If a player stands in a spot that looks dark, it must
reliably count as dark. Option A gives exact control. It also satisfies
CLAUDE.md's rule that light-sampling math is tested. A dev-only viewport
probe (in DebugOverlay) shows A's value next to a B reading so the developer
can tune ambient zones until they agree with what's on screen.

### 5.3 Design

- **`LightSource`** (Node, child of any OmniLight3D or SpotLight3D). It joins
  group `sensed_lights`, reads its parent's type, energy, colour, range,
  attenuation and spot angle, and exposes `is_on()` (which covers both power
  and the switch). Lights without a LightSource are purely cosmetic.
- **`AmbientZone`** (Area3D, from func_godot's `func_ambient`). Exports
  `base_level` (moon or streetlight spill, unpowered) and `powered_level`
  (bounce approximation added while its `circuit_id` is powered). The
  highest-priority zone containing the point wins.
- **`LightSampler`** (World/Systems):
  - `sample_point(p: Vector3) -> float`. Returns a 0–1 level.
  - `sample_body(points: Array[Vector3]) -> float`. The maximum over the
    points, because one lit limb is enough to see.
  - It caches the list of active lights and updates it on `LightSource.toggled`.
  - Per light: skip if distance > range. Then compute
    `contrib = energy * luminance(color) * omni_attenuation(d, range, attenuation)`,
    with `omni_attenuation` mirroring Godot's own formula:
    `(max(1 - (d/range)^4, 0))^2 * d^(-attenuation)`. Spots also get the cone
    falloff from `spot_angle` and `spot_angle_attenuation`. Then an occlusion
    raycast from the light to the point on the `LIGHT_OCCLUDER` collision mask.
  - Result: `level = 1 - exp(-exposure_k * (ambient + Σ contrib))`, with
    `exposure_k` exported. The curve compresses bright values so ten lamps
    aren't ten times as visible as one.
  - Math lives in a pure static class, `LightMath` (tested). Raycasting stays
    in LightSampler.
- **Player** samples at 10 Hz (exported), not every frame, and emits
  `visibility_changed(light_level: float, visibility: float)`. Visibility =
  level × stance × motion factors (DESIGN §2.2), computed by `VisibilityMath`
  (tested).
- **Budget:** at most about 12 lights in range of any point, and 3 sample
  points, gives about 36 raycasts per sample at 10 Hz. That's negligible.

---

## 6. Data formats (resources, not hardcoded)

All mission data is typed `Resource` subclasses saved as `.tres` and edited in
the inspector. Times are authored as `"HH:MM"` strings for readability and
parsed by `ClockTime` (tested) into **mission minutes** (float minutes since
mission start; handles crossing midnight).

### 6.1 `MissionDefinition` (`data/mission_definition.gd`)
```
level_scene: PackedScene
start_clock: String            # "23:00"
deadline_clock: String         # "05:00"
time_scale: float              # 10.0 game-sec per real-sec
story_base_heights: PackedFloat32Array   # Y of each story floor (basement first)
residents: Array[NpcProfile]
world_events: Array[TimelineEvent]
target_item: ItemDefinition
police_response_minutes: float # 12.0
difficulty_tiers: Array[DifficultyTier]
leak_messages: Array[PhoneMessage]
arrest_messages: Array[PhoneMessage]
retry_messages: Array[PhoneMessage]
success_messages: Array[PhoneMessage]
```

### 6.2 `NpcProfile`
```
npc_id: StringName             # "A".."I"
scene: PackedScene             # visual variant
home_room: StringName
sleeper: int (enum NONE, LIGHT, NORMAL)
sight_base: float, hearing_base: float
keys: Array[StringName]
power_circuit: StringName      # circuit their room/activities hang on
needs_network: StringName      # router id or &""
needs_water: bool
schedule: Array[ScheduleEntry]
```

### 6.3 `ScheduleEntry`
```
start: String                  # "01:00"; runs until the next entry's start
activity: int (enum SLEEP, SIT, STAND_USE, LIE_AWAKE, LAUNDRY, AWAY, IDLE_AT)
spot_id: StringName            # NpcSpot in the map
devices_on: Array[StringName]  # device ids switched on when the activity begins
devices_off: Array[StringName]
door_state: int (enum LEAVE, CLOSE, OPEN)   # what to do with the room door on arrival
sight_mult: float = 1.0        # activity modifiers (DESIGN §3.2)
hearing_mult: float = 1.0
fixed_gaze_spot: StringName    # e.g. C stares at the monitor; &"" for free look
```
`Schedule.entry_at(entries, mission_minute) -> int` is a pure static function
(tested). It returns the index of the entry covering that minute, or -1 for
before the first entry.

### 6.4 `TimelineEvent`
```
at: String
kind: int (enum TEXT, SPAWN_NPC, DESPAWN_NPC, SET_DEVICE, PLAY_SOUND, SIGNAL)
payload: Dictionary            # keys by kind, validated by a test over all mission data
```

### 6.5 `DifficultyTier`
```
sight_gain_mult: float
wariness_floor_start: float
deadline_override: String      # "" = no change
locked_overrides: Array[StringName]   # targetnames of doors/windows/hatches forced locked
unmantleable: Array[StringName]       # targetnames of mantle-blocker volumes enabled
```

### 6.6 Other resources
`ItemDefinition` (id, display name, viewmodel scene, value, is_target,
is_tool), `PhoneMessage` (sender, text, delay_s), and `SurfaceType`
constants (`carpet`, `wood`, `tile`, `concrete`, `gravel`, `metal`), with
multipliers in a `SurfaceTable` resource.

A **data validation test** loads every `.tres` under `data/missions/` and
checks:
- All times parse.
- Schedules are in order.
- Every `spot_id`, device id and targetname exists in the mission's level
  scene.
- Every event payload has the required keys.

---

## 7. Timeline system

**`TimelineManager` (autoload).**
- State: `mission_minute: float`, `time_scale: float`, `running: bool`, and a
  sorted event queue.
- `start(def: MissionDefinition)`, `stop()`,
  `advance(real_delta: float)` (called from `_process` and directly in
  tests), `clock_string() -> String`, `minutes_remaining() -> float`.
- On advance: add `real_delta * time_scale / 60` to the minute. Then pop and
  emit **every** event whose time ≤ the new minute, in order (crossing-safe,
  DESIGN §4). Emit `minute_ticked(whole_minute)` once per crossed whole
  minute, and `deadline_reached()` exactly once.
- It knows nothing about NPCs. Residents are driven by `minute_ticked`.

**`GameState` (autoload).** Survives level reloads.
- Fields: `attempt: int`, `difficulty_tier: int`, `loot_total: int`,
  `loot_items: Array[StringName]`, `outcome: int` (enum NONE, SUCCESS, LEAK,
  ARRESTED, ESCAPED_EMPTY).
- Functions: `begin_attempt()`, `record_loot(item)`, `resolve(outcome)`
  (which applies the retry and reset rules from DESIGN §6.4), and
  `reset_campaign()`.

---

## 8. Sound propagation

- **`NoiseEvent`** (RefCounted): `origin: Vector3`, `radius: float`,
  `kind: int` (FOOTSTEP, MECHANICAL, IMPACT, ALARMING, ELECTRONIC),
  `source: Node`.
- **`NoiseBus`** (World/Systems) has `report(event)`. It stamps the source
  story (from `story_base_heights`) and emits `noise_emitted(event)`.
- **`NoiseMath`** (static, tested):
  - `radius_for(base, surface_mult, gait_mult) -> float`
  - `effective_radius(event, listener_story, story_atten = 0.6)`
  - `heard_strength(distance, effective_radius, hearing_mult) -> float`
    (0 if outside the radius, otherwise `1 - d/(r*h)`)
- **Surfaces.** Footsteps raycast down and read the collider's
  `surface` metadata. func_godot `func_surface` brushes set it, and
  worldspawn's `surface` key sets the default. Missing metadata means `wood`.
- **`CreakZone`** (`trigger_creak`). Area3D. A walk or run foot-plant inside
  it adds a 9 m MECHANICAL event.
- **Emitters:** Footsteps (player and NPC), Door, Window, Carriable (on
  impact, from contact velocity and mass), Phone (vibrate), NPC shout
  (ALARMING).
- **Debug:** DebugOverlay draws a fading wire sphere per event.

There is no geometric occlusion in the vertical slice (brief).

---

## 9. Interaction and inventory

- **`Interactable`** is the base class for everything frobbable. It has
  `can_interact(actor) -> bool`, `interact(actor, hold: bool)`,
  `interact_hint() -> StringName` (used only by the rim-highlight shader
  switch), and the signal `interacted(actor)`.
- **Subclasses (one file each):** `Door`, `Window`, `LightSwitch`,
  `BreakerPanel`, `RouterDevice`, `Manhole`, `Container` (drawers, with
  contents as `Array[ItemDefinition]`), `Pickup`, `Carriable`. Brush
  entities (doors, windows) get their script through func_godot entity
  definitions.
- **Door:** an AnimatableBody3D rotating about its hinge.
  - Fields: `locked`, `key_id`, `creaky`, `open_speed_normal`,
    `open_speed_slow`.
  - Opening makes noise proportional to the speed used.
  - NPC access: `Door.request_open(by: Node)` checks the requester's keys.
  - Door collision is on the `INTERACTABLE` layer, **excluded from the navmesh
    bake**, and included in `LIGHT_OCCLUDER`.
- **`Interactor`** (player). Reads `InteractRay`, tracks the focused
  Interactable, routes `interact` (tap or hold) and `use_item` (the selected
  item applied to the focused object, for example a key on a door or the
  puller on the manhole).
- **`Inventory`** (player). An ordered `Array[ItemDefinition]` and a selected
  index.
  - `add`, `remove`, `has(id)`, `select_next/prev`, `holster`.
  - Signals: `item_added`, `item_removed`, `selection_changed(item)`.
  - Loot items go to `GameState.record_loot` and are **not** added to the
    selectable list.
  - Pure logic, fully unit-tested.
- **Carrying:** a Carriable is held at `HandRight` via a joint-free follow
  (it sets velocity toward the anchor). Throw applies an impulse. Its
  impact noise comes from the Carriable itself.

---

## 10. NPC architecture

### 10.1 Nodes
```
Npc (CharacterBody3D, npc.gd — class Npc)
├── Collider
├── Model (visual scene from NpcProfile) + AnimationTree
├── Head (Node3D, eye position; tracks gaze)
│   └── PhoneLight (SpotLight3D + LightSource; on while moving in darkness)
├── NavigationAgent3D
├── Perception (Node, npc_perception.gd)
├── Brain (StateMachine)
│   ├── Idle, Schedule, Suspicious, Searching, Alert, Errand
├── ActivityRunner (Node) plays the activity: animation, device toggles, door state, sleep flag
├── DoorHandler (Area3D ahead of the agent) opens and closes doors on the path
├── Footsteps (shared footstep_emitter.gd)
└── Voice (AudioStreamPlayer3D) for barks
```

### 10.2 Perception
- `Perception` holds a **`SuspicionMeter`** (RefCounted, tested):
  - `value`, `wariness_floor`
  - `add(amount)`, `decay(delta)`
  - Signals: `threshold_crossed(level)` where level is SUSPICIOUS (35),
    SEARCHING (70) or ALERT (100). Thresholds are exported.
- **Sight**, evaluated at 10 Hz. The player's visibility comes from the
  player's `visibility_changed` signal, cached. Then:
  1. Cone test (`PerceptionMath.in_cone`, tested).
  2. LOS raycasts to the player sample points.
  3. Gain = `PerceptionMath.sight_gain(visibility, distance, …)` (tested).
- **Hearing** subscribes to `NoiseBus.noise_emitted`, uses
  `NoiseMath.heard_strength`, and records the last stimulus position.
  An ALARMING kind jumps straight to the Searching threshold.
- **Modifiers** come from the current ScheduleEntry, the sleep flag, the
  NpcProfile base values and `GameState` difficulty. They're multiplied into
  one `PerceptionModifiers` value computed on activity change.
- **Environmental noticing.** Doors, windows and lights emit
  `state_changed(node, new_state)` via their group. Perception checks
  whether the NPC can see the object and compares it with the last state it
  saw (a small Dictionary).

### 10.3 Brain states
Transitions follow DESIGN §3.3 exactly.

- **Schedule.** Listens to `TimelineManager.minute_ticked` and calls
  `Schedule.entry_at(...)`. When the index changes, it paths to the entry's
  NpcSpot through the NavigationAgent3D, then hands the entry to
  ActivityRunner. `AWAY` hides and disables the NPC.
- **Suspicious.** Turns to the stimulus and barks. Subscribes to meter decay
  and threshold signals.
- **Searching.** Builds a search list with `SearchPlanner` (tested): the last
  known position plus N navmesh points within radius R, scored by darkness
  (`LightSampler.sample_point`) and distance. It visits each point, then
  times out, raises `wariness_floor` and returns to Schedule.
- **Alert.**
  - Emits an ALARMING shout noise and `alerted(npc_id, player_pos)`.
  - Paths away from the player to a safe spot (its home room).
  - After a call duration, emits `police_called(npc_id)`.
  - Never approaches the player.
- **Errand.** Receives an `Errand` (RefCounted: `spot_id`, `duration_min`,
  `on_complete: Callable`, such as `PowerGrid.set_circuit.bind(&"F2", true)`).
  Paths there, waits, completes, and returns to Schedule. Perception can
  interrupt it. An interrupted errand is abandoned, and the coordinator
  re-assigns it (§11).
- **Return to schedule.** Every entry into Schedule re-queries `entry_at(now)`.
  There is no stored "resume" state.

### 10.4 Navigation
- One `NavigationRegion3D` per level. Its source geometry comes from the
  `nav_source` group (func_godot world geometry and clip ramps). Doors and
  carriables are excluded.
- The navmesh is **baked in-editor** and saved as a resource. Runtime bake on
  load is a fallback for gyms.
- Agent settings: radius 0.3 m, height 1.8 m, max climb 0.35 m, max slope 40°.
- `NpcSpot` (Marker3D, from `info_npc_spot`) has a `spot_id` and a facing.
  `Level` keeps a `spot_id → NpcSpot` dictionary.

---

## 11. Infrastructure systems

- **`PowerGrid`.**
  - State: `circuits: Dictionary[StringName, bool]` (`main`, `F1`, `F2`, `F3`,
    `B`). A circuit is live if `main` and its own switch are on.
  - Functions: `set_circuit(id, on)`, `is_live(id)`.
  - Signal: `circuit_changed(id, live)` (emitted per affected circuit when
    `main` flips).
- **`PoweredDevice`** (Node component). Attaches to lights (via LightSource),
  the TV, monitor, record player, washer and routers. It has `circuit_id`,
  listens to `circuit_changed`, and combines power with the device's own
  on/off.
- **`WaterSupply`** has `set_on(bool)` and signal `water_changed(on)`.
  `Manhole` drives it.
- **`NetworkGrid`** tracks each router's plugged state and has signal
  `network_changed(router_id, up)`. `RouterDevice` drives it.
- **`DisruptionCoordinator`.**
  - Listens to the three signals above.
  - Finds the affected residents from their NpcProfile (`power_circuit`,
    `needs_network`, `needs_water`), keeping only those that are awake and
    present.
  - Picks **one responder** with `ResponderPicker` (tested): the nearest by
    navmesh path length, ties broken by npc_id.
  - Emits `errand_assigned(npc_id, errand)`. `Level` routes it to that NPC's
    Brain.
  - Gives the remaining affected residents a suspicion bump
    (DESIGN §5.4).
  - One active errand per disruption. If the responder is interrupted, it
    re-picks.

---

## 12. Mission flow

**`MissionDirector`** (World/Systems) owns one attempt:
1. Load the `MissionDefinition` and apply the `DifficultyTier` for
   `GameState.difficulty_tier` (locks, deadline, multipliers).
2. Spawn the residents at their schedule's current spot and start
   `TimelineManager`.
3. Handle timeline events. TEXT goes to `Phone.receive(message)`, and
   SPAWN/DESPAWN goes to NPCs.
4. Watch for the target pickup (`Inventory.item_added` with `is_target`) and
   the extraction zone (`ExtractionZone.player_entered`).
5. Police: on `police_called`, start the response timer in mission minutes.
   Trigger siren audio. On arrival, check `PropertyBounds` (an Area3D, from
   `trigger_property`) to decide the outcome.
6. Resolve the outcome with `GameState.resolve()`, emit
   `mission_ended(outcome)`, and stop the timeline.

`FailScreen` plays the right message list. On "any key", `Main` reloads
`World` from `level_scene` and repositions `Player`.

**Retry** (escaped empty-handed): `GameState` raises `difficulty_tier` and the
level reloads. **Leak, arrest or success:** `reset_campaign()`, then reload.

---

## 13. Diegetic UI

- **`Watch`** (viewmodel on HandLeft). Its hand angles are computed from
  `TimelineManager.mission_minute` by `WatchMath` (tested: the hour, minute
  and second hand angles). It raises while `check_watch` is held, animated
  on its own AnimationPlayer. The luminous hands use an emissive material
  that is **not** paired with a light, so they don't light the player.
- **`Phone`** (item, viewmodel on HandRight):
  - Holds the message thread (`Array[PhoneMessage]`).
  - `receive(msg)` adds the message, emits an ELECTRONIC noise event
    (vibrate) and a haptic-style buzz animation.
  - Raising the phone sets PhoneLight energy above 0, so the LightSampler
    sees the player light themselves.
  - The screen is a SubViewport with a `PhoneScreen` Control.
- **`FailScreen`** (UI). A full-screen `PhoneScreen` that plays a
  `PhoneMessage` list with its delays. It's the only non-3D UI, and it's
  still the in-fiction phone.
- **`DebugOverlay`** (UI, dev builds only, F3):
  - Light level and visibility numbers.
  - Viewport-probe calibration value.
  - The state and suspicion of every NPC.
  - The mission clock.
  - Noise spheres.

---

## 14. TrenchBroom / func_godot integration

Every gameplay object is a **standalone scene or script** that works both
hand-placed (gyms, tests) and spawned by func_godot from the developer's map.
The FGD lives in `trenchbroom/` and maps classnames to those scenes and
scripts.

| Classname | Type | Key properties | Becomes |
|---|---|---|---|
| `worldspawn` | brush | `surface` | Geometry, in `nav_source` and `LIGHT_OCCLUDER` |
| `func_detail` | brush | `surface` | Non-structural geometry |
| `func_surface` | brush | `surface` | Geometry with surface metadata |
| `func_clip` | brush | — | Invisible collision (stair ramps), in `nav_source` |
| `func_door` | brush | `targetname`, `key_id`, `locked`, `creaky`, `hinge_side` | Door |
| `func_window` | brush | `targetname`, `locked`, `slide_height` | Window |
| `func_climbable` | brush | `kind` (ladder, pipe) | Climbable volume |
| `func_ambient` | brush | `base_level`, `powered_level`, `circuit`, `priority` | AmbientZone |
| `func_mantle_block` | brush | `targetname` | A mantle blocker toggled by difficulty |
| `trigger_creak` | brush | — | CreakZone |
| `trigger_extraction` | brush | — | ExtractionZone |
| `trigger_property` | brush | — | PropertyBounds |
| `info_player_start` | point | angle | Player spawn |
| `info_npc_spot` | point | `spot_id`, angle | NpcSpot |
| `light_point` / `light_spot` | point | `targetname`, `circuit`, `color`, `energy`, `range`, `shadow`, `flicker`, spot angle | Light3D + LightSource + PoweredDevice |
| `prop_switch` | point | `target` (light targetname), `circuit` | LightSwitch |
| `prop_device` | point | `device_id`, `kind` (tv, monitor, record_player, washer, router), `circuit` | Device scene + PoweredDevice |
| `prop_breaker` | point | — | BreakerPanel |
| `prop_manhole` | point | — | Manhole |
| `prop_container` | point | `contents` (item ids, comma separated), `locked` | Container |
| `prop_pickup` | point | `item_id` | Pickup |
| `prop_carriable` | point | `model` | Carriable |

**Collision layers:**

| # | Name | Contents |
|---|---|---|
| 1 | WORLD | Static geometry |
| 2 | PLAYER | Player capsule |
| 3 | NPC | NPC capsules |
| 4 | INTERACTABLE | Doors, windows, containers |
| 5 | CARRIABLE | Physics props |
| 6 | LIGHT_OCCLUDER | Mask of WORLD plus doors; used by LightSampler and LOS |
| 7 | TRIGGER | Areas |
| 8 | NAV_EXCLUDE | Marker layer so bakes skip these |

---

## 15. Signal map

| Emitter | Signal (args) | Listeners |
|---|---|---|
| TimelineManager | `minute_ticked(minute: int)` | NPC Schedule state, Watch (coarse), MissionDirector |
| TimelineManager | `event_fired(event: TimelineEvent)` | MissionDirector |
| TimelineManager | `deadline_reached()` | MissionDirector |
| GameState | `outcome_resolved(outcome: int)` | Main (reload), FailScreen |
| GameState | `loot_changed(total: int)` | (end screen only) |
| PlayerController | `visibility_changed(light: float, visibility: float)` | NPC Perception (all), DebugOverlay |
| PlayerController | `gait_changed(gait: int)`, `crouch_changed(on: bool)` | Footsteps, RigAnimator driver |
| Footsteps | → `NoiseBus.report()` (call) | — |
| NoiseBus | `noise_emitted(event: NoiseEvent)` | NPC Perception (all), DebugOverlay |
| LightSource | `toggled(on: bool)` | LightSampler (cache) |
| Door / Window / LightSwitch | `state_changed(node: Node, state: int)` | NPC Perception (environmental noticing) |
| Interactor | `focus_changed(target: Interactable)` | Rim highlight |
| Inventory | `item_added(item)`, `item_removed(item)`, `selection_changed(item)` | Viewmodel switcher, MissionDirector (target) |
| Phone | `message_received(msg: PhoneMessage)` | Phone viewmodel (buzz), NoiseBus (via call) |
| PowerGrid | `circuit_changed(id: StringName, live: bool)` | PoweredDevice (all), DisruptionCoordinator, NPC PhoneLight logic |
| WaterSupply | `water_changed(on: bool)` | Water devices (washer, sink), DisruptionCoordinator |
| NetworkGrid | `network_changed(router_id: StringName, up: bool)` | Devices (TV, monitor), DisruptionCoordinator |
| DisruptionCoordinator | `errand_assigned(npc_id: StringName, errand: Errand)` | Level → Npc Brain |
| SuspicionMeter | `threshold_crossed(level: int)` | NPC Brain |
| Npc | `state_entered(npc_id, state: StringName)` | DebugOverlay |
| Npc | `alerted(npc_id, at: Vector3)` | MissionDirector, other NPCs via the shout noise |
| Npc | `police_called(npc_id)` | MissionDirector |
| ExtractionZone | `player_entered()` | MissionDirector |
| MissionDirector | `mission_ended(outcome: int)` | GameState (resolve), TimelineManager (stop) |
| StateMachine | `transition_requested(to, msg)` | its own StateMachine (internal) |

New signals must be added to this table in the same change that introduces
them.

---

## 16. Testing strategy (GUT)

Run with `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.

| Area | Test file | What |
|---|---|---|
| MovementMath | `test_movement_math.gd` | Accel/decel curves, reversal skid, air control cap |
| Player state machine | `test_player_states.gd` | Transitions with a stubbed body (floor lost → Airborne, ledge → Mantling, and so on) |
| LightMath / VisibilityMath | `test_light_math.gd` | Omni and spot attenuation match Godot's formula, exposure curve, stance and motion factors |
| LightSampler (integration) | `test_light_sampler.gd` | A small scene with occluding walls. Switching power changes the sample. |
| NoiseMath | `test_noise_math.gd` | Surface and gait radius, story attenuation, heard strength |
| ClockTime / TimelineManager | `test_timeline.gd` | Parsing, midnight crossing, crossing-safe multi-event advance, deadline fires once |
| Schedule | `test_schedule.gd` | `entry_at` boundaries, before first entry |
| SuspicionMeter / PerceptionMath | `test_perception.gd` | Thresholds, decay floor, cone test, sight gain |
| NPC brain | `test_npc_brain.gd` | Every DESIGN §3.3 transition, including return-to-schedule at a *different* entry |
| SearchPlanner / ResponderPicker | `test_search_responder.gd` | Darkness scoring, single responder, re-pick on interrupt |
| PowerGrid / WaterSupply / NetworkGrid | `test_infrastructure.gd` | Main-breaker cascade, signals |
| Inventory | `test_inventory.gd` | Add, remove, cycle, holster, loot routing |
| GameState | `test_game_state.gd` | Outcome → retry or reset rules, tier cap |
| WatchMath | `test_watch_math.gd` | Hand angles |
| Mission data | `test_mission_data.gd` | Validation from §6.6 |

Not tested: rendering, input feel, animation blending, SDFGI look.

**Cloud sessions:** the container has no Godot binary. M0 adds a
SessionStart hook that installs the pinned 4.7.2 headless build so the
implementer can run the tests.

---

## 17. Performance budget (target: GTX 1660 / RX 5600-class at 1080p60)

- At most 8 shadow-casting lights visible at once. Other lights don't cast
  shadows.
- Omni shadow atlas at 4096. Spot shadows at 2048.
- SDFGI: 4 cascades, min cell size tuned for interiors (start at 0.2 m).
- Volumetric fog is optional (lit shafts from the streetlight). It's the first
  thing to cut.
- Perception and light sampling run at 10 Hz. NPCs outside the player's
  story ±1 drop sight checks to 2 Hz.

---

## 18. Explicitly out of scope

- **Save system.** Not in the vertical slice. `GameState` is in-memory only.
  Nothing here should assume serialisation, but nothing prevents it later
  either (data is already in Resources).
- Main menu, settings and rebinding UI.
- Economy, shop and upgrades.
- Multiplayer.
- Sound occlusion.
- Gamepad.
