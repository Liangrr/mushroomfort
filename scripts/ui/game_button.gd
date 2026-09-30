class_name GameButton
extends Button
## Button with squash/stretch hover + press feedback and UI sounds.

@export var click_sound := "click"
var _tween: Tween


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	resized.connect(_center_pivot)
	_center_pivot()
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_on_focus)
	focus_exited.connect(_on_hover.bind(false))
	button_down.connect(_squash)
	pressed.connect(_on_pressed)


func _center_pivot() -> void:
	pivot_offset = size / 2.0


func _on_hover(inside: bool) -> void:
	if disabled:
		return
	if inside:
		Sound.play("hover")
	_scale_to(1.06 if inside or has_focus() else 1.0, 0.12)


func _on_focus() -> void:
	if Controls.uses_focus():
		Sound.play("hover")
	_scale_to(1.06, 0.12)


func _squash() -> void:
	_scale_to(0.93, 0.05)


func _on_pressed() -> void:
	if click_sound != "":
		Sound.play(click_sound)
	if _tween != null:
		_tween.kill()
	scale = Vector2(0.92, 0.92)
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * (1.06 if is_hovered() else 1.0), 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if Controls.device != "gamepad" and Controls.device != "keyboard":
		release_focus.call_deferred()


func _scale_to(target: float, time: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * target, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
