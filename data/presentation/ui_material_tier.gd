class_name UiMaterialTier
extends Resource

const REQUIRED_ROLES: Array[StringName] = [
	&"primary_button", &"secondary_button", &"destructive_button", &"disabled_button",
	&"reading_panel", &"hud_panel", &"card_panel", &"modal_panel", &"inspector_panel",
	&"reward_panel", &"class_badge", &"cost_badge", &"cooldown_badge", &"locked_badge",
	&"completed_badge", &"focus_ring",
]

@export var schema_version: int = 1
@export var tier_id: StringName = &""
@export var theme_path: String = ""
@export var type_variations: Dictionary = {}
@export var panel_opacity: float = 1.0
@export var ambient_emission_scale: float = 1.0


func validate_contract() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != 1:
		errors.append("schema_version: expected 1")
	if tier_id == &"":
		errors.append("tier_id: required")
	if theme_path.is_empty() or not theme_path.begins_with("res://"):
		errors.append("theme_path: required res:// Theme")
	elif not ResourceLoader.exists(theme_path, "Theme"):
		errors.append("theme_path: missing Theme %s" % theme_path)
	elif not load(theme_path) is Theme:
		errors.append("theme_path: expected Theme %s" % theme_path)
	if type_variations.size() != REQUIRED_ROLES.size():
		errors.append("type_variations: expected exact sixteen roles")
	for role: StringName in REQUIRED_ROLES:
		if not type_variations.has(role):
			errors.append("type_variations: missing %s" % role)
			continue
		var value: Variant = type_variations[role]
		if typeof(value) != TYPE_STRING_NAME or value == &"":
			errors.append("type_variations.%s: expected nonempty StringName" % role)
	for raw_key: Variant in type_variations:
		if typeof(raw_key) != TYPE_STRING_NAME or not REQUIRED_ROLES.has(raw_key):
			errors.append("type_variations: unexpected key %s" % raw_key)
	for item: Array in [
		["panel_opacity", panel_opacity],
		["ambient_emission_scale", ambient_emission_scale],
	]:
		var value := float(item[1])
		if not is_finite(value) or value < 0.0 or value > 1.0:
			errors.append("%s: expected finite [0,1]" % item[0])
	return errors
