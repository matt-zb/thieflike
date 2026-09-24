extends GutTest

## MovementMath: accel/decel curves, reversal skid, air control cap
## (DESIGN.md §2.1, MILESTONES.md M1).

const CREEP_SPEED: float = 1.0
const CREEP_ACCEL_TIME: float = 0.20
const CREEP_DECEL_TIME: float = 0.12

const WALK_SPEED: float = 2.2
const WALK_ACCEL_TIME: float = 0.30
const WALK_DECEL_TIME: float = 0.20

const RUN_SPEED: float = 4.8
const RUN_ACCEL_TIME: float = 0.55
const RUN_DECEL_TIME: float = 0.40

const FRAME: float = 1.0 / 60.0
const FRAME_TOLERANCE: float = FRAME * 1.5


func _time_to_reach(target_speed: float, accel_time: float, threshold_frac: float = 0.99) -> float:
	var rate: float = MovementMath.rate_from_time(target_speed, accel_time)
	var v: Vector2 = Vector2.ZERO
	var wish: Vector2 = Vector2.UP
	var t: float = 0.0
	var threshold: float = target_speed * threshold_frac
	while v.length() < threshold and t < 5.0:
		v = MovementMath.horizontal_move(v, wish, target_speed, rate, rate, FRAME)
		t += FRAME
	return t


func _time_to_stop(target_speed: float, decel_time: float) -> float:
	var accel_rate: float = MovementMath.rate_from_time(target_speed, 0.05)
	var decel_rate: float = MovementMath.rate_from_time(target_speed, decel_time)
	var v: Vector2 = Vector2.UP * target_speed
	var t: float = 0.0
	while v.length() > 0.01 and t < 5.0:
		v = MovementMath.horizontal_move(v, Vector2.ZERO, target_speed, accel_rate, decel_rate, FRAME)
		t += FRAME
	return t


func test_creep_time_to_full_speed() -> void:
	var t: float = _time_to_reach(CREEP_SPEED, CREEP_ACCEL_TIME)
	assert_almost_eq(t, CREEP_ACCEL_TIME, FRAME_TOLERANCE)


func test_walk_time_to_full_speed() -> void:
	var t: float = _time_to_reach(WALK_SPEED, WALK_ACCEL_TIME)
	assert_almost_eq(t, WALK_ACCEL_TIME, FRAME_TOLERANCE)


func test_run_time_to_full_speed() -> void:
	var t: float = _time_to_reach(RUN_SPEED, RUN_ACCEL_TIME)
	assert_almost_eq(t, RUN_ACCEL_TIME, FRAME_TOLERANCE)


func test_walk_decel_to_stop() -> void:
	var t: float = _time_to_stop(WALK_SPEED, WALK_DECEL_TIME)
	assert_almost_eq(t, WALK_DECEL_TIME, FRAME_TOLERANCE)


func test_run_decel_to_stop() -> void:
	var t: float = _time_to_stop(RUN_SPEED, RUN_DECEL_TIME)
	assert_almost_eq(t, RUN_DECEL_TIME, FRAME_TOLERANCE)


## A hard reversal at run speed bleeds off through the decel rate before the
## accel rate can build speed the other way, which is what produces the
## "about 0.3 s of skid" DESIGN.md §2.1 describes. We assert the time to
## cross zero velocity is in that ballpark, with a generous tolerance since
## the design text itself says "about".
func test_run_reversal_skid_roughly_point_three_seconds() -> void:
	var accel_rate: float = MovementMath.rate_from_time(RUN_SPEED, RUN_ACCEL_TIME)
	var decel_rate: float = MovementMath.rate_from_time(RUN_SPEED, RUN_DECEL_TIME)
	var v: Vector2 = Vector2.UP * RUN_SPEED
	var wish: Vector2 = Vector2.DOWN
	var t: float = 0.0
	while v.dot(Vector2.UP) > 0.0 and t < 5.0:
		v = MovementMath.horizontal_move(v, wish, RUN_SPEED, accel_rate, decel_rate, FRAME)
		t += FRAME
	assert_almost_eq(t, 0.3, 0.15)


func test_air_control_capped_at_15_percent_of_ground_accel() -> void:
	var ground_accel: float = MovementMath.rate_from_time(RUN_SPEED, RUN_ACCEL_TIME)
	var air_pct: float = 0.15
	var v: Vector2 = Vector2.ZERO
	v = MovementMath.air_move(v, Vector2.UP, RUN_SPEED, ground_accel, air_pct, FRAME)
	var expected_delta: float = ground_accel * air_pct * FRAME
	assert_almost_eq(v.length(), expected_delta, 0.001)

	# Over a full second, air control alone should fall well short of full
	# ground speed (it's capped, not merely slow).
	v = Vector2.ZERO
	for _i in range(60):
		v = MovementMath.air_move(v, Vector2.UP, RUN_SPEED, ground_accel, air_pct, FRAME)
	assert_lt(v.length(), RUN_SPEED * 0.5)


func test_jump_speed_for_height() -> void:
	var gravity: float = 20.0
	var height: float = 0.45
	var speed: float = MovementMath.jump_speed_for_height(height, gravity)
	# Check it actually reaches ~height under that gravity: apex = v^2/(2g).
	var apex: float = (speed * speed) / (2.0 * gravity)
	assert_almost_eq(apex, height, 0.01)


func test_rate_from_time_guards_zero_time() -> void:
	assert_eq(MovementMath.rate_from_time(2.0, 0.0), INF)
