class_name AetheriaButton
extends Button

const AetheriaLabelType := preload("res://scripts/ui/components/aetheria_label.gd")
const GameTypographyType := preload("res://scripts/ui/game_typography.gd")
const COMPACT_ACTION_MINIMUM_WIDTH := 44.0
const COMPACT_ACTION_MINIMUM_HEIGHT := 64.0
const COMPACT_ACTION_FONT_SIZE := GameTypographyType.BODY
const COMPACT_ACTION_ROW_TOP_PADDING := 12

const ROLE_VARIATIONS := {
	&"primary": &"AuiPrimaryButton",
	&"secondary": &"AuiSecondaryButton",
	&"selected": &"AuiSelectedButton",
	&"destructive": &"AuiDestructiveButton",
	&"disabled": &"AuiDisabledButton",
}

@export var role: StringName:
	get:
		return _role
	set(value):
		apply_role(value)

var _role: StringName = &"secondary"


func _init() -> void:
	custom_minimum_size = Vector2(44.0, 52.0)
	focus_mode = Control.FOCUS_ALL
	apply_role(&"secondary")


func _get_minimum_size() -> Vector2:
	var minimum := custom_minimum_size
	var label := get_node_or_null("PresentationLabel") as AetheriaLabelType
	if label != null:
		var label_minimum := label.get_combined_minimum_size() + Vector2(32.0, 20.0)
		minimum.x = maxf(minimum.x, label_minimum.x)
		minimum.y = maxf(minimum.y, label_minimum.y)
	return minimum


func apply_role(value: StringName) -> bool:
	if not ROLE_VARIATIONS.has(value):
		return false
	_role = value
	theme_type_variation = ROLE_VARIATIONS[value]
	return true


func set_presentation_text(logical_text: String, rendered_text: String) -> bool:
	if logical_text.is_empty() or rendered_text.is_empty():
		return false
	text = logical_text
	autowrap_mode = TextServer.AUTOWRAP_OFF
	clip_text = true
	var transparent := Color(0.0, 0.0, 0.0, 0.0)
	for color_name: StringName in [
		&"font_color", &"font_hover_color", &"font_pressed_color",
		&"font_hover_pressed_color", &"font_focus_color", &"font_disabled_color",
	]:
		add_theme_color_override(color_name, transparent)
	var label := get_node_or_null("PresentationLabel") as AetheriaLabelType
	if label == null:
		label = AetheriaLabelType.new()
		label.name = "PresentationLabel"
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = true
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.apply_role(&"body")
		add_child(label)
	label.text = rendered_text
	return true


func fit_presentation(
	max_width: float,
	minimum_width: float = 44.0,
	minimum_height: float = 52.0,
) -> bool:
	var label := get_node_or_null("PresentationLabel") as AetheriaLabelType
	if label == null or max_width < 44.0:
		return false
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	var text_width := font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
	).x
	var width := clampf(maxf(minimum_width, text_width + 32.0), 44.0, max_width)
	var line_width := maxf(1.0, width - 32.0)
	var line_count := maxi(1, ceili(text_width / line_width))
	var height := maxf(minimum_height, font.get_height(font_size) * line_count + 20.0)
	custom_minimum_size = Vector2(width, height)
	label.clip_text = false
	update_minimum_size()
	return true


func apply_compact_action_layout() -> bool:
	var label := get_node_or_null("PresentationLabel") as AetheriaLabelType
	if label == null:
		return false
	custom_minimum_size = Vector2(
		maxf(custom_minimum_size.x, COMPACT_ACTION_MINIMUM_WIDTH),
		COMPACT_ACTION_MINIMUM_HEIGHT,
	)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_theme_font_size_override(&"font_size", COMPACT_ACTION_FONT_SIZE)
	label.add_theme_font_size_override(&"font_size", COMPACT_ACTION_FONT_SIZE)
	set_meta(&"compact_action_layout", true)
	return true
