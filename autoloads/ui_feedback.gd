extends Node

## Global tactile feedback for every BaseButton. Press scale is applied as a
## multiplicative presentation layer so it composes with existing hover, pulse,
## selection, and reveal animation owners without changing container geometry.

const PRESS_FACTOR := 0.96
const RELEASE_SECONDS := 0.12
const CLICK_CUE_ID := "ui_click"
const META_BOUND := &"_protos_press_feedback_bound"
const META_ACTIVE := &"_protos_press_feedback_active"
const META_BASE_SCALE := &"_protos_press_feedback_base_scale"
const META_LAST_APPLIED_SCALE := &"_protos_press_feedback_last_applied_scale"

var _states: Dictionary = {}
var _binding_count := 0
var _click_play_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	get_tree().node_added.connect(_on_tree_node_added)
	_bind_descendants(get_tree().root)


func _process(delta: float) -> void:
	for instance_id: Variant in _states.keys():
		_advance_state(int(instance_id), delta)


func binding_count() -> int:
	return _binding_count


func button_is_bound(button: BaseButton) -> bool:
	return button != null and bool(button.get_meta(META_BOUND, false))


func button_feedback_active(button: BaseButton) -> bool:
	return button != null and bool(button.get_meta(META_ACTIVE, false))


func click_play_count() -> int:
	return _click_play_count


func _on_tree_node_added(node: Node) -> void:
	if node is BaseButton:
		_bind_button_by_id.call_deferred(node.get_instance_id())


func _bind_button_by_id(instance_id: int) -> void:
	var value := instance_from_id(instance_id)
	if value is BaseButton:
		_bind_button(value as BaseButton)


func _bind_descendants(node: Node) -> void:
	if node is BaseButton:
		_bind_button(node as BaseButton)
	for child: Node in node.get_children():
		_bind_descendants(child)


func _bind_button(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button) or bool(button.get_meta(META_BOUND, false)):
		return
	button.set_meta(META_BOUND, true)
	button.set_meta(META_ACTIVE, false)
	button.resized.connect(_center_pivot.bind(button))
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))
	button.pressed.connect(_on_button_pressed.bind(button))
	button.tree_exiting.connect(_on_button_tree_exiting.bind(button.get_instance_id()))
	_center_pivot.call_deferred(button)
	_binding_count += 1


func _center_pivot(button: BaseButton) -> void:
	if button != null and is_instance_valid(button):
		button.pivot_offset = button.size * 0.5


func _on_button_down(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button) or button.disabled:
		return
	_center_pivot(button)
	var base_scale := button.scale
	button.set_meta(META_ACTIVE, true)
	button.set_meta(META_BASE_SCALE, base_scale)
	button.set_meta(META_LAST_APPLIED_SCALE, base_scale)
	var state := {
		"button": weakref(button),
		"base_scale": base_scale,
		"last_applied_scale": base_scale,
		"factor": 1.0,
		"start_factor": PRESS_FACTOR,
		"target_factor": PRESS_FACTOR,
		"elapsed": 0.0,
		"duration": 0.0,
		"pressed": true,
	}
	_states[button.get_instance_id()] = state
	if _motion_reduced():
		button.scale = base_scale
		state["last_applied_scale"] = base_scale
	else:
		var pressed_scale := base_scale * PRESS_FACTOR
		button.scale = pressed_scale
		state["factor"] = PRESS_FACTOR
		state["last_applied_scale"] = pressed_scale
	button.set_meta(META_LAST_APPLIED_SCALE, state["last_applied_scale"])
	_states[button.get_instance_id()] = state


func _on_button_up(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		return
	_begin_release(button.get_instance_id())


func _on_button_pressed(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button) or button.disabled:
		return
	var sfx := get_tree().root.get_node_or_null("Sfx")
	if sfx != null and bool(sfx.call("play", CLICK_CUE_ID)):
		_click_play_count += 1


func _begin_release(instance_id: int) -> void:
	if not _states.has(instance_id):
		return
	var state: Dictionary = _states[instance_id]
	var button := _button_from_state(state)
	if button == null:
		_states.erase(instance_id)
		return
	_sync_external_base(button, state)
	if _motion_reduced():
		_finish_state(instance_id, button, state)
		return
	state["pressed"] = false
	state["start_factor"] = float(state.get("factor", PRESS_FACTOR))
	state["target_factor"] = 1.0
	state["elapsed"] = 0.0
	state["duration"] = RELEASE_SECONDS
	_states[instance_id] = state


func _advance_state(instance_id: int, delta: float) -> void:
	if not _states.has(instance_id):
		return
	var state: Dictionary = _states[instance_id]
	var button := _button_from_state(state)
	if button == null:
		_states.erase(instance_id)
		return
	_sync_external_base(button, state)
	if _motion_reduced():
		_finish_state(instance_id, button, state)
		return
	if button.disabled and bool(state.get("pressed", false)):
		state["pressed"] = false
		state["start_factor"] = float(state.get("factor", PRESS_FACTOR))
		state["target_factor"] = 1.0
		state["elapsed"] = 0.0
		state["duration"] = RELEASE_SECONDS
	if bool(state.get("pressed", false)):
		state["factor"] = PRESS_FACTOR
		_apply_state(button, state)
		_states[instance_id] = state
		return
	var duration := maxf(float(state.get("duration", RELEASE_SECONDS)), 0.0001)
	var elapsed := minf(float(state.get("elapsed", 0.0)) + maxf(delta, 0.0), duration)
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	state["elapsed"] = elapsed
	state["factor"] = lerpf(
		float(state.get("start_factor", PRESS_FACTOR)),
		float(state.get("target_factor", 1.0)),
		eased,
	)
	_apply_state(button, state)
	if progress >= 1.0:
		_finish_state(instance_id, button, state)
	else:
		_states[instance_id] = state


func _sync_external_base(button: BaseButton, state: Dictionary) -> void:
	var last_applied: Vector2 = state.get("last_applied_scale", button.scale)
	if not button.scale.is_equal_approx(last_applied):
		state["base_scale"] = button.scale
		button.set_meta(META_BASE_SCALE, button.scale)


func _apply_state(button: BaseButton, state: Dictionary) -> void:
	var base_scale: Vector2 = state.get("base_scale", Vector2.ONE)
	var applied_scale := base_scale * float(state.get("factor", 1.0))
	button.scale = applied_scale
	state["last_applied_scale"] = applied_scale
	button.set_meta(META_LAST_APPLIED_SCALE, applied_scale)
	button.set_meta(META_BASE_SCALE, base_scale)


func _finish_state(instance_id: int, button: BaseButton, state: Dictionary) -> void:
	var base_scale: Vector2 = state.get("base_scale", button.scale)
	button.scale = base_scale
	button.set_meta(META_ACTIVE, false)
	button.set_meta(META_BASE_SCALE, base_scale)
	button.set_meta(META_LAST_APPLIED_SCALE, base_scale)
	_states.erase(instance_id)


func _button_from_state(state: Dictionary) -> BaseButton:
	var reference := state.get("button") as WeakRef
	if reference == null:
		return null
	var value: Variant = reference.get_ref()
	return value as BaseButton if value is BaseButton and is_instance_valid(value) else null


func _on_button_tree_exiting(instance_id: int) -> void:
	_states.erase(instance_id)


func _motion_reduced() -> bool:
	return bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
