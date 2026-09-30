extends Node
## Registers every gameplay action in code (easy to remap) and tracks the last
## input device so hints can show mouse / keyboard / gamepad / touch prompts.

signal device_changed(device: String)

enum { JOY_A = 0, JOY_B = 1, JOY_X = 2, JOY_Y = 3, JOY_BACK = 4, JOY_START = 6, JOY_LB = 9, JOY_RB = 10 }

const ACTIONS := {
	# action: [[keys...], [joypad buttons...]]
	"ui_accept": [[KEY_ENTER, KEY_KP_ENTER], [JOY_A]],
	"ui_cancel": [[KEY_ESCAPE], [JOY_B]],
	"mg_pause": [[KEY_SPACE, KEY_P], [JOY_BACK]],
	"mg_menu": [[], [JOY_START]],
	"mg_speed": [[KEY_F], [JOY_Y]],
	"mg_wave": [[KEY_N], [JOY_X]],
	"mg_tower_1": [[KEY_1], []],
	"mg_tower_2": [[KEY_2], []],
	"mg_tower_3": [[KEY_3], []],
	"mg_tower_4": [[KEY_4], []],
	"mg_sell": [[KEY_DELETE, KEY_BACKSPACE], []],
	"mg_upgrade": [[KEY_U], []],
	"mg_prev_tower": [[KEY_Q], [JOY_LB]],
	"mg_next_tower": [[KEY_E], [JOY_RB]],
}

var device := "mouse"   # mouse | keyboard | gamepad | touch


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.5)
		for key: int in ACTIONS[action][0]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
		for button: int in ACTIONS[action][1]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = button as JoyButton
			jb.device = -1
			InputMap.action_add_event(action, jb)
	# Grid cursor/menu navigation: arrows + WASD + d-pad + left stick.
	_add_nav("ui_left", KEY_A, JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_add_nav("ui_right", KEY_D, JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_add_nav("ui_up", KEY_W, JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0)
	_add_nav("ui_down", KEY_S, JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0)


func _add_nav(action: String, extra_key: Key, dpad: JoyButton, axis: JoyAxis, dir: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	var ev := InputEventKey.new()
	ev.physical_keycode = extra_key
	InputMap.action_add_event(action, ev)
	var has_dpad := false
	var has_axis := false
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and existing.button_index == dpad:
			has_dpad = true
		if existing is InputEventJoypadMotion and existing.axis == axis:
			has_axis = true
	if not has_dpad:
		var jb := InputEventJoypadButton.new()
		jb.button_index = dpad
		InputMap.action_add_event(action, jb)
	if not has_axis:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axis
		jm.axis_value = dir
		InputMap.action_add_event(action, jm)


func _input(event: InputEvent) -> void:
	var next := device
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		next = "touch"
	elif event is InputEventMouseButton and not _is_emulated(event):
		next = "mouse"
	elif event is InputEventMouseMotion and not _is_emulated(event):
		if event.relative.length() > 3.0:
			next = "mouse"
	elif event is InputEventKey and event.pressed:
		next = "keyboard"
	elif event is InputEventJoypadButton and event.pressed:
		next = "gamepad"
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		next = "gamepad"
	if next != device:
		device = next
		device_changed.emit(device)


func _is_emulated(event: InputEvent) -> bool:
	# Touch-emulated mouse events report device -1 (InputEvent.DEVICE_ID_EMULATION).
	return event.device == InputEvent.DEVICE_ID_EMULATION


func uses_focus() -> bool:
	return device == "keyboard" or device == "gamepad"


## Short label for an action in the current device's vocabulary.
func glyph(action: String) -> String:
	var pad := device == "gamepad"
	match action:
		"accept": return "A" if pad else "Enter"
		"cancel": return "B" if pad else "Esc"
		"wave": return "X" if pad else "N"
		"speed": return "Y" if pad else "F"
		"pause": return "Start" if pad else "Space"
		"cycle": return "LB/RB" if pad else "Q/E"
		"move": return "D-Pad" if pad else "WASD"
	return action
