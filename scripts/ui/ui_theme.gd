class_name UiTheme
extends RefCounted
## Builds the whole game Theme in code: paper panels, sticker-style buttons,
## sliders and focus rings. Variations: CoralButton, PaperButton, RoundButton,
## PillPanel, InkPanel, TitleLabel, HeadingLabel, SmallLabel, CreamLabel.

static var display_font: Font
static var bold_font: Font
static var regular_font: Font


static func build(regular: Font, medium: Font, bold: Font, display: Font) -> Theme:
	regular_font = regular
	bold_font = bold
	display_font = display
	var t := Theme.new()
	t.default_font = regular
	t.default_font_size = 20

	# ---------- Labels
	t.set_color("font_color", "Label", Palette.INK)
	t.set_font_size("font_size", "Label", 20)
	_label_variant(t, "TitleLabel", display, 56, Palette.CREAM, Palette.INK, 14)
	_label_variant(t, "HeadingLabel", display, 32, Palette.INK, Color(0, 0, 0, 0), 0)
	_label_variant(t, "CreamLabel", bold, 20, Palette.CREAM, Palette.INK, 7)
	_label_variant(t, "SmallLabel", regular, 16, Palette.INK_SOFT, Color(0, 0, 0, 0), 0)
	_label_variant(t, "HudLabel", display, 26, Palette.INK, Color(0, 0, 0, 0), 0)
	t.set_font("normal_font", "RichTextLabel", regular)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_color("default_color", "RichTextLabel", Palette.INK)
	t.set_font_size("normal_font_size", "RichTextLabel", 18)
	t.set_font_size("bold_font_size", "RichTextLabel", 18)

	# ---------- Buttons
	_button_type(t, "Button", Palette.MOSS, Palette.MOSS_LIGHT, Palette.MOSS_DARK, Palette.CREAM, display, 24)
	_button_type(t, "CoralButton", Palette.CORAL, Palette.CORAL_LIGHT, Palette.CORAL_DARK, Palette.CREAM, display, 26)
	_button_type(t, "PaperButton", Palette.PAPER, Palette.CREAM, Palette.PAPER_DARK, Palette.INK, display, 22)
	_button_type(t, "RoundButton", Palette.PAPER, Palette.CREAM, Palette.PAPER_DARK, Palette.INK, display, 24, 40)
	for v in ["CoralButton", "PaperButton", "RoundButton"]:
		t.set_type_variation(v, "Button")

	# ---------- Panels
	var paper_tex := load("res://assets/mg/ui/panel.png") as Texture2D
	if paper_tex != null:
		var sb := StyleBoxTexture.new()
		sb.texture = paper_tex
		sb.set_texture_margin_all(44)
		sb.set_content_margin_all(34)
		t.set_stylebox("panel", "PanelContainer", sb)
	else:
		t.set_stylebox("panel", "PanelContainer", _flat(Palette.PAPER, Palette.INK, 4, 22))
	var pill := _flat(Palette.CREAM, Palette.INK, 3, 22)
	pill.shadow_color = Color(Palette.INK, 0.45)
	pill.shadow_offset = Vector2(0, 4)
	pill.shadow_size = 1
	pill.content_margin_left = 14
	pill.content_margin_right = 16
	pill.content_margin_top = 4
	pill.content_margin_bottom = 4
	t.set_stylebox("panel", "PillPanel", pill)
	t.set_type_variation("PillPanel", "PanelContainer")
	var ink := _flat(Color(Palette.INK, 0.82), Color(Palette.CREAM, 0.35), 2, 18)
	ink.set_content_margin_all(14)
	t.set_stylebox("panel", "InkPanel", ink)
	t.set_type_variation("InkPanel", "PanelContainer")
	var card := _flat(Palette.CREAM, Palette.INK, 3, 16)
	card.set_content_margin_all(12)
	t.set_stylebox("panel", "CardPanel", card)
	t.set_type_variation("CardPanel", "PanelContainer")

	# ---------- Slider
	var groove := _flat(Palette.PAPER_DARK, Palette.INK, 3, 10)
	groove.content_margin_top = 7
	groove.content_margin_bottom = 7
	t.set_stylebox("slider", "HSlider", groove)
	var fill := _flat(Palette.MOSS, Palette.INK, 3, 10)
	fill.content_margin_top = 7
	fill.content_margin_bottom = 7
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := _circle_texture(30, Palette.CREAM, Palette.INK)
	var knob_hot := _circle_texture(30, Palette.AMBER_LIGHT, Palette.INK)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob_hot)
	t.set_icon("grabber_disabled", "HSlider", knob)
	var focus := _focus_box()
	t.set_stylebox("focus", "HSlider", focus)
	t.set_stylebox("focus", "Button", focus)
	return t


static func _label_variant(t: Theme, name: String, font: Font, size: int, color: Color, outline: Color, outline_size: int) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)
	t.set_color("font_outline_color", name, outline)
	t.set_constant("outline_size", name, outline_size)
	t.set_color("font_shadow_color", name, Color(0, 0, 0, 0))


static func _button_type(t: Theme, type: String, base: Color, hover: Color, press: Color, text: Color, font: Font, size: int, radius: int = 18) -> void:
	var normal := _button_box(base, radius, 0)
	var hot := _button_box(hover, radius, 0)
	var down := _button_box(press, radius, 3)
	var off := _button_box(base.lerp(Palette.GREY, 0.65), radius, 0)
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hot)
	t.set_stylebox("pressed", type, down)
	t.set_stylebox("hover_pressed", type, down)
	t.set_stylebox("disabled", type, off)
	t.set_stylebox("focus", type, _focus_box(radius))
	t.set_font("font", type, font)
	t.set_font_size("font_size", type, size)
	t.set_color("font_color", type, text)
	t.set_color("font_hover_color", type, text)
	t.set_color("font_pressed_color", type, text)
	t.set_color("font_focus_color", type, text)
	t.set_color("font_hover_pressed_color", type, text)
	t.set_color("font_disabled_color", type, Color(text, 0.55))
	var light_text := text.get_luminance() > 0.5
	t.set_color("font_outline_color", type, Palette.INK if light_text else Color(0, 0, 0, 0))
	t.set_constant("outline_size", type, 6 if light_text else 0)
	t.set_constant("h_separation", type, 10)
	t.set_constant("icon_max_width", type, 44)


static func _button_box(color: Color, radius: int, press_offset: int) -> StyleBoxFlat:
	var sb := _flat(color, Palette.INK, 3, radius)
	sb.shadow_color = Color(Palette.INK, 0.85)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, 5 - press_offset)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 8 + press_offset
	sb.content_margin_bottom = 10 - press_offset
	# Soft inner highlight band suggests a painted, rounded sticker.
	sb.border_blend = false
	return sb


static func _focus_box(radius: int = 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Palette.AMBER_LIGHT
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(radius + 4)
	sb.set_expand_margin_all(6)
	return sb


static func _flat(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


static func _circle_texture(size: int, fill: Color, border: Color) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var col := Color(0, 0, 0, 0)
			if d <= c:
				col = border
			if d <= c - 3.0:
				col = fill
			if d > c - 1.0 and d <= c:
				col.a = clampf(c - d + 0.0, 0.0, 1.0) * border.a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
