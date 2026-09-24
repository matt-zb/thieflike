class_name State
extends Node

## Base class for a single state in a StateMachine. Shared between the
## player's movement states and (later) the NPC brain's states, so it lives
## in common/ rather than player/ (CLAUDE.md: keep reusable math and
## behaviour out of specific systems).
##
## Concrete states override enter/exit/physics_update/handle_input and
## request transitions through `transition_requested` rather than switching
## state directly, so the owning StateMachine stays the single source of
## truth for "what state am I in".

signal transition_requested(to: StringName, msg: Dictionary)

## The node this state drives (a PlayerController, or later an Npc). Set by
## the owning StateMachine before any state's enter() runs, so states never
## need a relative get_node() to find their actor.
var actor: Node


## Called once when the state machine switches into this state.
## `msg` carries whatever context the previous state or caller wants to pass
## along (for example the ledge target for Mantling).
func enter(_msg: Dictionary) -> void:
	pass


## Called once when the state machine switches away from this state.
func exit() -> void:
	pass


## Called every physics frame while this state is active.
func physics_update(_delta: float) -> void:
	pass


## Called on unhandled input while this state is active.
func handle_input(_event: InputEvent) -> void:
	pass
