# DESIGN.md — Vertical Slice Design Document

Status: v1, Session 1. Source of truth for *what* the game does.
ARCHITECTURE.md is the source of truth for *how*.
Inputs: `BRIEF.md`, `CLAUDE.md`, `docs/mission1_floorplan.png`, developer Q&A (Session 1).

---

## 1. Premise and tone

An ordinary person is blackmailed by an anonymous texter who holds something
that would ruin them. The instructions come by text: break into this building,
take this thing, deliver it before the deadline. Nobody the player robs is a
villain. They are neighbours: a nurse cooking before a night shift, a student
gaming with headphones on, someone listening to records at 1 AM. The game is
tense and grounded, never campy. Every system should make the player feel like
an intruder in someone's home: they hear snoring through a door, eat-in
dinners go cold, and it's the player's footsteps that wake someone up. Guilt
comes from how intimate the spaces are, not from cutscenes. Reference points:
*Thief: The Dark Project / Thief II* for mechanics and *Black Mirror, "Shut Up
and Dance"* for tone.

---

## 2. Player mechanics

### 2.1 Movement model — "heavy without being cumbersome"

The player is a person with mass. Velocity changes through acceleration, not
instantly. Mouse look is never smoothed or lagged, because the camera belongs
to the player's head. The *body* carries the weight.

| Gait    | Input            | Target speed (m/s) | Accel time to full | Decel time to stop | Noise |
|---------|------------------|--------------------|--------------------|--------------------|-------|
| Creep   | hold Alt         | 1.0                | 0.20 s             | 0.12 s             | minimal |
| Walk    | default          | 2.2                | 0.30 s             | 0.20 s             | low   |
| Run     | hold Shift       | 4.8                | 0.55 s             | 0.40 s             | high  |
| Crouch  | C (toggle)       | ×0.55 of gait      | same               | same               | ×0.5  |

All values are starting points and live in exported variables.

- **Momentum.** Deceleration is shorter than acceleration, so stopping feels
  deliberate but not slippery. Hard direction reversals at run speed carry
  about 0.3 s of skid. There is no air control beyond 15% of ground
  acceleration.
- **Jump.** Low and heavy (about 0.45 m apex). Used mainly to trigger mantles.
  Landing produces a noise event scaled by fall speed and a camera dip.
- **Crouch.** Toggle. Lowers the eye from 1.65 m to 1.05 m and the capsule
  from 1.8 m to 1.1 m. You can't stand up under a low ceiling (shape-cast
  check). Crouching lowers visibility (§2.2) and noise.
- **Lean.** Hold Q or E. The head rotates and translates around a hip pivot
  up to 0.45 m sideways and 12° of roll. Lean stops at walls so the camera
  never clips. The body does not move, so leaning around a doorframe exposes
  the head only (visibility is sampled at the head while leaning, §2.2).
- **Mantle.** Press jump facing a ledge between 0.5 m and 1.9 m above your
  feet with enough clearance on top. The player climbs over the ledge in about
  0.6–0.9 s, taking longer for higher ledges. Input is locked during the
  mantle and the climb makes a soft noise. Used for window sills, fences, the
  alley wall and furniture.
- **Climb.** Ladders (the roof hatch) and climbable pipes (a drainpipe robust
  enough to reach the roof). Enter by walking into the climbable and pressing
  forward. W/S moves up and down, jump pushes you off, and you mantle
  automatically at the top. Pipes climb slower and louder than ladders.
- **Head bob and footfalls.** Subtle, and tied to the gait's step cadence.
  Footstep sounds fire on the bob cycle's foot-plant, so what you see matches
  what you hear. There is no bob while creeping, beyond a tiny sway.

### 2.2 Light and shadow visibility

Light is the core mechanic. The world has no baked lighting: every light is
real-time and can be switched, powered or moved.

- **Light level.** A scalar from 0 to 1 sampled at the player's body points
  (feet, chest, head; the head only while leaning). It sums every relevant
  light's contribution with occlusion, plus the local ambient term (moonlight
  and streetlight spill, bounce approximation).
- **Visibility** = light level × stance factor (standing 1.0, crouched 0.65)
  × motion factor (still 0.6, creep 0.8, walk 1.0, run 1.3). NPC perception
  (§3.2) uses this value, not the raw light level.
- **Darkness threshold.** Below a tunable threshold (about 0.12) the player
  can't be seen at all beyond "bump range" (about 1.2 m). Pools of light are
  what's dangerous. Hallways at night are meant to be crossed, not lived in.
- **Self-illumination.** The phone screen (§2.5) is a light source attached to
  the player. Raising it to read texts makes you visible and lights your face.
- **Player feedback: no HUD light gem.** Feedback is diegetic. The first-person
  hands and sleeves are lit or unlit by the real lighting, and the watch hands
  are luminous and read clearly only in darkness. A **developer-only** debug
  overlay (toggle F3) shows the numeric light level and visibility for tuning.
  This is the biggest playtest risk. See §8 open decisions.

### 2.3 Sound propagation

Every audible action emits a **noise event**: an origin, a loudness radius (in
metres) and a kind. Radius = base for the action × surface multiplier × gait
multiplier.

| Surface  | Mult. | Where                                   |
|----------|-------|-----------------------------------------|
| Carpet   | 0.4   | bedrooms, living room                   |
| Wood     | 1.0   | hallways, stairs (default interior)     |
| Tile     | 1.2   | kitchen, bathroom                       |
| Concrete | 0.8   | basement, rear lot                      |
| Gravel   | 1.5   | alley, rear lot edges                   |
| Metal    | 1.6   | roof hatch, ladder, drainpipe           |

Starting base radii: creep step 1.5 m, walk step 5 m, run step 12 m, landing
4–14 m (scales with fall speed), door open 4 m (creaky doors 9 m), slammed or
dropped object 10 m, thrown object impact 6–15 m (scales with mass and speed),
glass break 20 m, phone vibrate 2 m.

- **Creaky floorboards** are placed by hand in the map. Stepping on one at
  walk or run adds a creak event with a 9 m radius. Creeping over one is silent.
- **Between floors.** Sound travels through floors. When the listener is on a
  different story from the source, the effective radius is multiplied by 0.6
  per story (the building has thin floors). There is no other occlusion in the
  vertical slice.
- **Noise kinds.** `footstep`, `mechanical` (doors, drawers, switches),
  `impact`, `alarming` (glass, loud crashes), `electronic` (phone). Alarming
  noises skip Suspicious and put the NPC straight into Searching.

### 2.4 Interaction ("frob")

**F** interacts with whatever is under the crosshair within 1.8 m. There is no
crosshair graphic. Instead, an interactable is highlighted with a faint rim
light on the object itself, visible only when you're close. What F does
depends on the object:

- **Doors.** Open or close. Tap F to swing normally (normal noise). Hold F to
  ease the door open slowly (quiet, about 2 s). Locked doors rattle (a small
  noise) and need the matching key selected.
- **Windows.** Open or close the sash. Locked windows don't move. An open
  window you can mantle through is an entry point.
- **Light switches and lamps.** Toggle. An NPC who notices a light changed
  state (§3.2) becomes Suspicious.
- **Breaker panel.** Toggle individual circuits (§5.4).
- **Routers.** Unplug or replug.
- **Manhole cover.** Needs the manhole puller selected. Opening it gives
  access to the water shutoff valve.
- **Drawers and containers.** Open to see what's inside. Picking up the
  contents moves them to your pockets.
- **Pickups.** Keys, loot, the target, tools: frob to pocket.
- **Carriables.** Small physics props (bottle, mug, shoe). Frob to hold one in
  front of you. Right mouse throws it with force based on how long you hold
  it, and it makes an impact noise where it lands. This is the player's
  distraction tool, and it's free.

### 2.5 Inventory, watch and phone

- **Pockets and backpack.** A small ordered list of items. Mouse wheel cycles
  the selected item and Tab holsters (empty hands). The selected item is
  visible in the right hand as a viewmodel. The item name appears briefly as
  a diegetic "look at" beat (the hand lifts the item into view for about
  0.5 s). There is no text overlay and no inventory screen.
- **Left mouse** uses the selected item: key on a lock, puller on a manhole,
  phone raised to read.
- **Starting inventory:** the phone only. No lockpicks or flashlight in
  Mission 1; those are future purchasable tools. Everything else is found in
  the level: E's alley key, the manhole puller (basement) and the target.
- **The phone** is the player's only phone. It gets anonymous texts from the
  blackmailer. When one arrives the phone vibrates, which is a quiet noise
  event (§2.3). Raising the phone (left mouse with the phone selected) shows
  the message thread on its screen, and the screen emits light (§2.2).
- **The watch** is on the left wrist. Hold T to raise it. It's an analog face
  with luminous hands, showing the mission clock (§4). Raising it is instant
  and silent. It gives no light.
- **Loot** (optional valuables) goes in the backpack. It is tallied but not
  selectable, since it only counts at mission end (§6.3).

### 2.6 Controls (keyboard and mouse only)

| Action               | Key          |
|----------------------|--------------|
| Move                 | WASD         |
| Look                 | Mouse        |
| Run (hold)           | Shift        |
| Creep (hold)         | Alt          |
| Crouch (toggle)      | C            |
| Lean left / right    | Q / E        |
| Jump / mantle        | Space        |
| Interact (frob)      | F            |
| Use selected item    | Left mouse   |
| Throw carried prop   | Right mouse  |
| Cycle item           | Mouse wheel  |
| Holster              | Tab          |
| Check watch (hold)   | T            |
| Debug overlay (dev)  | F3           |
| Restart mission (dev)| F9           |

There is no rebinding UI (no settings screen). Bindings are defined in the
Input Map.

---

## 3. NPC mechanics

### 3.1 Schedule-driven behaviour

Every resident has a **schedule**: a time-indexed list of activities, each
with a location (a named spot in the map), an activity type and perception
modifiers. At any mission time exactly one schedule entry is "current". A
resident's default job is to be where the schedule says, doing what it says.

Activity types for the vertical slice: `sleep`, `sit` (computer, TV, reading),
`stand_use` (cook, wash, bathroom sink), `lie_awake`, `walk_to`, `away`
(offstage: the NPC is not in the world), `laundry` (uses the washer).

An activity can also set the resident's **devices**. G turns the record player
on, F turns the TV on, and room lamps go on and off with the activity. This is
how schedules change the building's lighting over the night.

### 3.2 Perception

Each resident perceives through two channels that feed one **suspicion value**
(0–100).

**Sight.**
- A view cone of 110° horizontal and 70° vertical out to 18 m, plus a
  peripheral band to 150° that counts at 30% effectiveness.
- The NPC needs line of sight to at least one of the player's sample points.
- Gain per second = visibility (§2.2) × distance falloff (1 at ≤ 3 m, down to
  0 at max range) × activity modifier × difficulty modifier × a base rate.
- Below the darkness threshold, sight gives nothing unless the player is
  within bump range.

**Hearing.** An NPC hears a noise event if distance ≤ radius × the NPC's
hearing multiplier. The gain scales with how deep inside the radius the NPC
is.

**Activity and trait modifiers:**

| Condition                       | Sight | Hearing |
|---------------------------------|-------|---------|
| Asleep, light sleeper (A, I)    | 0     | 0.8     |
| Asleep, normal sleeper          | 0     | 0.35    |
| Headphones (C at computer)      | 1.0 (cone fixed on the monitor) | 0.15 |
| Watching TV (F)                 | 0.6   | 0.5     |
| Record player on (G, H nearby)  | 1.0   | 0.6     |
| Cooking (E)                     | 0.8   | 0.7     |
| Drunk, returning (B)            | 0.5   | 0.6     |
| Awake and idle                  | 1.0   | 1.0     |

**Environmental noticing.** An awake NPC who sees a light, door or window in a
different state from the one they expect (door open that they closed, lamp
off) gets a one-off suspicion bump. There is no per-object memory beyond
"the last state I saw."

Suspicion decays slowly while there's no stimulus (about 5 per second, and
never below the NPC's **wariness floor**; see Searching).

### 3.3 State machine

```
            ┌──────────── timeout / nothing found ─────────────┐
            ▼                                                  │
 IDLE ──► SCHEDULE ──(suspicion ≥ 35)──► SUSPICIOUS ──(≥ 70 or alarming)──► SEARCHING ──(clear sight of player)──► ALERT
  ▲         │  ▲                             │                                  │
  │         │  └─────(decays < 20)───────────┘                                  │
  │         ├──(disruption assigned)──► ERRAND ──(done)──► SCHEDULE              │
  └─(no current entry)                                                           │
                                      (clear sight of player at any state) ──────┘
```

- **Idle.** No schedule entry applies, or the NPC is waiting on a blocked
  path. The NPC stands in place and looks around. It's rarely seen and mostly
  a fallback.
- **Schedule.** The NPC is executing the current entry: pathing to its spot,
  then performing the activity. `sleep` is a Schedule activity, not a state.
  A sleeping NPC reaching the Suspicious threshold first **wakes up** (about
  2 s: sit up, lamp on).
- **Suspicious** (suspicion ≥ 35). The NPC stops, turns toward the stimulus
  and plays a short vocal bark ("…hello?"; audio only, no dialogue system).
  It may take a few steps toward the stimulus. If suspicion decays below 20,
  it returns to Schedule. If it reaches 70, it moves to Searching.
- **Searching** (suspicion ≥ 70, or an alarming noise). The NPC goes to the
  last known stimulus position, then checks 3–5 nearby reachable points,
  preferring dark corners and doorways, for 45–90 real seconds. If it's
  awake and the power is out, it uses its phone flashlight. At the end it
  raises its **wariness floor** by 15 for the rest of the mission (it stays
  jumpy) and returns to its schedule.
- **Alert.** A clear sighting: suspicion reaches 100 from sight, or the
  player is within bump range and visible. The NPC shouts, which is an
  alarming noise event that wakes and alarms nearby residents. It retreats to
  its own room or the nearest lit room and **calls the police** (§6.2).
  Alerted NPCs never approach the player. The game is non-violent and
  residents are afraid, not heroic. Other residents who hear the shout go to
  Searching.
- **Errand.** An NPC chosen to respond to an infrastructure disruption (§5.4)
  walks to the relevant spot (breaker, dining-room router, basement or kitchen
  sink), spends a set time there, may fix it, and returns. Errands can be
  interrupted by perception exactly like Schedule.
- **Return to schedule.** Schedules are indexed by time, so resuming never
  means "continue where I was". The NPC looks up the entry for *now* and
  paths to it. If G was pulled away at 01:50 and gets back at 02:10, G goes
  to bed, not back to the record player.

### 3.4 Doors and navigation

Residents path on a navigation mesh. They open doors in their way, which makes
normal door noise and **leaves them in the state the schedule dictates**
(bedroom doors closed by default; C's door open). Residents carry the keys
they logically own: front door, their own room, the back door. They never use
the alley gate, except E, whose key is in their nightstand drawer. No
resident goes onto the roof.

---

## 4. Timeline and schedule system

A mission is defined by a **timeline**: a table indexed by mission time.

- **Clock.** At the default time scale, 10 game minutes = 1 real minute. The
  6-hour window (23:00 → 05:00) plays out in 36 real minutes. The scale is a
  single tunable, and the documented fallback is 5:1 (72 real minutes).
- **Resident schedules.** One table per resident, as in §3.1.
- **World events.** One-off timed changes that aren't owned by a resident:
  a blackmailer text arriving, a resident spawning (B arriving home) or
  despawning (E leaving), a car's headlights sweeping the living room,
  streetlights, the deadline.
- **Crossing-safe.** If a frame spans several event times (for example after
  a hitch), every event crossed fires, in time order. Nothing is skipped.
- **Data, not code.** Timelines and schedules are resource files authored
  in the Godot inspector (ARCHITECTURE.md §6). The developer can retune the
  night without touching scripts.

---

## 5. Mission 1 — "The Townhouse"

### 5.1 Site

The site is a three-storey building with a basement. **All three floors share
the layout in `docs/mission1_floorplan.png`.** The street is at the front and
the parking area is at the rear. The layout below is a description for
design; the developer's TrenchBroom map is authoritative.

- **Left (alley side), front to back:** the living room (bay window to the
  street), then Rooms A, B and C (windows onto the alley, doors onto the
  central hall), then the rear stair.
- **Right side, front to back:** the shared entry and the front stairs up
  (street door at the front), then the dining room, bathroom and kitchen.
- **Central hall:** runs from the dining room to the kitchen, past the
  bedroom doors and the bathroom.
- **Rear stair:** a separate stairwell. Its door opens from the kitchen,
  and it has an exterior door to the parking area at ground level. It is
  the **only** way to the basement (at the bottom) and the roof (a ladder and
  hatch at the top).
- **Front stairs:** connect floors 1–3 via the shared entry area. They don't
  go to the basement or the roof.
- **Basement:** laundry (washers), breaker panel, and the manhole puller
  (a tool hung on a hook).
- **Exterior:**
  - The street frontage (mission start and extraction point: the player's
    car).
  - The alleyway along the left, with a locked gate at the street end.
  - The rear parking lot, with the water-shutoff manhole.
  - The roof, which you can walk on. One drainpipe (alley side) can be
    climbed to it.
- **No fire escape.**

### 5.2 Residents

"Room A/B/C" means front, middle and rear bedroom on that floor. Residents
have no fixed gender.

| ID | Floor | Room | Profile | Sleeper | Notes |
|----|-------|------|---------|---------|-------|
| A  | 1 | A | Early bird. In bed early. | Light | Wakes 04:30. |
| B  | 1 | B | Party-goer, never home. | Normal (drunk) | `away` until 04:00. Comes in through the front door, loud, lights on, kitchen, bed by 04:30. |
| C  | 1 | C | Up all night at the computer, door open, headphones on. | — | Monitor glow spills into the hall. Kitchen/bathroom trips. Needs the router. |
| D  | 2 | A | Night owl, reclusive. | — | Awake in their room, lamp on, door shut. Bathroom trips. Sharpest perception in the building. |
| E  | 2 | B | Cooks, then leaves for a night shift. | — | Kitchen 23:00–23:50, leaves 00:15 via the front door. Alley key in their nightstand. The only resident who leaves. |
| F  | 2 | C | Watches TV in the living room. | Normal | TV (a flickering coloured light) until 02:30, then bed. Needs the router. |
| G  | 3 | A | Record player in the living room. | Normal | Music (a noise mask) until 02:00, then bed. |
| H  | 3 | B | Hangs out with G, then does laundry. | Normal | With G until 01:00, then basement laundry via the rear stair. Needs water. |
| I  | 3 | C | Like A. **Target room.** | Light | Asleep all night, wakes 04:30. |

### 5.3 Entry points

| Entry | State | Notes |
|-------|-------|-------|
| Front street door | Locked | No key available in Mission 1. Opens when B arrives home (04:00) or E leaves (00:15), which gives a timing window. |
| Rear exterior door (rear stair) | Locked | Can be unlocked from inside. |
| Ground-floor alley windows (Rooms A, B, C) | A: locked. B: **unlocked** (B is out). C: locked. | Reached from the alley, so they need the alley key or a mantle over the gate (difficulty-dependent, §6.4). |
| Ground-floor living room bay (street) | One sash unlocked | Visible from the street and lit by the streetlight. |
| Rear kitchen windows (all floors) | Floor 1 unlocked. Floors 2–3 need the drainpipe or the roof and hatch. | |
| Roof hatch | Latched from inside | Opens from inside only, unless someone left it unlatched (difficulty tier 0). |
| Alley gate | Locked | Key in E's nightstand, floor 2 Room B. Mantling it depends on difficulty. |

### 5.4 Infrastructure (primary mechanics)

**Power: the breaker panel (basement).**
- The panel has a **main** switch plus one circuit per floor (F1, F2, F3) and
  one for the basement.
- Circuits feed interior lights, lamps and devices (TV, monitor, record
  player, washers, routers). Street lights, moonlight and neighbouring
  buildings are unaffected, so a powered-down building becomes a dark shell
  with cold light coming in through its windows. That's the look.
- Cutting a circuit that has awake residents on it creates a **disruption**.
  One responder (the nearest awake, eligible resident on that circuit) goes
  on an Errand to the breaker with their phone flashlight: a moving pool of
  light down the rear stair. They restore power after about 20 game-seconds
  at the panel, unless they're pulled into Suspicious or Searching.
- Other awake residents on the circuit get a suspicion bump to just above the
  Suspicious threshold (§3.3). They stop, switch on their phone lights and
  look toward the hall. They don't search unless something else pushes them
  over.
- Sleeping residents don't react to power loss.
- Losing power stops G's music, which removes G's noise mask, and wakes
  nobody.

**Water: the manhole valve (rear parking area).**
- Needs the manhole puller from the basement. Turning the valve shuts water to
  the whole building.
- Disrupted: E cooking (E finishes early and leaves about 15 game-minutes
  sooner), H's washer (H goes on an Errand to the basement, stays about
  15 game-minutes, then gives up), and anyone using the bathroom sink or
  shower.
- Turning water back on doesn't re-trigger errands.

**Network: routers (dining room, each floor).**
- Unplugging a floor's router disrupts that floor's network-dependent
  residents: C (floor 1) and F (floor 2). Floor 3 has no dependents in
  Mission 1, so the router there is a red herring.
- The responder walks to the dining room, next to the front entry, and
  replugs it after about 10 game-seconds. This pulls C away from their open
  door and F away from the TV.

Each disruption has **one responder at a time**. The rest of the building
keeps its routine, so the player can create deliberate, local windows rather
than chaos.

### 5.5 Mission 1 timeline (first pass, to be tuned in playtest)

Mission window: **23:00 → 05:00.**

| Time  | Event |
|-------|-------|
| 23:00 | Player starts in the car on the street. Text: *"3rd floor. Back bedroom. There's a [TARGET] in it. You have until 5. Don't disappoint me."* A, I asleep. C at computer. D in room. E cooking. F TV. G + H in F3 living room, record playing. B away. |
| 23:50 | E finishes cooking, eats at the dining table. |
| 00:15 | E leaves by the front door (the door is briefly open). E despawns. |
| 01:00 | H leaves G, gets laundry, goes down the rear stair to the basement. Washer starts. |
| 01:15 | C: kitchen trip (about 5 game-minutes). |
| 01:30 | H goes back up to F3 (living room with G). |
| 01:55 | H goes down to the basement again to move the laundry, then goes to bed by 02:15. |
| 02:00 | G stops the record, G to bed. Text: *"Three hours."* |
| 02:30 | F turns off the TV and goes to bed. |
| 03:00 | D: bathroom trip. C: bathroom trip. |
| 04:00 | B arrives, drunk, through the front door. Lights on in the F1 hall and kitchen. |
| 04:30 | B in bed. A and I wake up (early birds): bathroom, kitchen, lights on. Text: *"Tick tock."* |
| 05:00 | Deadline. |

`[TARGET]` is a placeholder: a single pickup with a data-defined name and
model, placed in Room I.

---

## 6. Mission flow and outcomes

### 6.1 Objective and success
Pick up the target and reach the **extraction zone** (the player's car on the
street) before the deadline. On success, the blackmailer texts *"Good. Keep
your phone on."* The phone screen shows the loot tally (§6.3). Press any key
to continue, which restarts at attempt 1 in the vertical slice.

### 6.2 Police
When an NPC reaches Alert, they spend about 1 game-minute calling. Then a
**police response timer** starts: 12 game-minutes (about 72 real seconds at
10:1, tunable). Distant sirens fade in during the last third. The player's
watch doesn't show this timer; the sirens are the timer. When police arrive:
- If the player is inside the property bounds (the building, alley, roof or
  rear lot), they're **arrested**, which is a mission failure (§6.4).
- If the player is outside with the target and reaches the car, it's a
  success. The police are too late.
- If the player is outside without the target, the attempt is failed but
  escaped. See Retry.

### 6.3 Loot
Optional valuables (cash, jewellery, electronics, prescription bottles) sit in
drawers, on nightstands and on desks. Each has a value. Taking nothing is a
fully viable playstyle, and the game never requires or rewards it within the
mission. The tally is recorded (for the future between-mission economy: a
steady "paycheck" plus stolen bonus). In the vertical slice it's only shown on
the end screen.

### 6.4 Failure and retry

| Outcome | Trigger | Result |
|---------|---------|--------|
| **Leak** | Mission clock hits 05:00 without an extraction | Fail screen: leak texts (§7.2). Restart at attempt 1. |
| **Arrested** | Police arrive while the player is on the property | Blackmailer texts *"Deal's off."*, then the leak texts. Restart at attempt 1. |
| **Escaped empty-handed** | Player reaches extraction without the target after any resident went Alert, or chooses to leave (hold F on the car door) | Text: *"You're making this harder for yourself. Tomorrow night."* **Retry with increased difficulty** (attempt + 1). |

**Difficulty tiers** raise the attempt counter one step each time, up to
tier 3:
- Tier 1: residents' sight gain ×1.15, and the alley gate can't be mantled
  (top is too high).
- Tier 2: the F1 Room B window is also locked, residents' wariness floor
  starts at 15, and the deadline is 04:30 ("Tomorrow night you have less
  time.").
- Tier 3: the roof hatch is always latched, the living-room bay is locked,
  and sight gain ×1.3.

Tiers are data (ARCHITECTURE.md §6.5).

---

## 7. Diegetic UI

There is no HUD, no floating text, no objective markers and no pause menu.

### 7.1 The watch
Hold T to raise the left wrist. The face is analog, with a sweep second hand
(which moves ×10 speed at the 10:1 time scale, a visible reminder that time is
compressed). The hands are luminous, readable in the dark and washed out in
bright light. There's a small date window showing the date. That's all.

### 7.2 Fail screen: the leak
When the leak drops, the camera pulls into the phone, which fills the screen.
Notifications arrive one by one, staggered and accelerating: a coworker
("is this you??"), a sibling ("call me. now."), an ex, a group chat, the boss,
unknown numbers. The phone never shows the leaked material itself. After
about 20 seconds the notifications keep coming, the screen dims, and a
"press any key" prompt appears on the lock screen as a clock-style widget.
The message content is data (a list of `{sender, text, delay}` entries).

### 7.3 Blackmailer texts
These show in the phone thread. The sender is an unsaved number. The phone
vibrates quietly on arrival (a noise event), and the player chooses when to
raise it and read.

### 7.4 Inventory
See §2.5. The selected item sits in the hand. Cycling lifts the new item into
view. There's no wheel graphic: order is fixed and learned.

---

## 8. Open decisions (to be settled in playtest)

1. **Visibility feedback without a light gem.** The default is hands lit by
   real lighting plus luminous watch hands. If playtest shows players can't
   read their exposure, the fallback is a diegetic "exposure" cue on the
   watch: the watch bezel glints when light hits the wrist.
2. **Time scale.** 10:1 by default. 5:1 is the fallback if the night feels
   rushed.
3. **Phone vibration noise.** 2 m radius by default. Remove it if players find
   it unfair rather than tense.

---

## 9. Scope exclusions (vertical slice)

Not in the vertical slice:
- Multiple missions.
- The between-mission economy, shop, upgrades and tools (lockpicks,
  flashlight, grappling hook, slim jim, weapons, quieter shoes).
- Save/load. Retry-with-difficulty lives in memory only.
- Main menu, settings or rebinding.
- Online features.
- Procedural generation.
- A dialogue system (barks are one-shot audio only).
- Violence, knockouts and combat.
- Gamepad support.
- Ray-traced sound occlusion.
- NPC-to-NPC conversation.
- Vehicles beyond the static car used for extraction.
- The final Mission 1 map. The developer builds it in TrenchBroom. The slice
  ships with a greybox townhouse built through the same pipeline.
