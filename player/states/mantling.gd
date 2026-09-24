extends State

## Climbing over a ledge: input is locked and the body is moved along a
## fixed two-segment path (straight up to the ledge's height, then forward
## onto it) over a duration scaled by the ledge's height
## (ARCHITECTURE.md §4.2, DESIGN.md §2.1). Position is driven directly
## rather than through move_and_slide, since this is a scripted animation
## of the body, not a physics response.

var _start_position: Vector3
var _mid_position: Vector3
var _target_position: Vector3
var _end_crouched: bool = false

var _duration: float = 0.6
var _up_duration: float = 0.24
var _elapsed: float = 0.0


func enter(msg: Dictionary) -> void:
	var player: PlayerController = actor as PlayerController
	if player == null:
		return

	player.velocity = Vector3.ZERO
	_start_position = player.global_position
	_target_position = msg.get("target_position", _start_position) as Vector3
	_end_crouched = msg.get("end_crouched", false) as bool
	var height: float = msg.get("height", player.mantle_min_height) as float

	_duration = MantleMath.duration_for_height(
		height, player.mantle_step_up_max_height, player.mantle_max_height,
		player.step_up_duration, player.mantle_min_duration, player.mantle_max_duration
	)
	# Rise first, then carry forward onto the ledge; ~40% of the total time
	# is spent rising.
	_up_duration = _duration * 0.4
	_mid_position = Vector3(_start_position.x, _target_position.y, _start_position.z)
	_elapsed = 0.0


func physics_update(delta: float) -> void:
	var player: PlayerController = actor as PlayerController
	if player == null:
		return

	_elapsed += delta
	var forward_duration: float = maxf(_duration - _up_duration, 0.001)

	var pos: Vector3
	if _elapsed <= _up_duration:
		var t: float = clampf(_elapsed / maxf(_up_duration, 0.001), 0.0, 1.0)
		pos = _start_position.lerp(_mid_position, t)
	else:
		var t: float = clampf((_elapsed - _up_duration) / forward_duration, 0.0, 1.0)
		pos = _mid_position.lerp(_target_position, t)

	player.global_position = pos

	if _elapsed >= _duration:
		player.global_position = _target_position
		player.velocity = Vector3.ZERO
		if _end_crouched:
			player.set_crouched(true)
		transition_requested.emit(&"Grounded", {})
