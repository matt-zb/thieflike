## Premise

Modern-day. Protagonist is blackmailed into increasingly serious burglaries.
Inspired by Black Mirror's "Shut Up and Dance." Tone is tense, grounded,
not campy. The player should feel guilty.

## Mission 1: The Townhouse

Three-story apartment building with a basement. Based on a real building
the developer lived in during college.

- All three floors have identical layouts, different furniture and inhabitants.
- There is a locked alleyway along one side.
- The target item is on the third floor.
- Missing the mission deadline causes the blackmail material to be released
  (mission failure).

### Floor plan

See `docs/mission1_floorplan.png` (developer sketch, one floor; all three
floors share this layout). Street at the front, alleyway on the left,
parking area at the rear.

Each floor of the apartment is identical. The game "maps" will be handcrafted by the User using trenchbroom, and provided to you at a later time. The goal of the project is to create a proof-of-concept "tech demo" wherein the game is feature-complete but has no "levels" yet, so to speak.

Each floor has three rooms along a single straight hallway, front-to-back. The bathroom is opposite the rooms. The kitchen is at the rear, with a back entrance leading to a staircase (this is the only basement/laundry access at the bottom, with a ladder hatch to the roof at the top) and an exterior door at the bottom of the staircase. The living room is at the front.

### Inhabitants

Inhabitants are listed from front to back.

Floor 1: A is an early bird, so should be in bed early but is a light sleeper; B is basically never home, always out partying till late; C is up all night with his door open on the computer listening to headphones
Floor 2: D is a night owl but reclusive; E cooks a meal at night before working night shift; F watches TV in the living room.
Floor 3: G listens to music at night on a record player in the living room; H is with G then goes to do laundry in the basement; I is like floor 1 A. Object in 3I.
Basement: Power switch, manhole puller for water line access in the rear parking lot, washing machines.

These are the types of simple "routines" that should be considered when designing levels.

### Entry points

Front door, rear door, ground floor windows on the alleyway side or front of the residence. The rear kitchen windows open as well. Doors would be locked, windows less likely to be so. Resident E has a copy of the alleyway key in their nightstand drawer.

No fire escape. Roof access is the single hatch.

### Infrastructure

- Breaker in the basement
- Water shutoff under a manhole in the rear parking area
- Cable boxes/routers in individual rooms. Most residents place theirs in the dining room, which is between the bathroom and the front door.

## Core feel

The player controller should feel **heavy without feeling cumbersome**.
Reference: Thief 1/2's movement — deliberate, physical, with real
momentum. Not floaty, not snappy. The player is a person, not a camera.

## Light and darkness

Light is the core aesthetic and the core mechanic. The game must look
beautiful in darkness with occasional pools of warm, harsh, or colored
light. No baked lighting — everything real-time (SDFGI in Forward+).
The player hides in darkness; the tension is about crossing lit spaces.

Disabling power at the breaker changes the light map of the whole
building. This is a primary mechanic, not a gimmick.

## UI philosophy

All UI is diegetic:
- Timer = the character's wristwatch.
- Fail screen = incoming text messages from friends/coworkers reacting
  to the leaked material.
- Inventory = a backpack or pockets. One item selected at a time
  (Thief weapon-wheel style). No pause-menu inventory screen.

## Explicit non-goals for the vertical slice

- Multiple missions.
- Save/load system.
- Main menu or settings screen.
- Any online features.
- Procedural generation.
- Dialogue system.
- Upgrade or progression system.
