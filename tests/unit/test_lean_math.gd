extends GutTest

## LeanMath: the wall-clearance clamp (ARCHITECTURE.md §4.3).


func test_no_hit_returns_target_unclamped() -> void:
	assert_eq(LeanMath.clamp_lean(1.0, 0.0, false), 1.0)
	assert_eq(LeanMath.clamp_lean(-0.6, 0.3, false), -0.6)


func test_hit_clamps_to_clearance_fraction() -> void:
	assert_almost_eq(LeanMath.clamp_lean(1.0, 0.4, true), 0.4, 0.0001)
	assert_almost_eq(LeanMath.clamp_lean(-1.0, 0.4, true), -0.4, 0.0001)


func test_hit_does_not_expand_a_smaller_target() -> void:
	# Already-partial lean shouldn't be pushed further out by clearance.
	assert_almost_eq(LeanMath.clamp_lean(0.2, 0.8, true), 0.2, 0.0001)


func test_hit_with_full_clearance_is_a_no_op() -> void:
	assert_almost_eq(LeanMath.clamp_lean(0.9, 1.0, true), 0.9, 0.0001)


func test_hit_with_zero_clearance_forces_center() -> void:
	assert_almost_eq(LeanMath.clamp_lean(0.9, 0.0, true), 0.0, 0.0001)
