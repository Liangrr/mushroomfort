extends SceneTree
## Headless balance bot entry. Run: tools/run_godot_test.sh tests/mg_autoplay.gd -- [strategy] [levels]
## The runner is loaded at runtime so autoload singletons resolve.


func _initialize() -> void:
	var runner: Node = load("res://tests/mg_autoplay_runner.gd").new()
	root.add_child.call_deferred(runner)
