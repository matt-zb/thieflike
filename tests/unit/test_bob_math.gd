extends GutTest

## BobMath: bob cadence math, tested directly since the AnimationTree it
## feeds may not advance in a headless test run (see
## tests/integration/test_player_bob.gd, and the note in MILESTONES.md M1).

const WALK_SPEED: float = 2.2
const RUN_SPEED: float = 4.8
const BASE_CYCLE: float = 0.6


func test_timescale_at_walk_speed_is_one() -> void:
	assert_almost_eq(BobMath.bob_timescale(WALK_SPEED, WALK_SPEED), 1.0, 0.001)


func test_timescale_scales_with_speed() -> void:
	var run_scale: float = BobMath.bob_timescale(RUN_SPEED, WALK_SPEED)
	assert_almost_eq(run_scale, RUN_SPEED / WALK_SPEED, 0.001)


func test_timescale_is_clamped() -> void:
	assert_almost_eq(BobMath.bob_timescale(0.0, WALK_SPEED), 0.2, 0.001)
	assert_almost_eq(BobMath.bob_timescale(100.0, WALK_SPEED), 3.0, 0.001)


func test_foot_plant_interval_is_half_the_cycle() -> void:
	var period: float = BobMath.bob_period(WALK_SPEED, WALK_SPEED, BASE_CYCLE)
	assert_almost_eq(period, BASE_CYCLE, 0.001)
	assert_almost_eq(BobMath.foot_plant_interval(WALK_SPEED, WALK_SPEED, BASE_CYCLE), BASE_CYCLE * 0.5, 0.001)


func test_faster_gait_plants_feet_more_often() -> void:
	var walk_interval: float = BobMath.foot_plant_interval(WALK_SPEED, WALK_SPEED, BASE_CYCLE)
	var run_interval: float = BobMath.foot_plant_interval(RUN_SPEED, WALK_SPEED, BASE_CYCLE)
	assert_lt(run_interval, walk_interval)
