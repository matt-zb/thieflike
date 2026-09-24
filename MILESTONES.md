# MILESTONES.md — Vertical Slice Build Order

Each milestone ends with:
1. The `implementer` reporting done, with **all GUT tests passing** headless.
2. The `reviewer` passing the diff against ARCHITECTURE.md and DESIGN.md.
3. The developer playtesting the listed criteria (for anything marked
   "Play").

Gyms are small CSG test scenes under `levels/gym/`. CSG is allowed there for
greyboxing only.

---

## M0 — Project bootstrap

**Build**
- A Godot 4.7.2 project with Forward+, Jolt physics and a 60 Hz tick.
- The full Input Map (ARCHITECTURE §4.4) and the collision layer names (§14).
- GUT and func_godot installed, with their versions recorded in `addons/VERSIONS.md`.
- The folder layout (§2).
- Stub autoloads `GameState` and `TimelineManager` (empty API, compiles).
- `Main` scene with the World, Player and UI placeholders.
- A `.claude` SessionStart hook that installs the Godot 4.7.2 headless build
  in cloud sessions.
- A single smoke test.

**Acceptance**
- `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
  exits 0 with the smoke test passing.
- The project opens in the editor with no errors.

**Not in this milestone:** any gameplay.

---

## M1 — Player controller

**Build**
- PlayerController, the shared StateMachine, and the Grounded, Airborne,
  Mantling and Climbing states.
- MovementMath.
- The camera rig pivots and the RigAnimator with crouch, lean, bob and land.
- The viewmodel shader with placeholder hands.
- Invisible stair ramps.
- `gym_movement.tscn`, containing ledges from 0.4 to 2.0 m, a low ceiling, a
  ladder, a pipe, stairs, a doorframe to lean around, and a mix of floor
  materials.

**Acceptance**
- Tests: MovementMath curves, and the player state transitions with a
  stubbed body.
- Play: creep, walk and run feel weighted. Stops take a beat and there's no
  ice-skating.
- Play: crouch is blocked under the low ceiling.
- Play: lean never shows through a wall.
- Play: mantles succeed on 0.5–1.9 m ledges and are refused outside that
  range.
- Play: ladder and pipe climbing work, with an auto-mantle at the top.
- Play: bob foot-plants are visibly regular (footstep audio comes in M3).

**Not in this milestone:** noise, light, interaction, footstep audio.

---

## M2 — Light and power

**Build**
- LightSource, AmbientZone, LightSampler and LightMath/VisibilityMath.
- PowerGrid and the PoweredDevice component.
- Player visibility sampling at 10 Hz and the `visibility_changed` signal.
- The DebugOverlay's light panel and the viewport-probe calibration readout.
- The WorldEnvironment preset: SDFGI, fixed exposure, fog.
- `gym_light.tscn`: rooms with lamps on two circuits, a streetlight through a
  window, and a temporary debug breaker switch.

**Acceptance**
- Tests: attenuation matches Godot's formula, occlusion blocks light,
  switching a circuit changes `sample_point`, and the main breaker cascades
  to every circuit.
- Play: F3 shows the light level. Walking from a lamp pool into shadow drops
  it below the darkness threshold at the visible edge of the pool.
- Play: flipping the breaker darkens the gym and GI settles within about
  1 s. The streetlight still spills in.
- Play: the calibration probe and the analytic value agree within about 0.15
  after ambient zones are tuned.

**Not in this milestone:** NPCs, the breaker as an interactable (M4),
lighting polish.

---

## M3 — Sound

**Build**
- NoiseEvent, NoiseBus and NoiseMath.
- Footsteps driven from bob foot-plants, with surface detection.
- CreakZone and landing noise.
- The DebugOverlay's noise spheres.
- The `SurfaceTable` resource and placeholder footstep audio per surface.

**Acceptance**
- Tests: radius per surface and gait, story attenuation, and heard strength.
- Play: noise spheres grow with gait and surface. A creep over a creak zone
  is silent, while a walk over it produces a sphere.
- Play: landing from a height produces a larger sphere.

**Not in this milestone:** NPC hearing (M7), door and prop noise (M4).

---

## M4 — Interaction and inventory

**Build**
- Interactable and Interactor, with the rim highlight.
- Door (tap versus slow hold, locked, key), Window, LightSwitch,
  BreakerPanel, RouterDevice, WaterSupply, NetworkGrid, Manhole (needs the
  puller), Container, Pickup and Carriable (hold and throw with impact noise).
- Inventory with cycle, holster and viewmodel swap.
- Loot routing to GameState.
- `gym_interact.tscn`.

**Acceptance**
- Tests: Inventory operations, the key-on-lock rule, the manhole requiring
  the puller, the water and network signals, and loot excluded from the
  selectable list.
- Play: a slow door open makes a smaller noise sphere than a tap.
- Play: a thrown mug lands and makes an impact sphere.
- Play: taking the key from a drawer opens the locked door.
- Play: the breaker panel's per-circuit switches work.

**Not in this milestone:** the phone and watch (M5), NPC reactions.

---

## M5 — Timeline, watch and phone

**Build**
- The full TimelineManager and ClockTime.
- The MissionDefinition, TimelineEvent and PhoneMessage resources.
- The Watch viewmodel and WatchMath.
- The Phone item: thread, receive, vibrate noise, raised screen via
  SubViewport, and PhoneLight.
- A test mission resource that fires three texts.

**Acceptance**
- Tests: time parsing across midnight, the crossing-safe multi-event
  advance, the deadline firing exactly once, and WatchMath angles.
- Play: at 10:1, holding T shows the watch advancing 10 minutes per real
  minute. Texts arrive on schedule with a buzz.
- Play: raising the phone raises the player's light level (F3) in a dark
  room.

**Not in this milestone:** the fail screen (M9), NPC schedules.

---

## M6 — NPC foundation: schedules and navigation

**Build**
- The Npc scene with a placeholder capsule model.
- NpcProfile and ScheduleEntry.
- The Brain with the Idle and Schedule states only.
- ActivityRunner (sleep, sit, stand_use, lie_awake, laundry, away), device
  toggling, and door state.
- DoorHandler and key checks.
- NpcSpot and the navmesh bake workflow.
- `gym_schedule.tscn`: two rooms, a hall and a door. One NPC with a
  four-entry schedule.

**Acceptance**
- Tests: `Schedule.entry_at` boundaries. The Schedule state switches entries
  on `minute_ticked`.
- Play: the NPC walks to each spot on time, opens and closes the door,
  switches the lamp with its activity, and sleeps.
- Play: after being teleported away mid-entry (debug key), the NPC paths
  back to the *current* entry.

**Not in this milestone:** perception, search, errands.

---

## M7 — NPC perception and the state machine

**Build**
- Perception: sight cone and LOS, hearing, and environmental noticing.
- SuspicionMeter and PerceptionMath.
- The Suspicious, Searching (SearchPlanner) and Alert states (shout and
  flee; the police call is only a signal for now).
- Wake-up from sleep. Barks with placeholder audio. PhoneLight in darkness.
- Debug readouts for NPC state and suspicion.

**Acceptance**
- Tests: every transition in DESIGN §3.3, threshold and decay behaviour,
  the wariness floor rising after a search, SearchPlanner preferring dark
  points, and a sleeping light sleeper waking from a walk-step but not from
  a creep-step at 3 m.
- Play: standing in darkness 4 m in front of an awake NPC is safe. Stepping
  into lamp light gets noticed in about 1–2 s.
- Play: a thrown object sends the NPC to search the impact point.
- Play: being seen clearly leads to a shout, a flee and the police signal.
- Play: after an unsuccessful search, the NPC resumes the schedule entry for
  the current time.

**Not in this milestone:** disruptions, police timer and outcomes.

---

## M8 — Disruptions

**Build**
- DisruptionCoordinator, ResponderPicker and Errand.
- Wiring PowerGrid, WaterSupply and NetworkGrid to affected residents.
- The Errand state with fix-on-complete.
- The suspicion bump for non-responders.
- NPC phone flashlights during outages.

**Acceptance**
- Tests: exactly one responder per disruption, nearest by path, re-pick when
  interrupted, sleeping NPCs ignored, and water and network dependencies
  honoured.
- Play: in a gym with three NPCs, cutting their circuit sends one of them
  with a phone light to the breaker, and power is restored after about
  20 game-seconds.
- Play: unplugging the router sends the computer user to the router.

**Not in this milestone:** Mission 1 data.

---

## M9 — Mission flow and outcomes

**Build**
- MissionDirector (spawning, events, target, extraction, police timer,
  sirens, property bounds).
- The full GameState resolve and retry logic, and DifficultyTier
  application.
- The FailScreen (leak, arrest, retry and success message lists).
- Reloading the level on any key.

**Acceptance**
- Tests: GameState outcome rules (retry increments the tier and caps at 3;
  leak, arrest and success reset), police arrival while inside bounds
  resolves to ARRESTED, and tier application locks the listed targetnames.
- Play: letting the clock hit the deadline shows the leak message cascade,
  and any key restarts.
- Play: extracting without the target after an alert gives the "Tomorrow
  night" text, and the next attempt applies tier 1.
- Play: extracting with the target gives the success texts and the loot
  tally.

**Not in this milestone:** the Mission 1 map and schedules.

---

## M10 — TrenchBroom pipeline

**Build**
- The FGD and func_godot entity definitions for every classname in
  ARCHITECTURE §14, mapped to the existing scenes and scripts.
- Surface metadata, clip ramps, `nav_source` grouping and door exclusion
  from the navmesh.
- Target linking between switches and lights.
- `trenchbroom/README.md` for the developer: the TrenchBroom game config,
  texture-to-surface conventions, the wall-thickness rule and entity
  reference.
- A small test `.map` (two rooms, a door, a switched light, an NPC spot) that
  builds into a working level.

**Acceptance**
- Tests: an integration test builds the test `.map` headless and asserts
  that the expected nodes, metadata and groups exist.
- Play: the test map runs. The switch toggles the light, the NPC paths
  through the door, and footsteps change sound on `func_surface`.
- The developer can open the FGD in TrenchBroom and place every entity.

**Not in this milestone:** the Mission 1 layout.

---

## M11 — Greybox townhouse and Mission 1 data

**Build**
- `levels/greybox_townhouse/townhouse.map`: a generated, axis-aligned greybox
  following `docs/mission1_floorplan.png`. It has the basement, three
  identical floors, both stairs, the roof and hatch, the alley and gate, the
  rear lot and manhole, and the street and car. It's built through the M10
  pipeline, not CSG, which proves the developer's map will drop in.
- `data/missions/mission_01/`: all nine NpcProfiles, the schedules and world
  events from DESIGN §5.5, the entry-point lock states from §5.3, and the
  difficulty tiers from §6.4.

**Acceptance**
- Tests: mission data validation passes (all spots, devices and targetnames
  exist in the greybox).
- Tests: a headless "night simulation" runs the timeline from 23:00 to
  05:00 with no player and asserts every resident reaches each scheduled
  spot within a tolerance.
- Play: a complete run is possible through at least three distinct routes:
  1. Alley key from E's nightstand, then an alley window.
  2. Drainpipe to the roof, then the hatch or a rear window.
  3. Power cut, then a crossing while the responder is in the basement.
- Play: all four outcomes are reachable.

**Not in this milestone:** final art, the developer's real map, audio
polish.

---

## M12 — Slice lock: look, sound and performance

**Build**
- A lighting look pass: warm, harsh and coloured practicals, TV flicker,
  monitor glow, streetlight shafts.
- Placeholder-quality but tonally correct audio: ambience, record player,
  TV, washer, sirens, barks.
- The performance budget from ARCHITECTURE §17.
- A tuning pass on all exports.
- A bug sweep.

**Acceptance**
- Play: holds 60 fps at 1080p on the target hardware in the greybox with all
  residents active.
- Play: at night the building reads as beautiful darkness with pools of
  light (developer judgement). Cutting power visibly transforms the
  building.
- All tests pass. The reviewer finds no open violations.

**Not in this milestone:** anything in DESIGN §9.
