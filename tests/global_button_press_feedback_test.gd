extends SceneTree

const ActionHoverFeedbackType := preload("res://scripts/ui/components/action_hover_feedback.gd")
const PRESS_FACTOR := 0.96
const EPSILON := 0.006

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	var feedback := root.get_node_or_null("UiFeedback")
	var sfx := root.get_node_or_null("Sfx")
	_check(feedback != null, "UiFeedback autoload is missing")
	_check(sfx != null, "Sfx autoload is missing")
	if feedback == null or sfx == null:
		_finish()
		return

	var buttons: Array[BaseButton] = [
		Button.new(),
		CheckButton.new(),
		OptionButton.new(),
		TextureButton.new(),
	]
	var base_scales := [
		Vector2.ONE,
		Vector2(1.025, 1.025),
		Vector2(0.98, 0.98),
		Vector2(1.1, 1.1),
	]
	for index: int in buttons.size():
		var button := buttons[index]
		button.name = "GlobalPressButton%d" % index
		button.position = Vector2(4096.0 + index * 180.0, 4096.0)
		button.size = Vector2(160.0, 64.0)
		button.scale = base_scales[index]
		root.add_child(button)
	await process_frame
	await process_frame

	for index: int in buttons.size():
		var button := buttons[index]
		var base_scale: Vector2 = base_scales[index]
		_check(bool(feedback.call("button_is_bound", button)), "%s is not globally bound" % button.get_class())
		_check(button.pivot_offset.is_equal_approx(button.size * 0.5), "%s pivot is not centered" % button.get_class())
		button.button_down.emit()
		_check(bool(feedback.call("button_feedback_active", button)), "%s press state did not activate" % button.get_class())
		_check(_near_vec(button.scale, base_scale * PRESS_FACTOR), "%s did not shrink from its own base scale" % button.get_class())
		button.button_up.emit()
		await create_timer(0.16).timeout
		_check(_near_vec(button.scale, base_scale), "%s did not release to its original base scale" % button.get_class())
		_check(not bool(feedback.call("button_feedback_active", button)), "%s press state did not settle" % button.get_class())
		var audible_before := int(sfx.call("audible_start_count"))
		var click_count_before := int(feedback.call("click_play_count"))
		button.pressed.emit()
		await process_frame
		_check(int(sfx.call("audible_start_count")) == audible_before + 1, "%s did not play exactly one click" % button.get_class())
		_check(int(feedback.call("click_play_count")) == click_count_before + 1, "%s click was not globally owned" % button.get_class())
		_check(sfx.call("last_resolved_id") == &"ui_click", "%s did not resolve to the click cue" % button.get_class())

	var composited := buttons[0]
	composited.scale = Vector2.ONE
	composited.button_down.emit()
	composited.scale = Vector2(1.2, 1.2)
	await process_frame
	await process_frame
	_check(
		_near_vec(composited.scale, Vector2(1.2, 1.2) * PRESS_FACTOR),
		"external hover/pulse scale was not composed during press: %s" % composited.scale,
	)
	composited.button_up.emit()
	await create_timer(0.16).timeout
	_check(_near_vec(composited.scale, Vector2(1.2, 1.2)), "external hover/pulse scale was not restored after release")

	var priority_action := Button.new()
	priority_action.name = "PriorityPressAction"
	priority_action.position = Vector2(4096.0, 4220.0)
	priority_action.size = Vector2(240.0, 72.0)
	root.add_child(priority_action)
	await process_frame
	ActionHoverFeedbackType.wire(root, priority_action)
	priority_action.mouse_entered.emit()
	await create_timer(0.24).timeout
	_check(_near_vec(priority_action.scale, Vector2(1.04, 1.04)), "priority action hover did not establish its base scale")
	priority_action.button_down.emit()
	_check(_near_vec(priority_action.scale, Vector2(1.04, 1.04) * PRESS_FACTOR), "priority action press did not compose with hover")
	priority_action.button_up.emit()
	await create_timer(0.16).timeout
	_check(_near_vec(priority_action.scale, Vector2(1.04, 1.04)), "priority action did not return to hover scale")
	priority_action.mouse_exited.emit()
	await create_timer(0.24).timeout
	_check(_near_vec(priority_action.scale, Vector2.ONE), "priority action hover did not settle after press")

	var disabled := Button.new()
	disabled.name = "DisabledPressButton"
	disabled.position = Vector2(4096.0, 4320.0)
	disabled.size = Vector2(180.0, 64.0)
	disabled.disabled = true
	root.add_child(disabled)
	await process_frame
	disabled.button_down.emit()
	_check(_near_vec(disabled.scale, Vector2.ONE), "disabled button still animated")
	_check(not bool(feedback.call("button_feedback_active", disabled)), "disabled button activated feedback state")

	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	var reduced := Button.new()
	reduced.name = "ReducedMotionPressButton"
	reduced.position = Vector2(4096.0, 4420.0)
	reduced.size = Vector2(220.0, 64.0)
	reduced.scale = Vector2(1.08, 1.08)
	root.add_child(reduced)
	await process_frame
	reduced.button_down.emit()
	_check(_near_vec(reduced.scale, Vector2(1.08, 1.08)), "reduced motion still shrank a button")
	reduced.button_up.emit()
	await process_frame
	_check(_near_vec(reduced.scale, Vector2(1.08, 1.08)), "reduced motion changed the button base scale")
	ProjectSettings.set_setting("accessibility/reduced_motion", false)

	for button: BaseButton in buttons:
		button.queue_free()
	priority_action.queue_free()
	disabled.queue_free()
	reduced.queue_free()
	sfx.call("stop_all")
	await process_frame
	call_deferred("_finish")


func _near_vec(actual: Vector2, expected: Vector2) -> bool:
	return actual.distance_to(expected) <= EPSILON


func _finish() -> void:
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	if _failures.is_empty():
		print("GLOBAL_BUTTON_PRESS_FEEDBACK_TEST_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
