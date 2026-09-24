class_name BobMath
extends RefCounted

## Pure cadence math for the head-bob cycle (ARCHITECTURE.md §4.3). The bob
## animation itself lives in an AnimationTree, which doesn't reliably
## advance in a headless test run, so the *timing* it should produce is
## covered here instead (see tests/integration/test_player_bob.gd).


## Mirrors PlayerController._update_rig_animator's `bob_timescale` formula:
## the baked bob cycle (authored at walk_speed's cadence) is sped up or
## slowed by `speed / walk_speed`, clamped so it never freezes or spins.
static func bob_timescale(speed: float, walk_speed: float, min_scale: float = 0.2, max_scale: float = 3.0) -> float:
	if walk_speed <= 0.0:
		return min_scale
	return clampf(speed / walk_speed, min_scale, max_scale)


## Wall-clock duration of one full bob cycle at the given speed.
static func bob_period(speed: float, walk_speed: float, base_cycle_length: float) -> float:
	var scale: float = bob_timescale(speed, walk_speed)
	if scale <= 0.0:
		return INF
	return base_cycle_length / scale


## A bob cycle plants one foot at its quarter point and the other at its
## three-quarter point (tools/build_rig_animations.gd), so a foot plants
## twice per cycle, evenly spaced.
static func foot_plant_interval(speed: float, walk_speed: float, base_cycle_length: float) -> float:
	return bob_period(speed, walk_speed, base_cycle_length) * 0.5
