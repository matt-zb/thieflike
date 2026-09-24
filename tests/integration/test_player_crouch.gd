extends GutTest

## Crouch capsule resize and the StandCheck block (DESIGN.md §2.1,
## ARCHITECTURE.md §4.1).

var player: PlayerController


func before_each() -> void:
	var floor_body: StaticBody3D = PlayerTestHelpers.make_floor(20.0)
	add_child_autofree(floor_body)
	player = PlayerTestHelpers.make_player()
	add_child_autofree(player)
	player.input_reader.enabled = false
	player.global_position = Vector3(0.0, 0.02, 0.0)
	await wait_physics_frames(3)  # let the player settle onto the floor first


## wait_physics_frames(1) actually spans two physics_frame signals (see
## addons/gut/awaiter.gd's `_elapsed_frames > _wait_physics_frames`), which
## would toggle a parity-sensitive flag like crouch twice and cancel out.
## Awaiting the tree's own physics_frame signal directly gives exactly one
## tick between setting and clearing the edge-triggered intent.
func _toggle_crouch() -> void:
	player.intent.crouch_toggled = true
	await get_tree().physics_frame
	player.intent.crouch_toggled = false
	await get_tree().physics_frame


func test_crouch_shrinks_the_capsule_with_feet_planted() -> void:
	var capsule: CapsuleShape3D = player.collider.shape as CapsuleShape3D
	var feet_before: float = player.collider.global_position.y - capsule.height * 0.5
	await _toggle_crouch()
	# Let the collider's own resize settle (it's applied immediately in
	# set_crouched, not animated, so one frame is enough).
	await wait_physics_frames(2)
	assert_true(player.crouched)
	assert_almost_eq(capsule.height, player.crouch_height, 0.01)
	var feet_after: float = player.collider.global_position.y - capsule.height * 0.5
	assert_almost_eq(feet_after, feet_before, 0.05)


func test_uncrouch_is_blocked_under_a_low_ceiling() -> void:
	var ceiling: StaticBody3D = PlayerTestHelpers.make_ceiling(1.3, 0.0)
	add_child_autofree(ceiling)

	await _toggle_crouch()
	assert_true(player.crouched)

	# Try to stand back up while still under the 1.3 m ceiling.
	await _toggle_crouch()
	assert_true(player.crouched, "StandCheck should refuse to uncrouch under a low ceiling")
