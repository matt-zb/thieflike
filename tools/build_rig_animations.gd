extends SceneTree

## Headless tool: builds the RigAnimator's AnimationLibrary and blend-tree
## resources and saves them as committed .tres files (ARCHITECTURE.md §4.3).
## Hand-authoring these as raw .tres text is error-prone, so this script
## builds them with the real Animation/AnimationNode API and saves the
## result. Run with:
##   godot --headless -s tools/build_rig_animations.gd
##
## Track paths are relative to the RigAnimator's AnimationPlayer's
## `root_node`, which player.tscn sets to the Player's `Rig` node.

const OUT_LIBRARY_PATH: String = "res://player/rig/rig_animations.tres"
const OUT_TREE_PATH: String = "res://player/rig/rig_animation_tree.tres"

# Defaults mirrored from PlayerController's exports (DESIGN.md §2.1); the
# baked poses use these literal values, and PlayerController's own exports
# remain the tunable source of truth for gameplay (crouch height, capsule
# size, mantle timing, movement speeds).
const STAND_EYE_HEIGHT: float = 1.65
const CROUCH_EYE_HEIGHT: float = 1.05
const LEAN_OFFSET: float = 0.45
const LEAN_ROLL_DEG: float = 12.0
const RUN_SPEED: float = 4.8
const BOB_CYCLE_LENGTH: float = 0.6
const BOB_HEIGHT: float = 0.035


func _init() -> void:
	var library: AnimationLibrary = _build_library()
	var err: int = ResourceSaver.save(library, OUT_LIBRARY_PATH)
	if err != OK:
		push_error("Failed to save %s (error %d)" % [OUT_LIBRARY_PATH, err])
		quit(1)
		return

	var tree_root: AnimationNodeBlendTree = _build_tree()
	err = ResourceSaver.save(tree_root, OUT_TREE_PATH)
	if err != OK:
		push_error("Failed to save %s (error %d)" % [OUT_TREE_PATH, err])
		quit(1)
		return

	print("Wrote %s and %s" % [OUT_LIBRARY_PATH, OUT_TREE_PATH])
	quit(0)


func _build_library() -> AnimationLibrary:
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.add_animation(&"crouch_stand", _pose_animation("CrouchPivot:position", Vector3(0.0, STAND_EYE_HEIGHT, 0.0)))
	lib.add_animation(&"crouch_crouched", _pose_animation("CrouchPivot:position", Vector3(0.0, CROUCH_EYE_HEIGHT, 0.0)))

	lib.add_animation(&"lean_left", _lean_animation(-1.0))
	lib.add_animation(&"lean_center", _lean_animation(0.0))
	lib.add_animation(&"lean_right", _lean_animation(1.0))

	lib.add_animation(&"bob_idle", _pose_animation("CrouchPivot/LeanPivot/BobPivot:position", Vector3.ZERO))
	lib.add_animation(&"bob_cycle", _bob_cycle_animation())

	lib.add_animation(&"land_dip", _land_dip_animation())
	return lib


func _pose_animation(track_path: String, value: Vector3) -> Animation:
	var anim: Animation = Animation.new()
	anim.length = 0.1
	var track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(track_path))
	anim.track_insert_key(track, 0.0, value)
	return anim


func _lean_animation(side: float) -> Animation:
	var anim: Animation = Animation.new()
	anim.length = 0.1
	var pos_track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pos_track, NodePath("CrouchPivot/LeanPivot:position"))
	anim.track_insert_key(pos_track, 0.0, Vector3(side * LEAN_OFFSET, 0.0, 0.0))

	var rot_track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rot_track, NodePath("CrouchPivot/LeanPivot:rotation"))
	anim.track_insert_key(rot_track, 0.0, Vector3(0.0, 0.0, deg_to_rad(-LEAN_ROLL_DEG) * side))
	return anim


## A looping bob cycle with method-call foot-plant keys at the quarter and
## three-quarter points, so `plant_foot(LEFT)` / `plant_foot(RIGHT)` fire
## once each per stride (ARCHITECTURE.md §4.3). Blended in via a
## BlendSpace1D point at `RUN_SPEED`, and sped up or slowed by
## `bob_timescale` for slower gaits (PlayerController._update_rig_animator).
func _bob_cycle_animation() -> Animation:
	var anim: Animation = Animation.new()
	anim.length = BOB_CYCLE_LENGTH
	anim.loop_mode = Animation.LOOP_LINEAR

	var track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("CrouchPivot/LeanPivot/BobPivot:position"))
	anim.track_insert_key(track, 0.0, Vector3.ZERO)
	anim.track_insert_key(track, BOB_CYCLE_LENGTH * 0.25, Vector3(0.0, BOB_HEIGHT, 0.0))
	anim.track_insert_key(track, BOB_CYCLE_LENGTH * 0.5, Vector3.ZERO)
	anim.track_insert_key(track, BOB_CYCLE_LENGTH * 0.75, Vector3(0.0, BOB_HEIGHT, 0.0))
	anim.track_insert_key(track, BOB_CYCLE_LENGTH, Vector3.ZERO)

	var method_track: int = anim.add_track(Animation.TYPE_METHOD)
	# Relative to root_node (Rig); ".." from Rig reaches the Player.
	anim.track_set_path(method_track, NodePath(".."))
	anim.track_insert_key(method_track, BOB_CYCLE_LENGTH * 0.25, {"method": "plant_foot", "args": [0]})
	anim.track_insert_key(method_track, BOB_CYCLE_LENGTH * 0.75, {"method": "plant_foot", "args": [1]})
	return anim


func _land_dip_animation() -> Animation:
	var anim: Animation = Animation.new()
	anim.length = 0.3
	var track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("CrouchPivot/LeanPivot/BobPivot:position"))
	anim.track_insert_key(track, 0.0, Vector3.ZERO)
	anim.track_insert_key(track, 0.08, Vector3(0.0, -0.08, 0.0))
	anim.track_insert_key(track, 0.3, Vector3.ZERO)
	return anim


func _build_tree() -> AnimationNodeBlendTree:
	var tree: AnimationNodeBlendTree = AnimationNodeBlendTree.new()

	var anim_crouch_stand: AnimationNodeAnimation = AnimationNodeAnimation.new()
	anim_crouch_stand.animation = &"crouch_stand"
	var anim_crouch_crouched: AnimationNodeAnimation = AnimationNodeAnimation.new()
	anim_crouch_crouched.animation = &"crouch_crouched"
	tree.add_node(&"anim_crouch_stand", anim_crouch_stand, Vector2(-400, -200))
	tree.add_node(&"anim_crouch_crouched", anim_crouch_crouched, Vector2(-400, -120))

	var crouch: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	tree.add_node(&"crouch", crouch, Vector2(-200, -160))
	tree.connect_node(&"crouch", 0, &"anim_crouch_stand")
	tree.connect_node(&"crouch", 1, &"anim_crouch_crouched")

	var anim_lean_left: AnimationNodeAnimation = AnimationNodeAnimation.new()
	anim_lean_left.animation = &"lean_left"
	var anim_lean_center: AnimationNodeAnimation = AnimationNodeAnimation.new()
	anim_lean_center.animation = &"lean_center"
	var anim_lean_right: AnimationNodeAnimation = AnimationNodeAnimation.new()
	anim_lean_right.animation = &"lean_right"

	var lean: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
	lean.min_space = -1.0
	lean.max_space = 1.0
	lean.add_blend_point(anim_lean_left, -1.0, 0, &"left")
	lean.add_blend_point(anim_lean_center, 0.0, 1, &"center")
	lean.add_blend_point(anim_lean_right, 1.0, 2, &"right")
	tree.add_node(&"lean", lean, Vector2(-200, -60))

	var anim_bob_idle: AnimationNodeAnimation = AnimationNodeAnimation.new()
	anim_bob_idle.animation = &"bob_idle"
	var anim_bob_cycle: AnimationNodeAnimation = AnimationNodeAnimation.new()
	anim_bob_cycle.animation = &"bob_cycle"

	var bob: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
	bob.min_space = 0.0
	bob.max_space = RUN_SPEED
	bob.add_blend_point(anim_bob_idle, 0.0, 0, &"idle")
	bob.add_blend_point(anim_bob_cycle, RUN_SPEED, 1, &"cycle")
	tree.add_node(&"bob", bob, Vector2(-400, 40))

	var bob_timescale: AnimationNodeTimeScale = AnimationNodeTimeScale.new()
	tree.add_node(&"bob_timescale", bob_timescale, Vector2(-200, 40))
	tree.connect_node(&"bob_timescale", 0, &"bob")

	var add_lean: AnimationNodeAdd2 = AnimationNodeAdd2.new()
	tree.add_node(&"add_lean", add_lean, Vector2(0, -100))
	tree.connect_node(&"add_lean", 0, &"crouch")
	tree.connect_node(&"add_lean", 1, &"lean")

	var add_bob: AnimationNodeAdd2 = AnimationNodeAdd2.new()
	tree.add_node(&"add_bob", add_bob, Vector2(200, -60))
	tree.connect_node(&"add_bob", 0, &"add_lean")
	tree.connect_node(&"add_bob", 1, &"bob_timescale")

	var anim_land: AnimationNodeAnimation = AnimationNodeAnimation.new()
	anim_land.animation = &"land_dip"
	tree.add_node(&"anim_land", anim_land, Vector2(200, 60))

	var land: AnimationNodeOneShot = AnimationNodeOneShot.new()
	# Additive, not replacing: the land dip only offsets BobPivot. Blend
	# mode (the default) would otherwise reset every track the "shot"
	# animation doesn't itself define -- including CrouchPivot and
	# LeanPivot -- to their zero pose for the dip's whole duration.
	land.mix_mode = AnimationNodeOneShot.MIX_MODE_ADD
	tree.add_node(&"land", land, Vector2(400, 0))
	tree.connect_node(&"land", 0, &"add_bob")
	tree.connect_node(&"land", 1, &"anim_land")

	tree.connect_node(&"output", 0, &"land")
	return tree
