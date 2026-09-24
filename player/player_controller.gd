class_name PlayerController
extends CharacterBody3D

## The player's body (ARCHITECTURE.md §4.1, §4.2). Owns tuning exports,
## the camera rig pivots, and the small set of things every movement state
## shares (gravity, crouch blend, lean, look). Movement logic itself lives
## in the states under player/states/ and in MovementMath; this node stays
## thin and wires dependencies for them.

signal gait_changed(gait: Gait)
signal crouch_changed(on: bool)
signal foot_planted(foot: int)
signal landed(fall_speed: float)

enum Gait { CREEP, WALK, RUN }
enum Foot { LEFT, RIGHT }

@export_group("Movement")
@export var creep_speed: float = 1.0
@export var creep_accel_time: float = 0.20
@export var creep_decel_time: float = 0.12
@export var walk_speed: float = 2.2
@export var walk_accel_time: float = 0.30
@export var walk_decel_time: float = 0.20
@export var run_speed: float = 4.8
@export var run_accel_time: float = 0.55
@export var run_decel_time: float = 0.40
@export var crouch_speed_mult: float = 0.55
@export var air_control_pct: float = 0.15
@export var jump_height: float = 0.45
@export var gravity: float = 20.0

@export_group("Crouch")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.1
@export var stand_eye_height: float = 1.65
@export var crouch_eye_height: float = 1.05
## How fast the crouch blend (0..1) moves toward its target, in units/sec.
@export var crouch_blend_speed: float = 6.0

@export_group("Lean")
@export var lean_max_offset: float = 0.45
@export var lean_max_roll_deg: float = 12.0
@export var lean_blend_speed: float = 5.0

@export_group("Mantle")
@export var mantle_min_height: float = 0.2
## Ledges at or below this height (kerbs, thresholds) get the quick
## `step_up_duration` step-up instead of the 0.6-0.9 s scaled climb
## (DESIGN.md §2.1).
@export var mantle_step_up_max_height: float = 0.5
@export var mantle_max_height: float = 1.9
@export var step_up_duration: float = 0.3
@export var mantle_min_duration: float = 0.6
@export var mantle_max_duration: float = 0.9
@export var mantle_wall_distance: float = 0.6

@export_group("Climb")
@export var climb_detach_speed: float = 3.0

@export_group("Look")
@export var mouse_sensitivity: float = 0.0025
@export var pitch_limit_deg: float = 85.0

@onready var collider: CollisionShape3D = $Collider
@onready var stand_check: ShapeCast3D = $StandCheck
@onready var wall_cast: ShapeCast3D = $MantleProbe/WallCast
@onready var ledge_cast: ShapeCast3D = $MantleProbe/LedgeCast
@onready var state_machine: StateMachine = $StateMachine
@onready var rig: Node3D = $Rig
@onready var crouch_pivot: Node3D = $Rig/CrouchPivot
@onready var lean_pivot: Node3D = $Rig/CrouchPivot/LeanPivot
@onready var bob_pivot: Node3D = $Rig/CrouchPivot/LeanPivot/BobPivot
@onready var camera: Camera3D = $Rig/CrouchPivot/LeanPivot/BobPivot/Camera3D
@onready var lean_clearance: ShapeCast3D = $Rig/CrouchPivot/LeanPivot/BobPivot/Camera3D/LeanClearance
@onready var rig_animator: AnimationTree = $RigAnimator
@onready var input_reader: PlayerInputReader = $PlayerInputReader

var intent: PlayerIntent = PlayerIntent.new()

var gait: Gait = Gait.WALK
var crouched: bool = false
var _crouch_blend: float = 0.0
var _lean_blend: float = 0.0
var camera_pitch: float = 0.0

## The Climbable the player is currently overlapping, kept up to date by
## Climbable's own body_entered/body_exited (Grounded/Airborne read this to
## decide whether "forward" means "start climbing").
var nearby_climbable: Climbable = null

## The Climbable actually being climbed, set when the Climbing state is
## entered.
var current_climbable: Climbable = null


func _ready() -> void:
	input_reader.intent = intent
	if collider.shape is CapsuleShape3D:
		(collider.shape as CapsuleShape3D).height = stand_height
	_crouch_blend = 0.0
	if rig_animator != null and rig_animator.active:
		# The two Add2 nodes exist only to run independent animations (crouch,
		# lean, bob) side by side without one fading the other out, so they
		# stay pinned fully open; see tools/build_rig_animations.gd.
		rig_animator.set("parameters/add_lean/add_amount", 1.0)
		rig_animator.set("parameters/add_bob/add_amount", 1.0)


func _physics_process(delta: float) -> void:
	input_reader.poll()
	_apply_look()
	_update_crouch_blend(delta)
	_update_lean(delta)
	state_machine.tick(delta)
	_update_rig_animator()


func _unhandled_input(event: InputEvent) -> void:
	state_machine.input(event)


## -- Look -----------------------------------------------------------------

func _apply_look() -> void:
	if intent.look_delta == Vector2.ZERO:
		return
	rotate_y(-intent.look_delta.x * mouse_sensitivity)
	camera_pitch = clampf(
		camera_pitch - intent.look_delta.y * mouse_sensitivity,
		deg_to_rad(-pitch_limit_deg),
		deg_to_rad(pitch_limit_deg)
	)
	camera.rotation.x = camera_pitch


## -- Crouch -----------------------------------------------------------------

## Requests a crouch state change. Refused (returns false) if trying to
## stand up under something too low (StandCheck), per ARCHITECTURE.md §4.2.
func set_crouched(value: bool) -> bool:
	if value == crouched:
		return true
	if not value and _stand_blocked():
		return false
	crouched = value
	_resize_collider()
	crouch_changed.emit(crouched)
	return true


func _stand_blocked() -> bool:
	stand_check.force_shapecast_update()
	return stand_check.is_colliding()


func _resize_collider() -> void:
	if collider.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collider.shape as CapsuleShape3D
		var new_height: float = crouch_height if crouched else stand_height
		# Keep feet planted: shift the collider up/down by half the height
		# delta so the capsule's bottom stays put while its centre moves.
		var delta_height: float = new_height - capsule.height
		capsule.height = new_height
		collider.position.y += delta_height * 0.5


func _update_crouch_blend(delta: float) -> void:
	var target: float = 1.0 if crouched else 0.0
	_crouch_blend = move_toward(_crouch_blend, target, crouch_blend_speed * delta)


## -- Lean -----------------------------------------------------------------

## Only ever writes the AnimationTree's lean blend parameter, never the
## pivot's transform (ARCHITECTURE.md §4.3): CrouchPivot/LeanPivot's
## position and roll come entirely from the baked "left"/"centre"/"right"
## lean animations blended by RigAnimator.
func _update_lean(delta: float) -> void:
	var target: float = clampf(intent.lean, -1.0, 1.0)
	if target != 0.0:
		lean_clearance.target_position = Vector3(target * (lean_max_offset + 0.2), 0.0, 0.0)
		lean_clearance.force_shapecast_update()
		var hit: bool = lean_clearance.is_colliding()
		var frac: float = lean_clearance.get_closest_collision_safe_fraction()
		target = LeanMath.clamp_lean(target, frac, hit)
	_lean_blend = move_toward(_lean_blend, target, lean_blend_speed * delta)


## -- Rig animator (blend parameters only; see ARCHITECTURE.md §4.3) --------

func _update_rig_animator() -> void:
	if rig_animator == null or not rig_animator.active:
		return
	rig_animator.set("parameters/crouch/blend_amount", _crouch_blend)
	rig_animator.set("parameters/lean/blend_position", _lean_blend)
	var speed: float = Vector2(velocity.x, velocity.z).length()
	rig_animator.set("parameters/bob/blend_position", speed)
	# Keeps step cadence matched to gait rather than to the bob cycle baked
	# at run speed (ARCHITECTURE.md §4.3).
	var timescale: float = clampf(speed / maxf(walk_speed, 0.01), 0.2, 3.0)
	rig_animator.set("parameters/bob_timescale/scale", timescale)


## Called by a method-call track on the bob animation at each foot-plant
## keyframe (ARCHITECTURE.md §4.3).
func plant_foot(foot: int) -> void:
	foot_planted.emit(foot)


func request_land(fall_speed: float) -> void:
	if rig_animator != null and rig_animator.active:
		rig_animator.set("parameters/land/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	landed.emit(fall_speed)


## -- Gait --------------------------------------------------------------

## Picks the active gait from held input. Creep takes priority over run
## when both are held, since crouched/stealthy movement is the more
## deliberate choice (undocumented in DESIGN.md; noted here as the concrete
## tie-break).
func resolve_gait() -> Gait:
	if intent.creep:
		return Gait.CREEP
	if intent.run:
		return Gait.RUN
	return Gait.WALK


func set_gait(value: Gait) -> void:
	if value == gait:
		return
	gait = value
	gait_changed.emit(gait)


func gait_speed(g: Gait) -> float:
	return GaitTable.lookup(g, creep_speed, walk_speed, run_speed)


func gait_accel_time(g: Gait) -> float:
	return GaitTable.lookup(g, creep_accel_time, walk_accel_time, run_accel_time)


func gait_decel_time(g: Gait) -> float:
	return GaitTable.lookup(g, creep_decel_time, walk_decel_time, run_decel_time)


## Current target ground speed: the gait's base speed, further scaled down
## while crouched (DESIGN.md §2.1: "Crouch: x0.55 of gait").
func target_speed() -> float:
	var base: float = gait_speed(gait)
	return base * crouch_speed_mult if crouched else base


func accel_rate() -> float:
	return MovementMath.rate_from_time(gait_speed(gait), gait_accel_time(gait))


func decel_rate() -> float:
	return MovementMath.rate_from_time(gait_speed(gait), gait_decel_time(gait))


## -- Wish direction in world space --------------------------------------

## Converts the intent's local wish_dir (x = strafe, y = forward) into a
## world-space XZ vector using the body's current facing.
func wish_world_dir() -> Vector3:
	var basis: Basis = global_transform.basis
	var forward: Vector3 = -basis.z
	var right: Vector3 = basis.x
	var dir: Vector3 = forward * intent.wish_dir.y + right * intent.wish_dir.x
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir


func horizontal_velocity() -> Vector2:
	return Vector2(velocity.x, velocity.z)


func set_horizontal_velocity(v: Vector2) -> void:
	velocity.x = v.x
	velocity.z = v.y


## Body-space forward, for the mantle/climb probes.
func facing_forward() -> Vector3:
	return -global_transform.basis.z
