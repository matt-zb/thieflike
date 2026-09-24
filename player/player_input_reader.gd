class_name PlayerInputReader
extends Node

## Fills a PlayerIntent from the Input Map every physics frame. This is the
## only place that touches `Input` for movement; everything downstream
## (states, MovementMath) reads the intent instead (ARCHITECTURE.md §4.2).

## When false, `poll()` is a no-op, so tests (and, in the future, cutscenes)
## can drive `intent` directly without a real input device overwriting it.
@export var enabled: bool = true

var intent: PlayerIntent = PlayerIntent.new()

var _accumulated_look: Vector2 = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if enabled and event is InputEventMouseMotion:
		_accumulated_look += (event as InputEventMouseMotion).relative


## Called explicitly by PlayerController once per physics frame
## (StateMachine and PlayerInputReader deliberately have no automatic
## _physics_process of their own — see StateMachine.tick).
func poll() -> void:
	if not enabled:
		return
	intent.wish_dir = Vector2(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"move_back", &"move_forward")
	)
	intent.run = Input.is_action_pressed(&"run")
	intent.creep = Input.is_action_pressed(&"creep")
	intent.crouch_toggled = Input.is_action_just_pressed(&"crouch")
	intent.jump_pressed = Input.is_action_just_pressed(&"jump")

	var lean_axis: float = Input.get_axis(&"lean_left", &"lean_right")
	intent.lean = lean_axis

	intent.look_delta = _accumulated_look
	_accumulated_look = Vector2.ZERO
