extends GutTest

## MantleMath: height acceptance and duration scaling (DESIGN.md §2.1).
## Mantle range is 0.2-1.9 m: 0.2-0.5 m is a quick, constant step-up;
## 0.5-1.9 m scales as before.

const MIN_H: float = 0.2
const STEP_UP_MAX_H: float = 0.5
const MAX_H: float = 1.9
const STEP_UP_D: float = 0.3
const MIN_D: float = 0.6
const MAX_D: float = 0.9


func test_heights_in_range_are_accepted() -> void:
	assert_true(MantleMath.is_height_acceptable(0.2, MIN_H, MAX_H))
	assert_true(MantleMath.is_height_acceptable(0.5, MIN_H, MAX_H))
	assert_true(MantleMath.is_height_acceptable(1.0, MIN_H, MAX_H))
	assert_true(MantleMath.is_height_acceptable(1.9, MIN_H, MAX_H))


func test_heights_outside_range_are_refused() -> void:
	assert_false(MantleMath.is_height_acceptable(0.15, MIN_H, MAX_H))
	assert_false(MantleMath.is_height_acceptable(2.0, MIN_H, MAX_H))
	assert_false(MantleMath.is_height_acceptable(0.0, MIN_H, MAX_H))


func test_low_ledges_get_the_constant_step_up_duration() -> void:
	assert_almost_eq(
		MantleMath.duration_for_height(0.2, STEP_UP_MAX_H, MAX_H, STEP_UP_D, MIN_D, MAX_D),
		STEP_UP_D, 0.001
	)
	assert_almost_eq(
		MantleMath.duration_for_height(0.35, STEP_UP_MAX_H, MAX_H, STEP_UP_D, MIN_D, MAX_D),
		STEP_UP_D, 0.001
	)
	assert_almost_eq(
		MantleMath.duration_for_height(0.5, STEP_UP_MAX_H, MAX_H, STEP_UP_D, MIN_D, MAX_D),
		STEP_UP_D, 0.001
	)


func test_duration_scales_between_step_up_max_and_max_height() -> void:
	# Just above the step-up cutoff, duration starts at min_duration, not
	# the step-up duration -- the 0.6-0.9 s scaling begins at 0.5 m.
	assert_almost_eq(
		MantleMath.duration_for_height(0.5 + 0.0001, STEP_UP_MAX_H, MAX_H, STEP_UP_D, MIN_D, MAX_D),
		MIN_D, 0.01
	)
	assert_almost_eq(
		MantleMath.duration_for_height(MAX_H, STEP_UP_MAX_H, MAX_H, STEP_UP_D, MIN_D, MAX_D),
		MAX_D, 0.001
	)
	var mid: float = (STEP_UP_MAX_H + MAX_H) * 0.5
	var mid_duration: float = MantleMath.duration_for_height(mid, STEP_UP_MAX_H, MAX_H, STEP_UP_D, MIN_D, MAX_D)
	assert_almost_eq(mid_duration, (MIN_D + MAX_D) * 0.5, 0.01)


func test_duration_clamps_out_of_range_heights() -> void:
	assert_almost_eq(
		MantleMath.duration_for_height(0.0, STEP_UP_MAX_H, MAX_H, STEP_UP_D, MIN_D, MAX_D),
		STEP_UP_D, 0.001
	)
	assert_almost_eq(
		MantleMath.duration_for_height(5.0, STEP_UP_MAX_H, MAX_H, STEP_UP_D, MIN_D, MAX_D),
		MAX_D, 0.001
	)
