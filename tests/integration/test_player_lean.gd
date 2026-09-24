extends GutTest

## Lean is clamped by LeanClearance when a wall is close by
## (DESIGN.md §2.1, ARCHITECTURE.md §4.3).

var player: PlayerController


func before_each() -> void:
	var floor_body: StaticBody3D = PlayerTestHelpers.make_floor(20.0)
	add_child_autofree(floor_body)
	player = PlayerTestHelpers.make_player()
	add_child_autofree(player)
	player.input_reader.enabled = false
	player.global_position = Vector3(0.0, 0.02, 0.0)
	await wait_physics_frames(3)


func test_lean_is_unclamped_in_open_space() -> void:
	player.intent.lean = 1.0
	# lean_blend_speed is 5/s; a lean of magnitude 1 takes ~0.2s to settle.
	await wait_physics_frames(30)
	assert_almost_eq(player._lean_blend, 1.0, 0.1)


func test_lean_is_clamped_by_a_nearby_wall() -> void:
	# A wall just to the right of the camera, close enough to be within the
	# unclamped lean's reach (lean_max_offset + margin) but clear of the
	# player's own 0.35 m capsule radius so the body itself never touches it.
	var wall: StaticBody3D = PlayerTestHelpers.make_box_body(Vector3(0.5, 1.5, 0.0), Vector3(0.2, 2.0, 2.0))
	add_child_autofree(wall)

	player.intent.lean = 1.0
	await wait_physics_frames(30)
	assert_lt(player._lean_blend, 0.9, "leaning into a nearby wall should be clamped short of full lean")
