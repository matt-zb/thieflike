class_name Climbable
extends Area3D

## A ladder or pipe the player (and later NPCs) can climb by walking into it
## and pressing forward (ARCHITECTURE.md §4.2). Works both hand-placed in a
## gym and spawned from func_godot's `func_climbable` in M10, so all the
## tuning lives on exported properties, not on how it was placed.

enum Kind { LADDER, PIPE }

@export var kind: Kind = Kind.LADDER

## Climb speed in m/s along this Climbable's local up axis. Pipes climb
## slower than ladders (DESIGN.md §2.1).
@export var ladder_climb_speed: float = 2.2
@export var pipe_climb_speed: float = 1.2

## World-space point the player is released at ("the top") for the
## Climbing state's auto-mantle check. Defaults to the Climbable's own top
## if left at INF.
@export var top_marker_path: NodePath


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		(body as PlayerController).nearby_climbable = self


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController and (body as PlayerController).nearby_climbable == self:
		(body as PlayerController).nearby_climbable = null


func get_climb_speed() -> float:
	return ladder_climb_speed if kind == Kind.LADDER else pipe_climb_speed


## The axis the player moves along while climbing, in world space.
func get_climb_axis() -> Vector3:
	return global_transform.basis.y.normalized()


func get_top_position() -> Vector3:
	if top_marker_path != NodePath():
		var marker: Node3D = get_node_or_null(top_marker_path)
		if marker != null:
			return marker.global_position
	# Fall back to the top of this Area3D's collision shape along its axis.
	var shape_node: CollisionShape3D = _find_collision_shape()
	var half_height: float = 1.0
	if shape_node != null and shape_node.shape is BoxShape3D:
		half_height = (shape_node.shape as BoxShape3D).size.y * 0.5
	return global_position + get_climb_axis() * half_height


func _find_collision_shape() -> CollisionShape3D:
	for child: Node in get_children():
		if child is CollisionShape3D:
			return child
	return null
