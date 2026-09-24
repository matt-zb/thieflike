class_name StateMachine
extends Node

## Generic state machine: drives whichever child `State` node is current.
## Shared by the player's movement states and (later) the NPC brain
## (ARCHITECTURE.md §3.1, §4.2, §10.3).
##
## States are plain children of this node. The machine discovers them in
## _ready(), keyed by node name, so `initial_state` and every
## `transition_requested(to, msg)` refer to a state by its child name
## (for example &"Grounded").

signal state_changed(from: StringName, to: StringName)

@export var initial_state: StringName = &""

## Who the states act on. Left null and resolved to `get_parent()` in
## _ready() for the normal case (a State's parent StateMachine's parent is
## the actor); tests may set this to a stub body before the machine enters
## the tree, so states can be exercised without a real PlayerController.
var actor: Node

var current_state: State
var current_state_name: StringName = &""

var _states: Dictionary = {}


func _ready() -> void:
	if actor == null:
		actor = get_parent()
	for child: Node in get_children():
		if child is State:
			_states[StringName(child.name)] = child
			child.actor = actor
			child.transition_requested.connect(_on_transition_requested)
	if initial_state != &"" and _states.has(initial_state):
		transition_to(initial_state, {})


## Advances the current state by one physics frame. Callers (PlayerController,
## and later the NPC Brain) call this explicitly from their own
## _physics_process rather than relying on Godot's automatic per-node
## process order, so the sequence "read input -> tick state -> move_and_slide"
## stays deterministic and easy to drive from tests.
func tick(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)


## Look up a state by name without transitioning to it. Used by states that
## need to read a sibling's exported tuning (for example Airborne reading
## Grounded's mantle height limits).
func get_state(name: StringName) -> State:
	return _states.get(name)


func transition_to(to: StringName, msg: Dictionary = {}) -> void:
	if not _states.has(to):
		push_error("StateMachine: unknown state '%s'" % to)
		return
	var from_name: StringName = current_state_name
	if current_state != null:
		current_state.exit()
	current_state = _states[to]
	current_state_name = to
	current_state.enter(msg)
	state_changed.emit(from_name, to)


func _on_transition_requested(to: StringName, msg: Dictionary) -> void:
	transition_to(to, msg)
