class_name ActionHoverFeedback
extends RefCounted

## Shared hover/focus motion for high-priority actions. Scale is transform-only,
## preserves container geometry, and is disabled when reduced motion is active.

const HOVER_SCALE := Vector2(1.04, 1.04)
const FOCUS_SCALE := Vector2(1.015, 1.015)
const HOVER_TINT := Color("fff2c6")
const FOCUS_TINT := Color("fff4d2")
const IDLE_TINT := Color.WHITE
const TRANSITION_SECONDS := 0.18

const META_WIRED := &"action_hover_feedback_wired"
const META_HOVERED := &"action_hover_feedback_hovered"
const META_FOCUSED := &"action_hover_feedback_focused"
const META_TWEEN := &"action_hover_feedback_tween"
const META_HOVER_SCALE := &"action_hover_feedback_hover_scale"
const META_FOCUS_SCALE := &"action_hover_feedback_focus_scale"
const META_HOVER_TINT := &"action_hover_feedback_hover_tint"
const META_FOCUS_TINT := &"action_hover_feedback_focus_tint"


static func wire(
	owner: Node,
	button: Button,
	hover_scale: Vector2 = HOVER_SCALE,
	focus_scale: Vector2 = FOCUS_SCALE,
	hover_tint: Color = HOVER_TINT,
	focus_tint: Color = FOCUS_TINT,
) -> bool:
	if owner == null or button == null or bool(button.get_meta(META_WIRED, false)):
		return false
	button.set_meta(META_WIRED, true)
	button.set_meta(META_HOVERED, false)
	button.set_meta(META_FOCUSED, button.has_focus())
	button.set_meta(META_HOVER_SCALE, hover_scale)
	button.set_meta(META_FOCUS_SCALE, focus_scale)
	button.set_meta(META_HOVER_TINT, hover_tint)
	button.set_meta(META_FOCUS_TINT, focus_tint)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.resized.connect(_center_pivot.bind(button))
	button.mouse_entered.connect(_set_hovered.bind(owner, button, true))
	button.mouse_exited.connect(_set_hovered.bind(owner, button, false))
	button.focus_entered.connect(_set_focused.bind(owner, button, true))
	button.focus_exited.connect(_set_focused.bind(owner, button, false))
	_center_pivot.call_deferred(button)
	_refresh(owner, button, true)
	return true


static func reset(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	_kill_tween(button)
	button.scale = Vector2.ONE
	button.modulate = IDLE_TINT
	button.set_meta(META_HOVERED, false)
	button.set_meta(META_FOCUSED, false)


static func _center_pivot(button: Button) -> void:
	if button != null and is_instance_valid(button):
		button.pivot_offset = button.size * 0.5


static func _set_hovered(owner: Node, button: Button, highlighted: bool) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.set_meta(META_HOVERED, highlighted)
	_refresh(owner, button)


static func _set_focused(owner: Node, button: Button, highlighted: bool) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.set_meta(META_FOCUSED, highlighted)
	_refresh(owner, button)


static func _refresh(owner: Node, button: Button, immediate := false) -> void:
	if owner == null or not is_instance_valid(owner) or button == null or not is_instance_valid(button):
		return
	var hovered := bool(button.get_meta(META_HOVERED, false))
	var focused := bool(button.get_meta(META_FOCUSED, false))
	var hover_scale: Vector2 = button.get_meta(META_HOVER_SCALE, HOVER_SCALE)
	var focus_scale: Vector2 = button.get_meta(META_FOCUS_SCALE, FOCUS_SCALE)
	var hover_tint: Color = button.get_meta(META_HOVER_TINT, HOVER_TINT)
	var focus_tint: Color = button.get_meta(META_FOCUS_TINT, FOCUS_TINT)
	var target_scale := hover_scale if hovered else (focus_scale if focused else Vector2.ONE)
	var target_tint := hover_tint if hovered else (focus_tint if focused else IDLE_TINT)
	var reduced_motion := bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
	if reduced_motion:
		target_scale = Vector2.ONE
	_kill_tween(button)
	if immediate or reduced_motion or not owner.is_inside_tree():
		button.scale = target_scale
		button.modulate = target_tint
		return
	var tween := owner.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, TRANSITION_SECONDS)
	tween.tween_property(button, "modulate", target_tint, TRANSITION_SECONDS)
	button.set_meta(META_TWEEN, tween)


static func _kill_tween(button: Button) -> void:
	if not button.has_meta(META_TWEEN):
		return
	var tween_value: Variant = button.get_meta(META_TWEEN)
	if tween_value is Tween and (tween_value as Tween).is_valid():
		(tween_value as Tween).kill()
	button.remove_meta(META_TWEEN)
