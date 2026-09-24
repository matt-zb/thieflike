extends GutTest

## M0 smoke test: verifies the project bootstrap (autoloads, main scene
## shape, renderer/physics settings, input map and collision layers) rather
## than any gameplay behaviour.

const MAIN_SCENE_PATH: String = "res://main/main.tscn"

const EXPECTED_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"run", &"creep", &"crouch", &"lean_left", &"lean_right", &"jump",
	&"interact", &"use_item", &"throw", &"item_next", &"item_prev",
	&"holster", &"check_watch", &"debug_overlay", &"debug_restart",
]

const EXPECTED_LAYER_NAMES: Array[String] = [
	"WORLD", "PLAYER", "NPC", "INTERACTABLE",
	"CARRIABLE", "LIGHT_OCCLUDER", "TRIGGER", "NAV_EXCLUDE",
]


func test_autoloads_exist_under_root() -> void:
	var root: Window = get_tree().root
	assert_not_null(root.get_node_or_null("GameState"), "GameState autoload should exist under /root")
	assert_not_null(root.get_node_or_null("TimelineManager"), "TimelineManager autoload should exist under /root")


func test_main_scene_instantiates_with_expected_node_paths() -> void:
	var packed: PackedScene = load(MAIN_SCENE_PATH)
	assert_not_null(packed, "main.tscn should load")
	var main: Node = packed.instantiate()
	add_child_autofree(main)

	assert_not_null(main.get_node_or_null("World"), "Main/World should exist")
	assert_not_null(main.get_node_or_null("World/Geometry"), "Main/World/Geometry should exist")
	assert_not_null(main.get_node_or_null("World/Lights"), "Main/World/Lights should exist")
	assert_not_null(main.get_node_or_null("World/NPCs"), "Main/World/NPCs should exist")
	assert_not_null(main.get_node_or_null("World/Interactables"), "Main/World/Interactables should exist")
	assert_not_null(main.get_node_or_null("World/NavigationRegion3D"), "Main/World/NavigationRegion3D should exist")
	assert_not_null(main.get_node_or_null("World/Systems"), "Main/World/Systems should exist")
	assert_not_null(main.get_node_or_null("Player"), "Main/Player should exist")
	assert_not_null(main.get_node_or_null("UI"), "Main/UI should exist")

	assert_true(main.get_node("World") is Node3D, "World should be Node3D")
	assert_true(main.get_node("World/NavigationRegion3D") is NavigationRegion3D, "NavigationRegion3D should be that type")
	assert_true(main.get_node("UI") is CanvasLayer, "UI should be a CanvasLayer")


func test_rendering_method_is_forward_plus() -> void:
	var method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method", "")
	assert_eq(method, "forward_plus")


func test_physics_engine_is_jolt_at_60hz() -> void:
	var engine_name: String = ProjectSettings.get_setting("physics/3d/physics_engine", "")
	assert_eq(engine_name, "Jolt Physics")

	var tick_rate: int = ProjectSettings.get_setting("physics/common/physics_ticks_per_second", -1)
	assert_eq(tick_rate, 60)


func test_input_actions_exist_with_events() -> void:
	for action: StringName in EXPECTED_ACTIONS:
		assert_true(InputMap.has_action(action), "Input map should have action '%s'" % action)
		if InputMap.has_action(action):
			var events: Array[InputEvent] = InputMap.action_get_events(action)
			assert_gt(events.size(), 0, "Action '%s' should have at least one bound event" % action)


func test_collision_layer_names_match() -> void:
	for i: int in range(EXPECTED_LAYER_NAMES.size()):
		var layer_index: int = i + 1
		var layer_name: String = ProjectSettings.get_setting("layer_names/3d_physics/layer_%d" % layer_index, "")
		assert_eq(layer_name, EXPECTED_LAYER_NAMES[i], "Layer %d name mismatch" % layer_index)
