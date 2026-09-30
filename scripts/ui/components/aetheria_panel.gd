class_name AetheriaPanel
extends PanelContainer

const ROLE_VARIATIONS := {
	&"reading": &"AuiReadingPanel",
	&"hud": &"AuiHudPanel",
	&"card": &"AuiCardPanel",
	&"modal": &"AuiModalPanel",
	&"inspector": &"AuiInspectorPanel",
	&"reward": &"AuiRewardPanel",
	&"focus_ring": &"AuiFocusRing",
}

@export var role: StringName:
	get:
		return _role
	set(value):
		apply_role(value)

var _role: StringName = &"reading"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_role(&"reading")


func apply_role(value: StringName) -> bool:
	if not ROLE_VARIATIONS.has(value):
		return false
	_role = value
	theme_type_variation = ROLE_VARIATIONS[value]
	return true
