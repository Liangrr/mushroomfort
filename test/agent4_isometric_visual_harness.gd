extends Node


func _ready() -> void:
	Game.run_seed = 404
	var stage_id := StringName(OS.get_environment("AGENT4_STAGE"))
	if stage_id == &"":
		stage_id = &"s1"
	Game.start_battle(stage_id)
