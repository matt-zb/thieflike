extends GutTest

## Bob foot-plants should fire at a regular cadence while walking
## (ARCHITECTURE.md §4.3, MILESTONES.md M1). AnimationTree method-call
## tracks are not guaranteed to advance in a headless run, so this falls
## back to `pending()` and points at test_bob_math.gd's pure cadence math
## when no plants are observed, per the milestone's own allowance.

var player: PlayerController


func before_each() -> void:
	var floor_body: StaticBody3D = PlayerTestHelpers.make_floor(20.0)
	add_child_autofree(floor_body)
	player = PlayerTestHelpers.make_player()
	add_child_autofree(player)
	player.input_reader.enabled = false
	player.global_position = Vector3(0.0, 0.02, 0.0)
	await wait_physics_frames(3)


func test_foot_plants_are_regular_while_walking() -> void:
	var plant_times: Array = []
	var elapsed: float = 0.0
	var on_plant: Callable = func(_foot: int) -> void:
		plant_times.append(elapsed)
	player.foot_planted.connect(on_plant)

	player.intent.wish_dir = Vector2(0.0, 1.0)
	for _i in range(240):
		await wait_physics_frames(1)
		elapsed += 1.0 / 60.0

	if plant_times.size() < 3:
		pending(
			"AnimationTree method-call tracks did not advance in this headless run; " +
			"see tests/unit/test_bob_math.gd for the cadence math this would otherwise verify."
		)
		return

	var intervals: Array = []
	for i in range(1, plant_times.size()):
		intervals.append(plant_times[i] - plant_times[i - 1])
	var total: float = 0.0
	for iv: float in intervals:
		total += iv
	var average: float = total / intervals.size()

	for iv: float in intervals:
		assert_almost_eq(iv, average, maxf(average * 0.5, 0.05))
