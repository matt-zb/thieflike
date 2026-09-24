extends State

## Moving up or down a ladder or pipe (ARCHITECTURE.md §4.2). Forward/back
## input maps to up/down along the Climbable's axis regardless of facing.
## Jump detaches into Airborne; reaching the top hands off to Mantling for
## a consistent "climb over the edge" motion.


func enter(_msg: Dictionary) -> void:
	var player: PlayerController = actor as PlayerController
	if player == null or player.current_climbable == null:
		return
	# Snap onto the climbable's vertical line so climbing doesn't drift.
	var climbable: Climbable = player.current_climbable
	var pos: Vector3 = player.global_position
	player.global_position = Vector3(climbable.global_position.x, pos.y, climbable.global_position.z)
	player.velocity = Vector3.ZERO


func exit() -> void:
	var player: PlayerController = actor as PlayerController
	if player != null:
		player.current_climbable = null


func physics_update(_delta: float) -> void:
	var player: PlayerController = actor as PlayerController
	if player == null:
		return
	var climbable: Climbable = player.current_climbable
	if climbable == null:
		transition_requested.emit(&"Grounded", {})
		return

	if player.intent.jump_pressed:
		var axis: Vector3 = climbable.get_climb_axis()
		player.velocity = axis * player.climb_detach_speed * 0.5
		transition_requested.emit(&"Airborne", {})
		return

	var axis: Vector3 = climbable.get_climb_axis()
	var climb_speed: float = climbable.get_climb_speed()
	var input_amount: float = player.intent.wish_dir.y
	player.velocity = axis * input_amount * climb_speed
	player.move_and_slide()

	var top: Vector3 = climbable.get_top_position()
	var reached_top: bool = (player.global_position - top).dot(axis) >= -0.15
	if input_amount > 0.0 and reached_top:
		var height: float = clampf(
			(top - player.global_position).dot(axis),
			player.mantle_min_height, player.mantle_max_height
		)
		player.velocity = Vector3.ZERO
		transition_requested.emit(&"Mantling", {
			"height": height,
			"target_position": top,
			"end_crouched": false,
		})
