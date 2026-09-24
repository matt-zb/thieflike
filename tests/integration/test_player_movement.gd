extends GutTest

## Real-physics coverage of ground movement, jumping, falling and landing
## (MILESTONES.md M1). Drives PlayerController by setting `intent` directly
## and stepping real physics frames, per the milestone's instruction.

var player: PlayerController


func before_each() -> void:
	# A modest floor patch, not the full 50 m fixture default: fast enough
	# gaits over the longer test runs (run speed x1.5s) would otherwise run
	# past a same-sized floor before decel/landing assertions finish.
	var floor_body: StaticBody3D = PlayerTestHelpers.make_box_body(Vector3(0, -0.5, 5), Vector3(20, 1, 30))
	add_child_autofree(floor_body)
	player = PlayerTestHelpers.make_player()
	add_child_autofree(player)
	player.input_reader.enabled = false
	player.global_position = Vector3(0.0, 0.02, 0.0)
	await wait_physics_frames(3)


func _walk_forward(frames: int) -> void:
	player.intent.wish_dir = Vector2(0.0, 1.0)
	await wait_physics_frames(frames)


func test_walk_reaches_about_2_2_ms() -> void:
	await _walk_forward(60)
	var speed: float = player.horizontal_velocity().length()
	assert_almost_eq(speed, 2.2, 0.3)


func test_run_reaches_about_4_8_ms() -> void:
	player.intent.run = true
	await _walk_forward(90)
	var speed: float = player.horizontal_velocity().length()
	assert_almost_eq(speed, 4.8, 0.4)


func test_creep_reaches_about_1_0_ms() -> void:
	player.intent.creep = true
	await _walk_forward(40)
	var speed: float = player.horizontal_velocity().length()
	assert_almost_eq(speed, 1.0, 0.2)


func test_crouch_walk_reaches_about_1_2_ms() -> void:
	# wait_physics_frames(1) actually spans two physics_frame signals (see
	# addons/gut/awaiter.gd), which would toggle crouch on and back off
	# again; awaiting the tree's own signal gives exactly one tick.
	player.intent.crouch_toggled = true
	await get_tree().physics_frame
	player.intent.crouch_toggled = false
	await get_tree().physics_frame
	await _walk_forward(40)
	var speed: float = player.horizontal_velocity().length()
	assert_true(player.crouched)
	assert_almost_eq(speed, 2.2 * 0.55, 0.25)


func test_releasing_input_stops_within_decel_time() -> void:
	await _walk_forward(60)
	player.intent.wish_dir = Vector2.ZERO
	# walk_decel_time is 0.2s; give a couple of frames' slack.
	await wait_physics_frames(int(0.2 * 60) + 3)
	assert_almost_eq(player.horizontal_velocity().length(), 0.0, 0.15)


func test_walking_off_a_ledge_becomes_airborne_then_lands() -> void:
	# Built off to one side (x=100) so it doesn't interact with the shared
	# before_each floor. Default (unrotated) facing walks toward -Z, so the
	# upper patch's near edge (its -Z face) is the drop: a lower floor
	# already sits underneath everything past that edge, so there's a clean
	# 2 m step down rather than an open pit.
	var upper_floor: StaticBody3D = PlayerTestHelpers.make_box_body(Vector3(100, -0.5, 0), Vector3(6, 1, 8))
	add_child_autofree(upper_floor)
	var lower_floor: StaticBody3D = PlayerTestHelpers.make_box_body(Vector3(100, -2.5, -12), Vector3(20, 1, 20))
	add_child_autofree(lower_floor)

	player.global_position = Vector3(100.0, 0.02, -1.0)
	player.intent.wish_dir = Vector2(0.0, 1.0)
	player.intent.run = true

	var became_airborne: bool = false
	for _i in range(180):
		await wait_physics_frames(1)
		if player.state_machine.current_state_name == &"Airborne":
			became_airborne = true
			break
	assert_true(became_airborne, "player should leave Grounded after walking off the floor's edge")

	# A single-element Array, not a bool: GDScript lambdas capture outer
	# locals by value, so a plain `bool = true` inside the callable would
	# only ever update its own copy. Array/Dictionary are captured by
	# reference, so mutating their contents is visible outside.
	var landed_signal_seen: Array = [false]
	var on_landed: Callable = func(_fall_speed: float) -> void:
		landed_signal_seen[0] = true
	player.landed.connect(on_landed)

	for _i in range(240):
		await wait_physics_frames(1)
		if player.state_machine.current_state_name == &"Grounded" and landed_signal_seen[0]:
			break
	assert_eq(player.state_machine.current_state_name, &"Grounded")
	assert_true(landed_signal_seen[0], "landed signal should fire once back on the floor")


func test_jump_height_is_about_0_45m() -> void:
	var start_y: float = player.global_position.y
	var peak_y: float = start_y
	player.intent.jump_pressed = true
	await wait_physics_frames(1)
	player.intent.jump_pressed = false
	for _i in range(90):
		await wait_physics_frames(1)
		peak_y = max(peak_y, player.global_position.y)
		if player.state_machine.current_state_name == &"Grounded" and player.global_position.y <= start_y + 0.01:
			break
	assert_almost_eq(peak_y - start_y, 0.45, 0.15)
