extends Control
## Map select: three level cards with minimap, difficulty, waves and best record.

var _cards: Array = []
var _back: GameButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = GameData.tex("maps/ground_1.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.55, 0.6, 0.5)
	add_child(bg)
	var motes := AmbientMotes.new()
	motes.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(motes)

	var title := UiKit.label(Loc.t("select.title"), "TitleLabel", 50, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(title, Vector2(0.5, 0), Vector2(-300, 26), Vector2(600, 70))
	add_child(title)

	_back = UiKit.button(Loc.t("common.back"), _on_back, "PaperButton", Vector2(150, 52))
	_back.position = Vector2(24, 26)
	add_child(_back)

	var row := UiKit.hbox(26, BoxContainer.ALIGNMENT_CENTER)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_top = 120
	row.offset_bottom = -40
	add_child(row)
	for i in GameData.level_count():
		var card := _make_card(i)
		row.add_child(card)
		_cards.append(card)
		UiKit.pop_in(card, 0.08 + i * 0.08)
	for i in _cards.size():
		var c: Control = _cards[i]
		c.focus_neighbor_left = c.get_path_to(_cards[(i - 1 + _cards.size()) % _cards.size()])
		c.focus_neighbor_right = c.get_path_to(_cards[(i + 1) % _cards.size()])
		c.focus_neighbor_top = c.get_path_to(_back)
	_back.focus_neighbor_bottom = _back.get_path_to(_cards[0])
	if Controls.uses_focus():
		_focus_default.call_deferred()


func _focus_default() -> void:
	# Focus the furthest unlocked map.
	var idx := 0
	for i in _cards.size():
		if Save.is_level_unlocked(i):
			idx = i
	_cards[idx].grab_focus()


func _make_card(i: int) -> GameButton:
	var level: Dictionary = GameData.levels[i]
	var unlocked := Save.is_level_unlocked(i)
	var rec := Save.level_record(str(level.get("id", "")))
	var card := GameButton.new()
	card.theme_type_variation = "PaperButton"
	card.custom_minimum_size = Vector2(360, 470)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.pressed.connect(_on_pick.bind(i))
	card.click_sound = "click" if unlocked else "invalid"
	var v := UiKit.vbox(8)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_right = -18
	v.offset_top = 18
	v.offset_bottom = -16
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var mini := LevelMinimap.new()
	mini.level = level
	mini.locked = not unlocked
	mini.custom_minimum_size = Vector2(324, 178)
	v.add_child(mini)
	var chapter := UiKit.label(Loc.t("select.chapter", {"n": i + 1}), "SmallLabel", 16)
	v.add_child(chapter)
	var name := UiKit.label(Loc.t(str(level.get("name", ""))), "HeadingLabel", 30)
	v.add_child(name)
	var desc := UiKit.label(Loc.t(str(level.get("desc", ""))), "SmallLabel", 16)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(324, 48)
	v.add_child(desc)
	var info := UiKit.hbox(10)
	info.add_child(UiKit.label(Loc.t("select.waves", {"n": level.get("waves", []).size()}), "", 18))
	var spacer_h := Control.new()
	spacer_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(spacer_h)
	info.add_child(UiKit.label(Loc.t("select.difficulty"), "", 18))
	for d in 3:
		var pip := UiKit.icon(GameData.tower_tex("puff_1"), 26)
		if d >= int(level.get("difficulty", 1)):
			pip.modulate = Color(0.2, 0.15, 0.1, 0.3)
		info.add_child(pip)
	v.add_child(info)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	if unlocked:
		var stars := StarRow.new()
		stars.star_size = 36
		stars.filled = rec.stars
		stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(stars)
		var best := UiKit.label(Loc.t("select.best", {"score": rec.score}) if rec.score > 0 else Loc.t("select.new"), "SmallLabel", 16, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(best)
	else:
		var lock := UiKit.label(Loc.t("select.locked"), "", 18, HORIZONTAL_ALIGNMENT_CENTER)
		lock.add_theme_color_override("font_color", Palette.CORAL_DARK)
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock.custom_minimum_size = Vector2(324, 60)
		v.add_child(lock)
	for c in v.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _on_pick(i: int) -> void:
	if not Save.is_level_unlocked(i):
		var c: Control = _cards[i]
		var tw := create_tween()
		for k in 4:
			tw.tween_property(c, "position:x", c.position.x + (8 if k % 2 == 0 else -8), 0.04)
		tw.tween_property(c, "position:x", c.position.x, 0.04)
		return
	get_tree().root.get_node("Main").go("battle", {"level": i})


func _on_back() -> void:
	get_tree().root.get_node("Main").go("title")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept")) and get_viewport().gui_get_focus_owner() == null:
		_focus_default()
		get_viewport().set_input_as_handled()
