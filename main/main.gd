extends Node

## Root of the game. Owns the current level under World and the always-
## present Player. M1: places the Player at the level's PlayerStart marker
## on ready; level swapping and mission wiring come later (ARCHITECTURE.md
## §3, §12).


func _ready() -> void:
	_place_player_at_start()


func _place_player_at_start() -> void:
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player == null:
		return
	var start: Node3D = get_node_or_null("World/PlayerStart") as Node3D
	if start == null:
		push_warning("main.gd: World/PlayerStart not found; Player stays at its scene position")
		return
	player.global_transform = start.global_transform
