extends GutTest

## Ladder and pipe climbing, with the auto-mantle at the top
## (DESIGN.md §2.1, ARCHITECTURE.md §4.2).

var player: PlayerController


func before_each() -> void:
	var floor_body: StaticBody3D = PlayerTestHelpers.make_floor(30.0)
	add_child_autofree(floor_body)
	player = PlayerTestHelpers.make_player()
	add_child_autofree(player)
	player.input_reader.enabled = false
	player.rotation.y = PI  # face +Z, matching the climbable's placement below


func _enter_climb(climbable: Area3D, top_y: float) -> void:
	# Matches PlayerTestHelpers.make_climbable's TopMarker, which sits at
	# local (0, top_y/2 + 0.3, -1.2) on a Climbable centred at
	# (0, top_y/2, 0) -> global y = top_y + 0.3. Offset in Z, clear of the
	# 0.6 m climbing shaft, so the platform's underside doesn't clip the
	# player's head while it's still climbing.
	var platform: StaticBody3D = PlayerTestHelpers.make_box_body(
		Vector3(0.0, top_y + 0.25, -1.2), Vector3(2.0, 0.1, 1.4)
	)
	add_child_autofree(platform)
	add_child_autofree(climbable)

	player.global_position = Vector3(0.0, 0.02, -1.0)
	player.intent.wish_dir = Vector2(0.0, 1.0)
	# Walk into the Climbable's Area3D so nearby_climbable gets set by its
	# body_entered signal, then keep holding forward to start climbing.
	for _i in range(60):
		await wait_physics_frames(1)
		if player.state_machine.current_state_name == &"Climbing":
			break


func _climb_to_mantle(max_frames: int) -> int:
	var frames_taken: int = 0
	for _i in range(max_frames):
		await wait_physics_frames(1)
		frames_taken += 1
		if player.state_machine.current_state_name == &"Grounded":
			break
	return frames_taken


func test_ladder_climb_auto_mantles_onto_platform() -> void:
	var ladder: Area3D = PlayerTestHelpers.make_climbable(Climbable.Kind.LADDER, 3.0)
	await _enter_climb(ladder, 3.0)
	assert_eq(player.state_machine.current_state_name, &"Climbing")

	await _climb_to_mantle(400)
	assert_eq(player.state_machine.current_state_name, &"Grounded")
	assert_gt(player.global_position.y, 2.5)


func test_pipe_is_slower_than_ladder() -> void:
	var ladder: Area3D = PlayerTestHelpers.make_climbable(Climbable.Kind.LADDER, 3.0)
	await _enter_climb(ladder, 3.0)
	var ladder_frames: int = await _climb_to_mantle(400)

	# Fresh scene for the pipe run.
	player.queue_free()
	await wait_physics_frames(1)
	player = PlayerTestHelpers.make_player()
	add_child_autofree(player)
	player.input_reader.enabled = false
	player.rotation.y = PI

	var pipe: Area3D = PlayerTestHelpers.make_climbable(Climbable.Kind.PIPE, 3.0)
	await _enter_climb(pipe, 3.0)
	var pipe_frames: int = await _climb_to_mantle(400)

	assert_gt(pipe_frames, ladder_frames, "the pipe should take longer to climb the same height")
