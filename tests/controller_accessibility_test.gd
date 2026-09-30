extends SceneTree

const EnemyAnimatorType := preload("res://scripts/view/enemy_animator.gd")
const UiCopyType := preload("res://scripts/ui/components/ui_copy.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(InputMap.has_action(&"ui_accept"), "ui_accept mapping is missing")
	_check(InputMap.has_action(&"ui_cancel"), "ui_cancel mapping is missing")
	_check(InputMap.has_action(&"battle_speed_down"), "battle_speed_down mapping is missing")
	_check(InputMap.has_action(&"battle_speed_up"), "battle_speed_up mapping is missing")
	_check(_has_key(&"ui_accept", KEY_ENTER), "Enter no longer activates ui_accept")
	_check(_has_key(&"ui_accept", KEY_KP_ENTER), "keypad Enter no longer activates ui_accept")
	_check(_has_key(&"ui_accept", KEY_SPACE), "Space no longer activates ui_accept")
	_check(_has_key(&"ui_cancel", KEY_ESCAPE), "Escape no longer activates ui_cancel")
	_check(_has_key(&"battle_speed_down", KEY_Q), "Q no longer reduces battle speed")
	_check(_has_key(&"battle_speed_up", KEY_E), "E no longer increases battle speed")
	_check(_has_joy_button(&"ui_accept", JOY_BUTTON_A), "controller A/Cross is not mapped to ui_accept")
	_check(_has_joy_button(&"ui_cancel", JOY_BUTTON_B), "controller B/Circle is not mapped to ui_cancel")
	_check(_has_joy_button(&"ui_up", JOY_BUTTON_DPAD_UP), "d-pad Up is not mapped to ui_up")
	_check(_has_joy_button(&"ui_down", JOY_BUTTON_DPAD_DOWN), "d-pad Down is not mapped to ui_down")
	_check(_has_joy_button(&"ui_left", JOY_BUTTON_DPAD_LEFT), "d-pad Left is not mapped to ui_left")
	_check(_has_joy_button(&"ui_right", JOY_BUTTON_DPAD_RIGHT), "d-pad Right is not mapped to ui_right")
	_check(_has_axis(&"ui_left", JOY_AXIS_LEFT_X, -1.0), "left stick negative X is not mapped to ui_left")
	_check(_has_axis(&"ui_right", JOY_AXIS_LEFT_X, 1.0), "left stick positive X is not mapped to ui_right")
	_check(_has_axis(&"ui_up", JOY_AXIS_LEFT_Y, -1.0), "left stick negative Y is not mapped to ui_up")
	_check(_has_axis(&"ui_down", JOY_AXIS_LEFT_Y, 1.0), "left stick positive Y is not mapped to ui_down")
	_check(is_equal_approx(InputMap.action_get_deadzone(&"ui_accept"), 0.5), "ui_accept deadzone drifted")
	_check(is_equal_approx(InputMap.action_get_deadzone(&"ui_cancel"), 0.5), "ui_cancel deadzone drifted")
	_check_enemy_display_accessibility()
	_finish()


func _check_enemy_display_accessibility() -> void:
	var expected := {
		&"grunt": "Collector",
		&"runner": "Tagger",
		&"drone": "Hunter Drone",
		&"shieldbearer": "Shieldbearer",
		&"breacher": "Breacher",
		&"spellcaster": "Channeler",
		&"heavy": "Farm Warden",
		&"mini_boss": "Gatecrasher",
	}
	for enemy_id: StringName in expected:
		_check(UiCopyType.enemy_name(enemy_id) == expected[enemy_id], "enemy display role changed for %s" % enemy_id)
	var enemy := EnemyState.new()
	enemy.id = 7
	enemy.def_id = &"runner"
	enemy.path_idx = 0
	var battle := BattleModel.create(
		load("res://data/stages/s1.tres") as StageDef, [], 7, GameConfig.new(), {},
	)
	_check(battle != null, "enemy accessibility battle fixture failed")
	if battle == null:
		return
	var body := EnemyAnimatorType.make_body(enemy, battle, {})
	_check(String(body.accessibility_name) == "Tagger", "enemy body accessibility exposes an internal ID instead of its display role")
	_check(body.mouse_filter == Control.MOUSE_FILTER_IGNORE, "enemy accessibility label changed pointer interaction")
	body.free()


func _has_key(action: StringName, physical_code: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == physical_code:
			return true
	return false


func _has_joy_button(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false


func _has_axis(action: StringName, axis: JoyAxis, axis_value: float) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if (
			event is InputEventJoypadMotion
			and (event as InputEventJoypadMotion).axis == axis
			and is_equal_approx((event as InputEventJoypadMotion).axis_value, axis_value)
		):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CONTROLLER_ACCESSIBILITY_TEST_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
