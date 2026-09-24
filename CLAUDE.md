# Project: Untitled Stealth Game (Vertical Slice)

## What this is

A first-person stealth game in the lineage of Thief: The Dark Project and Thief II.
Modern-day setting. The protagonist is blackmailed into committing burglaries
(premise drawn from Black Mirror's "Shut Up and Dance"). Missions are
time-limited; missing the deadline means the blackmail material drops.

Engine: Godot 4.7.2 (pinned). Language: GDScript exclusively.
Renderer: Forward+ with SDFGI for real-time global illumination.

## Your role (orchestrator)

You are the lead designer and architect. You make decisions, write specs, and
delegate implementation. You do NOT write GDScript yourself except for
small pseudocode snippets inside spec documents. All code is written by the
`implementer` subagent and reviewed by the `reviewer` subagent.

Keep your own context lean. Summarize, don't paste. When you need to understand
the current state of a file, ask `scout` to read it and report back.

## Subagents

| Name           | Model  | Role                                                        |
|----------------|--------|-------------------------------------------------------------|
| `implementer`  | sonnet | Writes and edits GDScript, scenes, resources, and tests.    |
| `scout`        | sonnet | Read-only. Summarizes files, finds nodes, reports structure. |
| `reviewer`     | sonnet | Read-only. Reviews diffs against ARCHITECTURE.md and DESIGN.md. Reports violations only. |

## Delegation rules

- **Planning, architecture, system design, hard trade-offs** → you (Opus 5.5).
- **Writing or editing .gd, .tscn, .tres, .cfg files** → `implementer`.
- **Reading project files to answer a question about current state** → `scout`.
- **Checking whether new code matches the spec** → `reviewer`.
- Never have `implementer` and `reviewer` be the same invocation.
- After `implementer` finishes a milestone, always run `reviewer` before
  reporting completion.

## Coding conventions

- GDScript, static typing everywhere: `var speed: float = 5.0`, not `var speed = 5.0`.
- Prefer signals over direct node references. Use autoloads sparingly:
  only for truly global systems (TimelineManager, GameState).
- Scene tree organization:
  ```
  Main
  ├── World (current level root)
  │   ├── Geometry
  │   ├── Lights
  │   ├── NPCs
  │   ├── Interactables
  │   └── NavigationRegion3D
  ├── Player (always present)
  └── UI (diegetic HUD elements)
  ```
- Node names: PascalCase. Variables/functions: snake_case. Constants: UPPER_SNAKE.
- One class per file. Filename matches the class: `player_controller.gd` for
  the node named `PlayerController`.
- Export variables for anything that should be tunable in the inspector:
  movement speeds, bob amplitudes, detection thresholds, timings. Use
  `@export_group` to organize them.
- Comments explain *why*, not *what*.

## Testing

- Use GUT (Godot Unit Testing framework, installed as addon).
- Every non-visual system must have a test script under `res://tests/`.
- Tests must pass via `godot --headless -s addons/gut/gut_cmdln.gd` before
  reporting a milestone complete.
- What to test: state machine transitions, schedule/timeline tick logic,
  light-level sampling math, detection calculations, inventory operations.
- What NOT to test: rendering, input feel, animation blending. Those are
  playtested by the developer.

## File outputs (Session 1)

This first session produces documents, not a playable build. Deliver these files
into the project root:

1. **DESIGN.md** — Complete game design document for the vertical slice.
   Must cover:
   - Premise and tone (one paragraph).
   - Player mechanics: movement model (acceleration, deceleration, crouch,
     lean, mantle), light/shadow visibility, sound propagation, interaction.
   - NPC mechanics: schedule-driven behavior, perception (sight cone, sound
     radius, light-level threshold), state machine
     (idle → schedule → suspicious → searching → alert), search behavior,
     return-to-schedule behavior.
   - Timeline/schedule system: how missions define NPC schedules and
     environmental changes as a time-indexed table.
   - Diegetic UI: the watch (timer), fail screen (text messages from
     contacts reacting to the leak), inventory (backpack/pockets,
     one selected item, Thief-style).
   - Mission 1 spec: three-story townhouse + basement, target on third
     floor, alleyway on one side, identical floor layouts with different
     inhabitants and furniture. Entry points. Power and water shutoff
     mechanics. The timeline (who is where, when, and what changes).
   - Explicit scope exclusions for the vertical slice.

2. **ARCHITECTURE.md** — Technical architecture keyed to Godot 4.
   Must cover:
   - Node/scene hierarchy (use the tree above as the starting point).
   - Player controller design: CharacterBody3D, input mapping, state
     machine for movement modes, how head bob / lean / crouch are
     implemented (camera rig nodes, not code-driven transforms).
   - Light-level sensor: how it works (options: OmniLight3D probe
     sampling, viewport readback, LightmapProbeData query), which
     approach to use and why.
   - Sound propagation model (simple: distance + surface type + speed →
     noise radius; no need for ray-based occlusion in the vertical slice).
   - NPC architecture: the state machine, how schedules are stored and
     consumed, navigation via NavigationAgent3D.
   - Timeline/schedule data format (resource files or JSON, not hardcoded).
   - Signal map: which nodes emit what, who listens.
   - Save system: explicitly out of scope for vertical slice (note it).

3. **MILESTONES.md** — Ordered milestone list with acceptance criteria.
   Each milestone must have:
   - A name.
   - What to build.
   - Acceptance criteria that can be verified by playing or by running tests.
   - What is explicitly NOT in this milestone.

4. **.claude/agents/implementer.md** — Subagent definition (already drafted below;
   adjust if the architecture demands it).

5. **.claude/agents/scout.md** — Subagent definition.

6. **.claude/agents/reviewer.md** — Subagent definition.

## What NOT to do

- Do not generate GDScript files in this session. Documents only.
- Do not design systems you won't need for the vertical slice
  (save system, main menu, multiple missions, upgrade trees).
- Do not plan for multiplayer.
- Do not recommend switching engines.
- Do not use Godot's CSG nodes for level geometry in the final product
  (they are acceptable for temp greyboxing only).
- Do not assume any third-party Godot addons are available except GUT
  and func_godot (for TrenchBroom .map import). If you want to recommend
  one, note it in ARCHITECTURE.md with justification; the developer
  will decide.
