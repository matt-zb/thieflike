extends State

## Falling and rising off the ground: gravity, capped air control, catching
## a mantle on the way up or down, and landing (ARCHITECTURE.md §4.2).


func physics_update(delta: float) -> void:
	var player: PlayerController = actor as PlayerController
	if player == null:
		return

	player.velocity.y -= player.gravity * delta

	var wish: Vector3 = player.wish_world_dir()
	var wish_xz: Vector2 = Vector2(wish.x, wish.z)
	var new_h: Vector2 = MovementMath.air_move(
		player.horizontal_velocity(), wish_xz, player.target_speed(),
		player.accel_rate(), player.air_control_pct, delta
	)
	player.set_horizontal_velocity(new_h)

	if player.intent.jump_pressed:
		var ledge: Dictionary = MantleProbe.probe_ledge(player)
		if not ledge.is_empty():
			transition_requested.emit(&"Mantling", ledge)
			return

	var fall_speed_before_impact: float = max(-player.velocity.y, 0.0)
	player.move_and_slide()

	if player.is_on_floor():
		player.request_land(fall_speed_before_impact)
		transition_requested.emit(&"Grounded", {})
