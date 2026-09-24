class_name PlayerIntent
extends RefCounted

## The player's input for one physics frame, decoupled from the Input
## singleton (ARCHITECTURE.md §4.2). States read only this object, never
## `Input` directly, so headless tests can drive the player by constructing
## a PlayerIntent and stepping physics, with no window focus or input
## injection required.

## Movement wish direction in the XZ plane, local to the player's facing:
## x = strafe (right positive), y = forward (forward positive). Not
## normalized by the reader; consumers normalize if length > 1.
var wish_dir: Vector2 = Vector2.ZERO

var run: bool = false
var creep: bool = false

## True for exactly the physics frame the crouch key was pressed. Crouch
## itself is a toggled flag owned by PlayerController (ARCHITECTURE.md
## §4.2), not by the intent.
var crouch_toggled: bool = false

## True for exactly the physics frame jump was pressed.
var jump_pressed: bool = false

## -1 (left) .. 1 (right). Held, not edge-triggered.
var lean: float = 0.0

## Accumulated mouse motion since the last physics frame, in the input's
## raw pixel units (PlayerController applies sensitivity).
var look_delta: Vector2 = Vector2.ZERO
