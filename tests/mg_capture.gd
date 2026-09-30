extends SceneTree
## Native capture entry (needs a display):
##   xvfb-run tools/run_godot_isolated.sh --script res://tests/mg_capture.gd -- [all|title|maps|battle_L2...][_zh]


func _initialize() -> void:
	var runner: Node = load("res://tests/mg_capture_runner.gd").new()
	root.add_child.call_deferred(runner)
