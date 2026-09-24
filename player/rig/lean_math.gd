class_name LeanMath
extends RefCounted

## Pure helper that clamps the lean target by how much clearance the
## LeanClearance shape cast reports, so a wall never lets the camera clip
## through it (DESIGN.md §2.1, ARCHITECTURE.md §4.3).


## `target` is the desired lean amount in -1..1 (from held input).
## `clearance_fraction` is the LeanClearance ShapeCast3D's hit fraction in
## the lean's direction: 1.0 means the full lean distance is clear, 0.0
## means a wall is immediately at the pivot. `has_hit` mirrors
## ShapeCast3D.is_colliding() for the cast aimed at `target`'s side; when
## there's no hit at all the cast reports no collision and the raw target
## is returned unclamped.
static func clamp_lean(target: float, clearance_fraction: float, has_hit: bool) -> float:
	if not has_hit:
		return target
	var allowed: float = clampf(clearance_fraction, 0.0, 1.0)
	return clampf(target, -allowed, allowed)
