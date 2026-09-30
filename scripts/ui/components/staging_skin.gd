class_name StagingSkin
extends RefCounted

const BODY_FONT: Font = preload("res://assets/template/fonts/ui_regular.tres")
const DISPLAY_FONT: Font = preload("res://assets/template/fonts/ui_medium.tres")
const TITLE_FONT: Font = preload("res://assets/template/fonts/ui_bold.tres")

const LUNARIS_SEAL := preload("res://assets/template/Interface/illuminated_staging_lunaris_seal.webp")
const MISSION_ICON := preload("res://assets/template/Interface/illuminated_staging_mission.webp")
const EXIT_ICON := preload("res://assets/template/Interface/illuminated_staging_exit.webp")
const SETTINGS_ICON := preload("res://assets/template/Interface/illuminated_staging_settings.webp")
const STATUS_DIAMOND := preload("res://assets/template/Interface/illuminated_staging_status_diamond.webp")
const AETHER_ICON := preload("res://assets/template/Interface/illuminated_resource_aether.webp")
const SIGIL_ICON := preload("res://assets/template/Interface/illuminated_resource_sigil.webp")
const STAMINA_ICON := preload("res://assets/template/Interface/illuminated_resource_stamina.webp")

const GOLD := Color("d9b96e")
const BRIGHT_GOLD := Color("f0d89a")
const MOON_CYAN := Color("91eaf1")
const IVORY := Color("f5efe1")
const MUTED := Color("aebfd0")
const INK := Color("07111c")
const PANEL_FILL := Color("07111c")
const CARD_FILL := Color("0b1827")
const CHIP_FILL := Color("13263b")
const NAV_FILL := Color("091522")
const SURFACE_BORDER_WIDTH := 3
const SURFACE_CORNER_RADIUS := 14
const BUTTON_CORNER_RADIUS := 12

static func body_font() -> Font:
	return BODY_FONT


static func display_font() -> Font:
	return DISPLAY_FONT


static func apply_body_type(
	control: Control,
	size: int,
	color: Color = IVORY,
) -> void:
	control.add_theme_font_override(&"font", body_font())
	control.add_theme_font_size_override(&"font_size", size)
	control.add_theme_color_override(&"font_color", color)


static func apply_display_type(
	control: Control,
	size: int,
	color: Color = IVORY,
	weight: int = 520,
) -> void:
	control.add_theme_font_override(&"font", TITLE_FONT if weight >= 650 else DISPLAY_FONT)
	control.add_theme_font_size_override(&"font_size", size)
	control.add_theme_color_override(&"font_color", color)


## Compatibility-named helpers now return code-native solid surfaces. Keeping the
## entry points avoids coupling screens to the presentation migration.
static func command_deck_style(_modulate: Color = Color.WHITE) -> StyleBoxFlat:
	return _solid_style(
		PANEL_FILL, GOLD, Vector4(48.0, 36.0, 48.0, 36.0), SURFACE_CORNER_RADIUS,
	)


static func mission_card_style(_modulate: Color = Color.WHITE) -> StyleBoxFlat:
	return _solid_style(
		CARD_FILL, GOLD, Vector4(48.0, 48.0, 48.0, 48.0), SURFACE_CORNER_RADIUS,
	)


static func operation_tile_style(_modulate: Color = Color.WHITE) -> StyleBoxFlat:
	return _solid_style(
		CARD_FILL, MOON_CYAN, Vector4(28.0, 16.0, 28.0, 16.0), SURFACE_CORNER_RADIUS,
	)


static func primary_button_style(
	fill: Color = GOLD,
	edge: Color = BRIGHT_GOLD,
) -> StyleBoxFlat:
	var style := clean_button_style(fill, edge, BUTTON_CORNER_RADIUS)
	style.content_margin_left = 12.0
	style.content_margin_top = 12.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 12.0
	return style


static func ornate_primary_button_style(_modulate: Color = Color.WHITE) -> StyleBoxFlat:
	return primary_button_style()


static func clean_button_style(
	fill: Color,
	edge: Color,
	corner_radius: int = BUTTON_CORNER_RADIUS,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(SURFACE_BORDER_WIDTH)
	style.set_corner_radius_all(maxi(corner_radius, BUTTON_CORNER_RADIUS))
	style.content_margin_left = 24.0
	style.content_margin_top = 10.0
	style.content_margin_right = 24.0
	style.content_margin_bottom = 10.0
	return style


static func resource_chip_style(_modulate: Color = Color.WHITE) -> StyleBoxFlat:
	return _solid_style(CHIP_FILL, GOLD, Vector4.ZERO, BUTTON_CORNER_RADIUS)


static func navbar_style(_modulate: Color = Color.WHITE) -> StyleBoxFlat:
	return _solid_style(NAV_FILL, GOLD, Vector4.ZERO, SURFACE_CORNER_RADIUS)


static func company_hud_plate_style(_modulate: Color = Color.WHITE) -> StyleBoxFlat:
	return _solid_style(
		PANEL_FILL, GOLD, Vector4(20.0, 14.0, 20.0, 14.0), SURFACE_CORNER_RADIUS,
	)


static func company_navigation_rail_style(
	_modulate: Color = Color.WHITE,
) -> StyleBoxFlat:
	return _solid_style(
		NAV_FILL, GOLD, Vector4(24.0, 64.0, 24.0, 36.0), SURFACE_CORNER_RADIUS,
	)


static func golden_focus_tint_style(
	corner_radius: int = BUTTON_CORNER_RADIUS,
	_alpha: float = 0.0,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = BRIGHT_GOLD
	style.set_border_width_all(SURFACE_BORDER_WIDTH + 1)
	style.set_corner_radius_all(maxi(corner_radius, BUTTON_CORNER_RADIUS))
	style.set_expand_margin_all(2.0)
	style.draw_center = false
	return style


## Compatibility alias for existing callers. Keyboard/controller focus is a
## plain high-contrast outline rather than another decorative surface.
static func transparent_focus_style(_color: Color = MOON_CYAN) -> StyleBoxFlat:
	return golden_focus_tint_style()


static func _solid_style(
	fill: Color,
	edge: Color,
	content_margins: Vector4,
	corner_radius: int,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(SURFACE_BORDER_WIDTH)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = content_margins.x
	style.content_margin_top = content_margins.y
	style.content_margin_right = content_margins.z
	style.content_margin_bottom = content_margins.w
	return style
