class_name MantleProbe
extends RefCounted

## Shared ledge-probing logic used by both Grounded and Airborne (a jump can
## catch a ledge while rising, and a fall can catch one on the way down —
## ARCHITECTURE.md §4.2). Not itself pure (it reads ShapeCast3D results and
## queries the physics space), so it isn't unit-tested; MantleMath (the
## acceptance/duration math it calls into) is.


## Casts MantleProbe/WallCast forward for a wall, then MantleProbe/LedgeCast
## down from above it for a ledge top. Returns {} if there's no acceptable
## candidate, or a dictionary describing the target for the Mantling state.
static func probe_ledge(player: PlayerController) -> Dictionary:
	var wall_cast: ShapeCast3D = player.wall_cast
	wall_cast.force_shapecast_update()
	if not wall_cast.is_colliding():
		return {}
	var wall_point: Vector3 = wall_cast.get_collision_point(0)
	var wall_normal: Vector3 = wall_cast.get_collision_normal(0)

	var ledge_cast: ShapeCast3D = player.ledge_cast
	ledge_cast.force_shapecast_update()
	if not ledge_cast.is_colliding():
		return {}
	var ledge_top: Vector3 = ledge_cast.get_collision_point(0)

	# Measured from the ground under the player, not the player's current
	# altitude: otherwise a normal jump next to a too-tall wall can drift
	# into the acceptable range mid-air as the player rises alongside it.
	var ground_y: float = _ground_reference_y(player)
	var height: float = ledge_top.y - ground_y
	# ShapeCast3D results carry a little geometric noise (safe-fraction
	# rounding, collision margins); a ~2 cm slack keeps an exact 0.2 m or
	# 1.9 m ledge from being spuriously refused.
	var slack: float = 0.02
	if not MantleMath.is_height_acceptable(height, player.mantle_min_height - slack, player.mantle_max_height + slack):
		return {}

	# Step just past the ledge's front edge, onto its top.
	var target_xz: Vector3 = wall_point - wall_normal * 0.35
	var target_position: Vector3 = Vector3(target_xz.x, ledge_top.y, target_xz.z)

	# Lift the clearance probe a hair above the ledge's exact top surface:
	# a capsule resting flush on it can register as overlapping due to the
	# physics engine's own collision margin, which would reject every
	# mantle at its own landing spot.
	var clearance_probe_position: Vector3 = target_position + Vector3(0.0, 0.03, 0.0)
	var end_crouched: bool = false
	if _capsule_overlaps(player, clearance_probe_position, player.stand_height):
		if _capsule_overlaps(player, clearance_probe_position, player.crouch_height):
			return {}
		end_crouched = true

	return {
		"height": height,
		"target_position": target_position,
		"end_crouched": end_crouched,
	}


## The ground surface directly beneath the player, used as the reference
## point for ledge height so a jump doesn't retarget the same ledge as
## progressively "shorter" while the player rises alongside it.
static func _ground_reference_y(player: PlayerController) -> float:
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0.0, 0.5, 0.0),
		player.global_position + Vector3(0.0, -3.0, 0.0)
	)
	params.collision_mask = 1  # WORLD
	params.exclude = [player.get_rid()]
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var result: Dictionary = space_state.intersect_ray(params)
	if result.has("position"):
		return (result["position"] as Vector3).y
	return player.global_position.y


## Checks whether a capsule of the given height, centred above `position`,
## is blocked by world geometry — the "top is checked first with the
## standing capsule, then with the crouched capsule" rule.
static func _capsule_overlaps(player: PlayerController, position: Vector3, height: float) -> bool:
	var collider_shape: CapsuleShape3D = player.collider.shape as CapsuleShape3D
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = collider_shape.radius if collider_shape != null else 0.35
	shape.height = height

	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), position + Vector3(0.0, height * 0.5, 0.0))
	params.collision_mask = 1  # WORLD
	params.exclude = [player.get_rid()]

	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	return space_state.intersect_shape(params, 1).size() > 0
