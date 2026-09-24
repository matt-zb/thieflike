class_name PlayerTestHelpers
extends RefCounted

## Builds the small physics fixtures the M1 integration tests drop a real
## player.tscn instance into (a floor, a wall with a ledge, a low ceiling,
## a ladder), per MILESTONES.md M1's instruction to prove movement with
## GUT tests that step real physics rather than mocks.
##
## Nodes are only constructed here; callers add them to the tree themselves
## (usually via GutTest.add_child_autofree) so ownership/freeing stays with
## the test.

const PLAYER_SCENE_PATH: String = "res://player/player.tscn"


## A flat StaticBody3D floor centred at `center`, `size` metres in each
## dimension, top surface at `center.y + size.y / 2`.
static func make_box_body(center: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1  # WORLD
	body.collision_mask = 0
	body.position = center
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	return body


## A flat floor whose top surface sits at y = 0.
static func make_floor(half_extent: float = 25.0) -> StaticBody3D:
	return make_box_body(Vector3(0.0, -0.5, 0.0), Vector3(half_extent * 2.0, 1.0, half_extent * 2.0))


## A wall/ledge block whose front face is at `front_z` and whose top is at
## `height` above the floor (y = 0). The player approaches from -Z.
static func make_ledge(front_z: float, height: float, depth: float = 2.0, width: float = 3.0) -> StaticBody3D:
	var center_z: float = front_z + depth * 0.5
	return make_box_body(Vector3(0.0, height * 0.5, center_z), Vector3(width, height, depth))


## A ceiling slab; combined with make_floor, forms a crawlspace of clear
## height `clear_height`.
static func make_ceiling(clear_height: float, z: float, width: float = 3.0, depth: float = 3.0) -> StaticBody3D:
	return make_box_body(Vector3(0.0, clear_height + 0.1, z), Vector3(width, 0.2, depth))


## Instantiates player.tscn and returns it un-parented. @onready vars
## (including input_reader) aren't valid until the node enters the tree, so
## callers must add it to the tree (usually add_child_autofree) before
## touching anything but the returned reference itself; disable
## `player.input_reader.enabled` right after, since tests drive `intent`
## directly rather than through real input.
static func make_player() -> PlayerController:
	var scene: PackedScene = load(PLAYER_SCENE_PATH)
	return scene.instantiate()


## A vertical Climbable (ladder or pipe) from y=0 to y=top_y, with a top
## platform and TopMarker the player is released onto.
static func make_climbable(kind: int, top_y: float, z: float = 0.0) -> Area3D:
	var climbable: Climbable = Climbable.new()
	climbable.kind = kind
	climbable.collision_layer = 0
	climbable.collision_mask = 2  # PLAYER
	climbable.position = Vector3(0.0, top_y * 0.5, z)

	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.6, top_y, 0.6)
	shape_node.shape = shape
	climbable.add_child(shape_node)

	# Offset well clear of the climbing shaft (which is 0.6 m wide): a
	# platform with solid geometry directly overhead would clip the
	## standing capsule's head long before the player's feet reach the
	# logical "near the top" trigger height.
	var top_marker: Marker3D = Marker3D.new()
	top_marker.name = "TopMarker"
	top_marker.position = Vector3(0.0, top_y * 0.5 + 0.3, -1.2)
	climbable.add_child(top_marker)
	climbable.top_marker_path = NodePath("TopMarker")

	return climbable
