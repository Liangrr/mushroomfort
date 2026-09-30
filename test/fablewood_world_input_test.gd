extends SceneTree

var screen: Control
var clicks: Array[Vector2i] = []
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("run")

func frames(count: int = 2) -> void:
	for i: int in count:
		await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func touch(index: int, at: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	await frames()

func drag(index: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = relative
	Input.parse_input_event(event)
	await frames()

func mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames()

func mouse_motion(at: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	Input.parse_input_event(event)
	await frames()

func point(cell: Vector2i) -> Vector2:
	return screen.world.get_global_transform_with_canvas() * screen.world.screen_of(cell)

func reset_camera() -> void:
	screen.world.reset_view()
	clicks.clear()
	await frames()

func run() -> void:
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	var game: Node = root.get_node("Game")
	check(game.start_campaign(false) and game.start_campaign_stage(&"s1"), "real campaign battle started")
	await frames(12)
	screen = game.content
	if not is_instance_valid(screen) or not screen.startup_succeeded:
		failures.append("battle did not become ready")
		finish()
		return
	if screen._tutorial_active:
		screen._skip_tutorial()
	screen.set_process(false)
	screen.world.cell_clicked.connect(func(cell: Vector2i): clicks.append(cell))
	var previous_emulation := Input.is_emulating_mouse_from_touch()
	var cell := Vector2i(4, 3)
	for emulation: bool in [true, false]:
		Input.set_emulate_mouse_from_touch(emulation)
		await reset_camera()
		var at := point(cell)
		await touch(0, at, true)
		await drag(0, at + Vector2(3, 0), Vector2(3, 0))
		await touch(0, at + Vector2(3, 0), false)
		check(screen.world.pan.is_zero_approx(), "sub-threshold touch jitter does not pan (emulation=%s)" % emulation)
		check(clicks.size() == 1 and clicks[0] == cell, "single touch picks exactly once with jitter (emulation=%s)" % emulation)
		await reset_camera()
		at = point(cell)
		var delta := Vector2(24, 12)
		var expected: Vector2 = screen.world.get_global_transform_with_canvas().affine_inverse().basis_xform(delta)
		await touch(0, at, true)
		await drag(0, at + delta, delta)
		await touch(0, at + delta, false)
		check(screen.world.pan.is_equal_approx(expected), "touch drag applies its displacement once (emulation=%s)" % emulation)
		check(clicks.is_empty(), "touch drag cannot become a release pick")
		await reset_camera()
		at = point(cell)
		await touch(0, at, true)
		await touch(0, at, false, true)
		check(clicks.is_empty(), "canceled native touch cannot select a cell")
		await reset_camera()
		at = point(cell)
		await touch(0, at - Vector2(60, 0), true)
		await touch(1, at + Vector2(60, 0), true)
		await drag(1, at + Vector2(84, 0), Vector2(24, 0))
		check(is_equal_approx(screen.world.zoom, 1.2), "pinch uses the two-finger baseline on its first movement")
		await touch(1, at + Vector2(84, 0), false)
		await touch(0, at - Vector2(60, 0), false)
		check(clicks.is_empty() and screen.world._touches.is_empty(), "pinch releases never become cell picks or leave stale fingers")
	Input.set_emulate_mouse_from_touch(true)
	await reset_camera()
	var at := point(cell)
	await mouse_motion(at, Vector2.ZERO)
	await mouse_button(at, true)
	await mouse_button(at, false)
	check(clicks.size() == 1 and clicks[0] == cell, "genuine mouse picking is preserved")
	await reset_camera()
	at = point(cell)
	var delta := Vector2(24, 12)
	var expected: Vector2 = screen.world.get_global_transform_with_canvas().affine_inverse().basis_xform(delta)
	await mouse_button(at, true)
	await mouse_motion(at + delta, delta)
	await mouse_button(at + delta, false)
	check(screen.world.pan.is_equal_approx(expected) and clicks.is_empty(), "genuine mouse dragging remains one movement with no pick")
	await reset_camera()
	screen._show_tutorial()
	await frames()
	at = point(cell)
	await touch(0, at, true)
	await touch(0, at, false)
	check(clicks.is_empty() and screen.model.units.is_empty(), "tutorial introduction blocks native touch gameplay")
	screen._tutorial_advance(false)
	await frames()
	var card: Button = screen._cards[0]
	at = card.get_global_rect().get_center()
	await touch(0, at, true)
	await touch(0, at, false)
	check(screen._tutorial_step == 2 and screen.chosen == &"caster_1", "tutorial still permits the highlighted touch selection button")
	at = point(cell)
	await touch(0, at, true)
	await touch(0, at, false)
	check(screen.model.units.size() == 1 and screen.model.dp == 220 and screen._tutorial_step == 3, "highlighted native touch placement spends once and advances on the real action")
	screen._skip_tutorial()
	Input.set_emulate_mouse_from_touch(previous_emulation)
	finish()

func finish() -> void:
	for message: String in failures:
		push_error(message)
	print("FABLEWOOD_WORLD_INPUT failures=", failures.size(), " checks=", checks)
	quit(0 if failures.is_empty() else 1)
