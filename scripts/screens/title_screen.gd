extends Control
## Title: animated key art, logo, main menu and language toggle.

const MobileLayout := preload("res://scripts/ui/mobile_layout.gd")

var _art: TextureRect
var _logo: TextureRect
var _menu: VBoxContainer
var _buttons: Array = []
var _lang_btn: GameButton
var _version_label: Label
var _progress: Label
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_art = TextureRect.new()
	_art.texture = GameData.tex("ui/title_art.jpg")
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_art.pivot_offset = Vector2(640, 360)

	# Left-side soft shade so the menu reads over the art.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.1, 0.07, 0.03, 0.72))
	grad.set_color(1, Color(0.1, 0.07, 0.03, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.62
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var motes := AmbientMotes.new()
	motes.amount = 40
	motes.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(motes)

	_logo = TextureRect.new()
	_logo.texture = GameData.tex("ui/logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.position = Vector2(46, 26)
	_logo.size = Vector2(560, 283)
	_logo.pivot_offset = _logo.size / 2.0
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)

	var menu := UiKit.vbox(14)
	_menu = menu
	menu.position = Vector2(150, 330)
	menu.custom_minimum_size = Vector2(340, 0)
	add_child(menu)
	var play := UiKit.button("", _on_play, "CoralButton", Vector2(340, 70))
	play.name = "PlayButton"
	play.add_theme_font_size_override("font_size", 32)
	var settings := UiKit.button("", _on_settings, "", Vector2(340, 58))
	var help := UiKit.button("", _on_help, "", Vector2(340, 58))
	menu.add_child(play)
	menu.add_child(settings)
	menu.add_child(help)
	_buttons = [play, settings, help]
	_progress = UiKit.label("", "CreamLabel", 20, HORIZONTAL_ALIGNMENT_CENTER)
	_progress.custom_minimum_size = Vector2(340, 34)
	menu.add_child(_progress)

	_lang_btn = UiKit.button("", _on_lang, "PaperButton", Vector2(150, 50))
	UiKit.place(_lang_btn, Vector2(1, 0), Vector2(-176, 22), Vector2(150, 50))
	add_child(_lang_btn)

	_buttons.append(_lang_btn)
	_version_label = UiKit.label(GameVersion.display(), "SmallLabel", 14)
	_version_label.modulate.a = 0.82
	UiKit.place(_version_label, Vector2(0, 1), Vector2(22, -42), Vector2(420, 28))
	add_child(_version_label)
	UiKit.chain_focus([play, settings, help])

	Loc.changed.connect(_refresh)
	get_viewport().size_changed.connect(_layout_mobile)
	_refresh()
	_layout_mobile()
	for i in menu.get_child_count():
		UiKit.pop_in(menu.get_child(i), 0.15 + i * 0.07)
	Sound.play_music("title", 1.2)
	Sound.prepare_music.call_deferred("battle")
	if Controls.uses_focus():
		play.grab_focus.call_deferred()


func _layout_mobile() -> void:
	if not MobileLayout.is_mobile_browser() or _menu == null:
		return
	var s := get_viewport_rect().size
	var inset := MobileLayout.edge_inset()
	# Keep the menu in the left safe area and enlarge its touch targets without
	# changing the authored desktop composition.
	_menu.position = Vector2(inset + 8.0, maxf(260.0, s.y * 0.43))
	_menu.custom_minimum_size = Vector2(minf(380.0, s.x * 0.42), 0)
	_logo.position = Vector2(inset, 14.0)
	_logo.size = Vector2(minf(560.0, s.x * 0.48), 270.0)
	UiKit.place(_lang_btn, Vector2(1, 0), Vector2(-inset - 158.0, inset), Vector2(150, 58))


func _refresh() -> void:
	_buttons[0].text = Loc.t("menu.play")
	_buttons[1].text = Loc.t("menu.settings")
	_buttons[2].text = Loc.t("menu.help")
	_lang_btn.text = "EN" if Loc.lang == "zh" else "中文"
	var stars := 0
	for level: Dictionary in GameData.levels:
		stars += Save.level_record(str(level.get("id", ""))).stars
	_progress.text = Loc.t("menu.stars", {"n": stars, "max": GameData.level_count() * 3})


func _process(delta: float) -> void:
	_t += delta
	_art.scale = Vector2.ONE * (1.04 + 0.02 * sin(_t * 0.25))
	_logo.position.y = 26 + sin(_t * 1.6) * 4.0
	_logo.rotation = sin(_t * 1.1) * 0.012


func _unhandled_input(event: InputEvent) -> void:
	if Main_has_modal():
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept"):
		if get_viewport().gui_get_focus_owner() == null:
			_buttons[0].grab_focus()
			get_viewport().set_input_as_handled()


func Main_has_modal() -> bool:
	var m := get_tree().root.get_node_or_null("Main")
	return m != null and m.has_modal()


func _on_play() -> void:
	get_tree().root.get_node("Main").go("map_select")


func _on_settings() -> void:
	get_tree().root.get_node("Main").open_settings(_restore_focus.bind(1))


func _on_help() -> void:
	get_tree().root.get_node("Main").open_help(_restore_focus.bind(2))


func _restore_focus(i: int) -> void:
	_refresh()
	if Controls.uses_focus() and is_inside_tree():
		_buttons[i].grab_focus()


func _on_lang() -> void:
	Loc.toggle()
