extends GutTest

## Real-physics mantle coverage across the accepted 0.2-1.9 m range (with
## the 0.2-0.5 m quick step-up and the 0.5-1.9 m scaled climb), the refused
## 0.15/2.0 m ends, and the crouch-fit window gap (DESIGN.md §2.1,
## ARCHITECTURE.md §4.2).

var player: PlayerController


func before_each() -> void:
	var floor_body: StaticBody3D = PlayerTestHelpers.make_floor(30.0)
	add_child_autofree(floor_body)
	player = PlayerTestHelpers.make_player()
	add_child_autofree(player)
	player.input_reader.enabled = false
	# Face +Z, matching PlayerTestHelpers.make_ledge's front-face convention.
	player.rotation.y = PI


func _approach_and_jump(front_z: float, timeout_frames: int = 240) -> void:
	player.global_position = Vector3(0.0, 0.02, front_z - 1.6)
	player.intent.wish_dir = Vector2(0.0, 1.0)
	# Walk up to (but not into) the wall first, at a speed and distance that
	# keeps it well clear in the time given, so an early jump doesn't just
	# launch a normal vertical jump before the wall is in probe range.
	await wait_physics_frames(75)
	# Now hold jump each frame until the state machine either accepts the
	# mantle or we give up (refused-height cases).
	for _i in range(timeout_frames):
		player.intent.jump_pressed = true
		await wait_physics_frames(1)
		player.intent.jump_pressed = false
		if player.state_machine.current_state_name == &"Mantling":
			break


## Returns the number of physics frames it took to reach Grounded, so
## callers can check the mantle's actual duration.
func _run_mantle_to_completion(max_frames: int = 90) -> int:
	var frames_taken: int = 0
	for _i in range(max_frames):
		await wait_physics_frames(1)
		frames_taken += 1
		if player.state_machine.current_state_name == &"Grounded":
			break
	return frames_taken


func test_mantle_0_5m_ends_grounded_on_top() -> void:
	var ledge: StaticBody3D = PlayerTestHelpers.make_ledge(3.0, 0.5)
	add_child_autofree(ledge)
	await _approach_and_jump(3.0)
	assert_eq(player.state_machine.current_state_name, &"Mantling")
	await _run_mantle_to_completion()
	assert_eq(player.state_machine.current_state_name, &"Grounded")
	assert_gt(player.global_position.y, 0.4)


func test_mantle_1_0m_ends_grounded_on_top() -> void:
	var ledge: StaticBody3D = PlayerTestHelpers.make_ledge(3.0, 1.0)
	add_child_autofree(ledge)
	await _approach_and_jump(3.0)
	assert_eq(player.state_machine.current_state_name, &"Mantling")
	await _run_mantle_to_completion()
	assert_eq(player.state_machine.current_state_name, &"Grounded")
	assert_gt(player.global_position.y, 0.9)


func test_mantle_1_9m_ends_grounded_on_top() -> void:
	var ledge: StaticBody3D = PlayerTestHelpers.make_ledge(3.0, 1.9)
	add_child_autofree(ledge)
	await _approach_and_jump(3.0)
	assert_eq(player.state_machine.current_state_name, &"Mantling")
	await _run_mantle_to_completion()
	assert_eq(player.state_machine.current_state_name, &"Grounded")
	assert_gt(player.global_position.y, 1.8)


## Kerb-height ledges (0.2-0.5 m) get a quick, roughly constant step-up
## (ARCHITECTURE.md §4.2's "Level authoring rule"; DESIGN.md §2.1), not the
## 0.6-0.9 s scaled climb.
func test_ledge_0_25m_steps_up_in_about_0_3s_and_ends_grounded() -> void:
	var ledge: StaticBody3D = PlayerTestHelpers.make_ledge(3.0, 0.25)
	add_child_autofree(ledge)
	await _approach_and_jump(3.0)
	assert_eq(player.state_machine.current_state_name, &"Mantling")
	var frames_taken: int = await _run_mantle_to_completion()
	assert_eq(player.state_machine.current_state_name, &"Grounded")
	assert_gt(player.global_position.y, 0.15)
	assert_almost_eq(frames_taken / 60.0, 0.3, 0.15)


func test_ledge_0_4m_steps_up_in_about_0_3s_and_ends_grounded() -> void:
	var ledge: StaticBody3D = PlayerTestHelpers.make_ledge(3.0, 0.4)
	add_child_autofree(ledge)
	await _approach_and_jump(3.0)
	assert_eq(player.state_machine.current_state_name, &"Mantling")
	var frames_taken: int = await _run_mantle_to_completion()
	assert_eq(player.state_machine.current_state_name, &"Grounded")
	assert_gt(player.global_position.y, 0.3)
	assert_almost_eq(frames_taken / 60.0, 0.3, 0.15)


## Below the 0.2 m mantle minimum, there's still no step-up (the "Level
## authoring rule": anything meant to be walked over must be a ramp
## collider), so a 0.15 m obstacle is simply refused.
func test_ledge_0_15m_is_refused() -> void:
	var ledge: StaticBody3D = PlayerTestHelpers.make_ledge(3.0, 0.15)
	add_child_autofree(ledge)
	await _approach_and_jump(3.0, 120)
	assert_ne(player.state_machine.current_state_name, &"Mantling")


func test_ledge_2_0m_is_refused() -> void:
	var ledge: StaticBody3D = PlayerTestHelpers.make_ledge(3.0, 2.0)
	add_child_autofree(ledge)
	await _approach_and_jump(3.0, 120)
	assert_ne(player.state_machine.current_state_name, &"Mantling")


## A window-height sill (0.9 m) with only crouch clearance above it
## (ARCHITECTURE.md §4.2's crouch-fit rule) should mantle the player onto
## the far side already crouched.
func test_window_gap_mantle_ends_crouched() -> void:
	var sill: StaticBody3D = PlayerTestHelpers.make_ledge(3.0, 0.9, 0.4)
	add_child_autofree(sill)
	# Gap spans 0.9-2.5 (1.6 m): enough for the 1.1 m crouch capsule but not
	# the 1.8 m standing one, and clear of LedgeCast's own 2.0 m probe
	# height so it reads the sill's top rather than the lintel's underside.
	var lintel: StaticBody3D = PlayerTestHelpers.make_box_body(Vector3(0.0, 3.15, 3.2), Vector3(3.0, 1.3, 0.4))
	add_child_autofree(lintel)

	await _approach_and_jump(3.0)
	assert_eq(player.state_machine.current_state_name, &"Mantling")
	await _run_mantle_to_completion()
	assert_eq(player.state_machine.current_state_name, &"Grounded")
	assert_true(player.crouched, "mantling through a low gap should end crouched")
