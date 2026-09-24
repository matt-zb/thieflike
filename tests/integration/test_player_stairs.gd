extends GutTest

## Stairs are invisible ramp colliders (ARCHITECTURE.md §4.2): walking up
## one should gain height while floor snap keeps the player Grounded the
## whole way, never dropping into Airborne.

var player: PlayerController


func before_each() -> void:
	var floor_body: StaticBody3D = PlayerTestHelpers.make_floor(30.0)
	add_child_autofree(floor_body)

	# A 32 deg ramp rising 2 m over 3.2 m of run, within the 30-35 deg range
	# ARCHITECTURE.md §4.1 asks the floor_max_angle / snap tuning to suit.
	var rise: float = 2.0
	var run: float = 3.2
	var angle: float = atan2(rise, run)
	var ramp_len: float = Vector2(run, rise).length()
	var ramp: StaticBody3D = StaticBody3D.new()
	ramp.collision_layer = 1
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3.0, 0.2, ramp_len)
	shape_node.shape = shape
	ramp.add_child(shape_node)
	ramp.position = Vector3(0.0, rise * 0.5, 3.0 + run * 0.5)
	ramp.rotation.x = -angle
	add_child_autofree(ramp)

	var top_platform: StaticBody3D = PlayerTestHelpers.make_box_body(
		Vector3(0.0, rise, 3.0 + run + 1.0), Vector3(3.0, 0.2, 2.0)
	)
	add_child_autofree(top_platform)

	player = PlayerTestHelpers.make_player()
	add_child_autofree(player)
	player.input_reader.enabled = false
	player.rotation.y = PI
	player.global_position = Vector3(0.0, 0.02, 0.5)


func test_walking_up_the_ramp_gains_height_without_airborne() -> void:
	# Let the small initial gap to the floor settle onto Grounded before
	# starting the assertion window.
	await wait_physics_frames(5)
	player.intent.wish_dir = Vector2(0.0, 1.0)
	player.intent.run = true
	var start_y: float = player.global_position.y
	var went_airborne: bool = false

	for _i in range(300):
		await wait_physics_frames(1)
		if player.state_machine.current_state_name == &"Airborne":
			went_airborne = true
		if player.global_position.y > start_y + 1.5:
			break

	assert_false(went_airborne, "climbing a 30-35 deg stair ramp should not leave Grounded")
	assert_gt(player.global_position.y, start_y + 1.5)
