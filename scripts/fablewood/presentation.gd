class_name FablewoodPresentation
extends RefCounted
const TITLE := preload("res://assets/template/World/illuminated_title.webp")
const BACKDROP := preload("res://assets/template/World/illuminated_backdrop.webp")
const ROOT := preload("res://assets/template/World/illuminated_root_tile.webp")
const PATH := preload("res://assets/template/World/illuminated_path_tile.webp")
const PAD := preload("res://assets/template/World/illuminated_build_pad.webp")
const VAULT := preload("res://assets/template/World/illuminated_seed_vault.webp")
const GATE := preload("res://assets/template/World/illuminated_ink_gate.webp")
const SEED := preload("res://assets/template/Interface/illuminated_seed_icon.webp")
const CHAPTER_ACCENT := preload("res://assets/template/Interface/illuminated_chapter_accent.webp")
const RESULT_ACCENT := preload("res://assets/template/Interface/illuminated_result_accent.webp")
const GUARDIANS := {
"fire":[preload("res://assets/template/Guardians/illuminated_fire_1.webp"),preload("res://assets/template/Guardians/illuminated_fire_2.webp"),preload("res://assets/template/Guardians/illuminated_fire_3.webp")],
"frost":[preload("res://assets/template/Guardians/illuminated_frost_1.webp"),preload("res://assets/template/Guardians/illuminated_frost_2.webp"),preload("res://assets/template/Guardians/illuminated_frost_3.webp")],
"storm":[preload("res://assets/template/Guardians/illuminated_storm_1.webp"),preload("res://assets/template/Guardians/illuminated_storm_2.webp"),preload("res://assets/template/Guardians/illuminated_storm_3.webp")],
"earth":[preload("res://assets/template/Guardians/illuminated_earth_1.webp"),preload("res://assets/template/Guardians/illuminated_earth_2.webp"),preload("res://assets/template/Guardians/illuminated_earth_3.webp")]
}
const ENEMIES := {&"goblin":preload("res://assets/template/InvadersIlluminated/goblin/icon.webp"),&"orc":preload("res://assets/template/InvadersIlluminated/orc/icon.webp"),&"troll":preload("res://assets/template/InvadersIlluminated/troll/icon.webp"),&"dragon":preload("res://assets/template/InvadersIlluminated/dragon/icon.webp")}
const IDS: Array[StringName] = [&"caster_1", &"sniper_1", &"recruit", &"guard_1"]
const COLORS := {"fire":Color("e88750"),"frost":Color("a5d8df"),"storm":Color("baa7de"),"earth":Color("b79d65")}
const INK := Color("202433")
const PANEL := Color("233831")
const PANEL_DEEP := Color("182a25")
const PANEL_INSET := Color("1d302a")
const BORDER := Color("74816b")
const GOLD := Color("e8bc68")
const TEXT := Color("f2efdf")
const MUTED := Color("bbc9bb")
const BODY_FONT: Font = preload("res://assets/template/fonts/ui_regular.tres")
const DISPLAY_FONT: Font = preload("res://assets/template/fonts/ui_medium.tres")
const TITLE_FONT: Font = preload("res://assets/template/fonts/ui_bold.tres")

static func t(key: String,values:Dictionary={}) -> String:
	return (Engine.get_main_loop() as SceneTree).root.get_node("I18n").t(StringName("fw."+key), key).format(values)

static func box(fill: Color = PANEL, border: Color = BORDER, width: int = 1, radius: int = 12) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 12
	b.content_margin_bottom = 12
	return b

static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = BODY_FONT
	th.default_font_size = 18
	th.set_font("font", "Button", DISPLAY_FONT)
	th.set_font("normal_font", "RichTextLabel", BODY_FONT)
	th.set_font("bold_font", "RichTextLabel", TITLE_FONT)
	th.set_color("font_color", "Label", TEXT)
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", GOLD)
	th.set_color("font_disabled_color", "Button", Color("72727c"))
	th.set_stylebox("normal", "Button", box(PANEL))
	th.set_stylebox("hover", "Button", box(Color("344d3e"), GOLD, 2))
	th.set_stylebox("pressed", "Button", box(Color("3f5035"), GOLD, 2))
	th.set_stylebox("focus", "Button", box(Color.TRANSPARENT, GOLD, 2))
	th.set_stylebox("disabled", "Button", box(PANEL_DEEP, Color("43564b")))
	th.set_stylebox("panel", "PanelContainer", box())
	th.set_stylebox("panel", "Panel", box())
	th.set_constant("separation", "VBoxContainer", 12)
	th.set_constant("separation", "HBoxContainer", 12)
	return th
