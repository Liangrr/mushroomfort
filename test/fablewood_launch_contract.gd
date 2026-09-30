extends SceneTree

const LaunchChecks := preload("fablewood_launch_checks.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var fixture := LaunchChecks.new(self)
	var result: Dictionary = await fixture.run()
	quit(0 if int(result.failures) == 0 else 1)
