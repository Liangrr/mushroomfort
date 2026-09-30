extends SceneTree

const JuiceLayerType := preload("res://scripts/view/juice_layer.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var config := load("res://data/juice_config.tres") as JuiceConfig
	_check(config != null, "juice config failed to load")
	if config == null:
		_finish()
		return
	var grid := Node2D.new()
	root.add_child(grid)
	var juice := JuiceLayerType.new()
	root.add_child(juice)
	juice.setup(config, grid)

	var sprite_trap := _sprite_backed_trap()
	grid.add_child(sprite_trap)
	juice.sprung(sprite_trap, false)
	_check(is_zero_approx(sprite_trap.color.a), "sprite-backed Spike Plate gained an activation background")
	var activation_cue := juice.get_node_or_null("MapTransientRoot/MapTransientSprung")
	_check(activation_cue is Line2D, "Spike Plate activation cue must be an unfilled outline")

	var fallback_trap := _fallback_trap()
	grid.add_child(fallback_trap)
	juice.sprung(fallback_trap, false)
	_check(is_zero_approx(fallback_trap.color.a), "fallback Spike Plate gained an activation background")

	for _frame: int in config.trap_sprung_frames + 1:
		await process_frame
	_check(is_zero_approx(sprite_trap.color.a), "sprite-backed Spike Plate regained a background after activation")
	_check(is_zero_approx(fallback_trap.color.a), "fallback Spike Plate regained a background after activation")

	juice.free()
	grid.free()
	_finish()


func _sprite_backed_trap() -> ColorRect:
	var trap := ColorRect.new()
	trap.color = Color("f4b41b")
	trap.size = Vector2(64.0, 32.0)
	var sprite := TextureRect.new()
	sprite.name = "Sprite"
	sprite.texture = Art.texture(&"trap_spike_armed")
	sprite.size = trap.size
	trap.add_child(sprite)
	return trap


func _fallback_trap() -> ColorRect:
	var trap := ColorRect.new()
	trap.color = Color("f4b41b")
	trap.size = Vector2(24.0, 24.0)
	var core := ColorRect.new()
	core.color = Color("1a1c2c")
	core.size = Vector2(8.0, 8.0)
	trap.add_child(core)
	return trap


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SPIKE_PLATE_TRANSPARENCY_TEST_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
