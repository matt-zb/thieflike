class_name GaitTable
extends RefCounted

## Small lookup helper mapping a Gait enum value to one of its three tuned
## numbers (DESIGN.md §2.1's table: speed, accel time or decel time). Split
## out of PlayerController purely to keep that file under CLAUDE.md's
## ~300-line guideline; it's a thin wrapper around the same exported
## values, not independently tested math.

static func lookup(
	g: PlayerController.Gait,
	creep_value: float,
	walk_value: float,
	run_value: float
) -> float:
	match g:
		PlayerController.Gait.CREEP:
			return creep_value
		PlayerController.Gait.RUN:
			return run_value
		_:
			return walk_value
