class_name AetheriaLabel
extends Label

const ROLE_VARIATIONS := {
	&"title": &"AuiTitleLabel",
	&"heading": &"AuiHeadingLabel",
	&"body": &"AuiBodyLabel",
	&"detail": &"AuiDetailLabel",
	&"dense_heading": &"AuiDenseHeadingLabel",
	&"dense_body": &"AuiDenseBodyLabel",
	&"dense_detail": &"AuiDenseDetailLabel",
	&"locale": &"AuiLocaleLabel",
	&"class_badge": &"AuiClassBadge",
	&"cost_badge": &"AuiCostBadge",
	&"cooldown_badge": &"AuiCooldownBadge",
	&"locked_badge": &"AuiLockedBadge",
	&"completed_badge": &"AuiCompletedBadge",
}

@export var role: StringName:
	get:
		return _role
	set(value):
		apply_role(value)

var _role: StringName = &"body"


func _init() -> void:
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_role(&"body")


func apply_role(value: StringName) -> bool:
	if not ROLE_VARIATIONS.has(value):
		return false
	_role = value
	theme_type_variation = ROLE_VARIATIONS[value]
	return true
