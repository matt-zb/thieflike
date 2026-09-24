class_name MovementMath
extends RefCounted

## Pure math for the player's (and, later, an NPC's) ground and air
## movement model (DESIGN.md §2.1, ARCHITECTURE.md §4.2). No node access,
## so it's covered entirely by unit tests.


## Converts a "time to reach full speed" (as tuned in DESIGN.md's table)
## into an acceleration in m/s^2. Guards against a zero time (instant).
static func rate_from_time(speed: float, time_to_speed: float) -> float:
	if time_to_speed <= 0.0:
		return INF
	return speed / time_to_speed


## The accel/decel/reversal-skid model: `v = v.move_toward(wish * target,
## rate * delta)`, where `rate` is `accel_rate` when the wish direction
## aligns with the current velocity and `decel_rate` otherwise. A reversal
## (wish opposes current velocity) therefore bleeds off through the decel
## rate before building back up through the accel rate once the velocity
## has crossed zero, which is what produces the run's ~0.3 s reversal skid.
## Operates on horizontal (XZ) vectors; callers pass the vertical component
## through separately.
static func horizontal_move(
	current: Vector2,
	wish_dir: Vector2,
	target_speed: float,
	accel_rate: float,
	decel_rate: float,
	delta: float
) -> Vector2:
	var wish: Vector2 = wish_dir
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target: Vector2 = wish * target_speed
	var rate: float
	if wish == Vector2.ZERO:
		rate = decel_rate
	elif current.dot(wish) >= 0.0:
		rate = accel_rate
	else:
		rate = decel_rate
	return current.move_toward(target, rate * delta)


## Airborne movement: at most `air_control_pct` of the ground accel rate,
## and no reversal skid (DESIGN.md §2.1: "no air control beyond 15% of
## ground acceleration").
static func air_move(
	current: Vector2,
	wish_dir: Vector2,
	target_speed: float,
	ground_accel_rate: float,
	air_control_pct: float,
	delta: float
) -> Vector2:
	var wish: Vector2 = wish_dir
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target: Vector2 = wish * target_speed
	var rate: float = ground_accel_rate * air_control_pct
	return current.move_toward(target, rate * delta)


## Jump takeoff speed for a target apex height under the given gravity
## (v = sqrt(2 * g * h)).
static func jump_speed_for_height(height: float, gravity: float) -> float:
	return sqrt(2.0 * gravity * height)
