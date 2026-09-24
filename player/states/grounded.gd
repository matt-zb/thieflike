extends State

## Walking, running, creeping and crouching on solid ground: gait selection,
## acceleration toward the target velocity via MovementMath, jump, and the
## entries into Mantling and Climbing (ARCHITECTURE.md §4.2).


func physics_update(delta: float) -> void:
	var player: PlayerController = actor as PlayerController
	if player == null:
		return

	if player.intent.crouch_toggled:
		player.set_crouched(not player.crouched)

	player.set_gait(player.resolve_gait())

	var wish: Vector3 = player.wish_world_dir()
	var wish_xz: Vector2 = Vector2(wish.x, wish.z)
	var new_h: Vector2 = MovementMath.horizontal_move(
		player.horizontal_velocity(), wish_xz, player.target_speed(),
		player.accel_rate(), player.decel_rate(), delta
	)
	player.set_horizontal_velocity(new_h)
	# Small constant downward speed, not full gravity: keeps the character
	# glued to the floor (and to sloped stair ramps) between physics ticks
	# without accumulating into a real fall while grounded.
	player.velocity.y = -0.5

	if player.intent.jump_pressed:
		var ledge: Dictionary = MantleProbe.probe_ledge(player)
		if not ledge.is_empty():
			transition_requested.emit(&"Mantling", ledge)
			return
		player.velocity.y = MovementMath.jump_speed_for_height(player.jump_height, player.gravity)
		player.move_and_slide()
		transition_requested.emit(&"Airborne", {})
		return

	if player.nearby_climbable != null and wish_xz.length() > 0.1:
		player.current_climbable = player.nearby_climbable
		transition_requested.emit(&"Climbing", {})
		return

	player.move_and_slide()

	if not player.is_on_floor():
		transition_requested.emit(&"Airborne", {})
