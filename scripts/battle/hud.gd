extends CanvasLayer
## Battle HUD: resources, wave control, build bar, radial build ring, tower
## upgrade panel, banners, combo callouts, pause menu, results and coach tips.

const Coach := preload("res://scripts/battle/coach.gd")

var battle: BattleScene

var _root: Control
var _lives_lbl: Label
var _gold_lbl: Label
var _wave_lbl: Label
var _gold_icon: TextureRect
var _wave_btn: GameButton
var _wave_preview: HBoxContainer
var _speed_btn: GameButton
var _pause_btn: GameButton
var _build_cards: Array = []
var _hint: Label
var _panel: PanelContainer
var _panel_for: Tower
var _panel_level := ""
var _ring: Control
var _ring_buttons: Array = []
var _toasts: VBoxContainer
var _combo_lbl: Label
var _banner: Control
var _vignette: TextureRect
var _modal: Control
var _coach: Node
var _shown_gold := 0.0
var _last_preview_wave := -2


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_vignette()
	_build_top_bar()
	_build_wave_controls()
	_build_build_bar()
	_build_hint()
	_toasts = UiKit.vbox(6)
	UiKit.place(_toasts, Vector2(0.5, 0), Vector2(-260, 150), Vector2(520, 0))
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(_toasts)
	_combo_lbl = UiKit.label("", "TitleLabel", 40, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_combo_lbl, Vector2(1, 0.5), Vector2(-300, -170), Vector2(280, 60))
	_combo_lbl.pivot_offset = Vector2(140, 30)
	_combo_lbl.modulate.a = 0.0
	_combo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_combo_lbl)
	_shown_gold = battle.gold
	Controls.device_changed.connect(func(_d: String) -> void: _refresh_hint())
	refresh_stats()
	if battle.level_index == 0 and not Save.tutorial_done():
		_coach = Coach.new()
		_coach.battle = battle
		_coach.hud = self
		_root.add_child(_coach)


# ------------------------------------------------------------ construction

func _build_vignette() -> void:
	_vignette = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.1, 0.05, 0.0))
	g.set_color(1, Color(0.9, 0.1, 0.05, 0.6))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	gt.width = 256
	gt.height = 256
	_vignette.texture = gt
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_root.add_child(_vignette)


func _stat_pill(icon_path: String, color: Color) -> Array:
	var pill := UiKit.panel("PillPanel")
	var h := UiKit.hbox(6)
	pill.add_child(h)
	var ic := UiKit.icon(GameData.tex(icon_path), 34)
	h.add_child(ic)
	var l := UiKit.label("0", "HudLabel", 26)
	l.add_theme_color_override("font_color", color)
	l.custom_minimum_size = Vector2(54, 0)
	h.add_child(l)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return [pill, l, ic]


func _build_top_bar() -> void:
	var bar := UiKit.hbox(10)
	bar.position = Vector2(14, 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	var lives := _stat_pill("ui/icon_seed.png", Palette.CORAL_DARK)
	_lives_lbl = lives[1]
	bar.add_child(lives[0])
	var gold := _stat_pill("ui/icon_coin.png", Color("9a6410"))
	_gold_lbl = gold[1]
	_gold_icon = gold[2]
	_gold_lbl.custom_minimum_size = Vector2(70, 0)
	bar.add_child(gold[0])
	var wave := _stat_pill("ui/icon_wave.png", Palette.INK)
	_wave_lbl = wave[1]
	_wave_lbl.custom_minimum_size = Vector2(86, 0)
	bar.add_child(wave[0])


func _build_wave_controls() -> void:
	var box := UiKit.hbox(10, BoxContainer.ALIGNMENT_END)
	UiKit.place(box, Vector2(1, 0), Vector2(-640, 8), Vector2(626, 64))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_wave_preview = UiKit.hbox(2, BoxContainer.ALIGNMENT_END)
	_wave_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_wave_preview)
	_wave_btn = UiKit.button("", battle.call_wave, "CoralButton", Vector2(220, 58))
	_wave_btn.focus_mode = Control.FOCUS_NONE
	_wave_btn.add_theme_font_size_override("font_size", 21)
	_wave_btn.click_sound = ""
	box.add_child(_wave_btn)
	_speed_btn = UiKit.button("x1", battle.cycle_speed, "RoundButton", Vector2(64, 58))
	_speed_btn.focus_mode = Control.FOCUS_NONE
	_speed_btn.click_sound = ""
	box.add_child(_speed_btn)
	_pause_btn = UiKit.button("II", open_pause, "RoundButton", Vector2(64, 58))
	_pause_btn.focus_mode = Control.FOCUS_NONE
	box.add_child(_pause_btn)


func _build_build_bar() -> void:
	var bar := UiKit.hbox(10, BoxContainer.ALIGNMENT_CENTER)
	UiKit.place(bar, Vector2(0.5, 1), Vector2(-260, -98), Vector2(520, 92))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	for i in GameData.tower_order.size():
		var tid := str(GameData.tower_order[i])
		var card := GameButton.new()
		card.theme_type_variation = "PaperButton"
		card.custom_minimum_size = Vector2(118, 90)
		card.focus_mode = Control.FOCUS_NONE
		card.click_sound = ""
		card.pressed.connect(battle.begin_build.bind(tid))
		var icon := UiKit.icon(GameData.tower_tex(str(GameData.tower_stats(tid, "1").get("sprite", ""))), 58)
		icon.position = Vector2(30, 2)
		icon.size = Vector2(58, 58)
		card.add_child(icon)
		var cost := UiKit.label(str(battle.tower_cost(tid)), "HudLabel", 20, HORIZONTAL_ALIGNMENT_CENTER)
		cost.position = Vector2(26, 58)
		cost.size = Vector2(80, 26)
		cost.add_theme_color_override("font_color", Color("8a560c"))
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cost)
		var coin := UiKit.icon(GameData.tex("ui/icon_coin.png"), 20)
		coin.position = Vector2(14, 61)
		coin.size = Vector2(20, 20)
		card.add_child(coin)
		var key := UiKit.label(str(i + 1), "CreamLabel", 15, HORIZONTAL_ALIGNMENT_CENTER)
		key.position = Vector2(4, 2)
		key.size = Vector2(22, 22)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(key)
		card.tooltip_text = ""
		bar.add_child(card)
		_build_cards.append({"card": card, "id": tid, "cost": cost, "key": key})


func _build_hint() -> void:
	_hint = UiKit.label("", "CreamLabel", 14)
	UiKit.place(_hint, Vector2(0, 1), Vector2(12, -60), Vector2(350, 52))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint.modulate.a = 0.85
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)
	_refresh_hint()


func _refresh_hint() -> void:
	match Controls.device:
		"gamepad": _hint.text = Loc.t("hint.gamepad")
		"keyboard": _hint.text = Loc.t("hint.keyboard")
		"touch": _hint.text = ""
		_: _hint.text = Loc.t("hint.mouse")
	for c: Dictionary in _build_cards:
		c.key.visible = Controls.device != "touch" and Controls.device != "gamepad"


# ------------------------------------------------------------ per-frame

func _process(delta: float) -> void:
	_shown_gold = move_toward(_shown_gold, battle.gold, maxf(40.0, absf(battle.gold - _shown_gold) * 8.0) * delta)
	_gold_lbl.text = str(int(round(_shown_gold)))
	_update_wave_button()
	if _panel != null and is_instance_valid(_panel_for):
		_position_panel()
		if _panel_level != _panel_for.level_key:
			_rebuild_panel()
		_update_panel_affordability()


func refresh_stats() -> void:
	_lives_lbl.text = str(battle.lives)
	_wave_lbl.text = "%d/%d" % [maxi(1, battle.wave_index + 1), battle.waves.size()]
	_speed_btn.text = battle.speed_label()
	_speed_btn.modulate = Color.WHITE if battle.speed_index == 0 else Color(1.0, 0.92, 0.6)
	for c: Dictionary in _build_cards:
		var cost := battle.tower_cost(c.id)
		var ok: bool = battle.gold >= cost
		(c.card as Control).modulate = Color.WHITE if ok else Color(0.72, 0.68, 0.62, 0.85)
		var active: bool = battle.build_tower == c.id
		(c.card as Control).position.y = -12.0 if active else 0.0
		(c.cost as Label).add_theme_color_override("font_color", Color("8a560c") if ok else Palette.CORAL_DARK)
	if _last_preview_wave != battle.wave_index:
		_last_preview_wave = battle.wave_index
		for c in _wave_preview.get_children():
			c.queue_free()
		for id in battle.next_wave_types():
			var def: Dictionary = GameData.enemies.get(id, {})
			var pv := UiKit.panel("PillPanel")
			pv.custom_minimum_size = Vector2(44, 44)
			var ic := UiKit.icon(GameData.enemy_tex(str(def.get("sprite", id))), 34)
			pv.add_child(ic)
			if bool(def.get("flying", false)):
				pv.self_modulate = Color(0.75, 0.88, 1.0)
			if bool(def.get("boss", false)):
				pv.self_modulate = Color(1.0, 0.7, 0.62)
			_wave_preview.add_child(pv)


func _update_wave_button() -> void:
	var can: bool = battle.can_call_wave()
	_wave_btn.disabled = not can
	_wave_preview.visible = can
	if battle.state == "prep":
		_wave_btn.text = Loc.t("hud.start_wave") + "  [%s]" % Controls.glyph("wave") if Controls.device != "touch" else Loc.t("hud.start_wave")
		var pulse := 1.0 + 0.05 * sin(Time.get_ticks_msec() / 160.0)
		_wave_btn.scale = Vector2(pulse, pulse)
	elif can:
		var bonus := int(round(battle.countdown * float(GameData.balance.get("early_call_gold_per_second", 2))))
		_wave_btn.text = Loc.t("hud.next_wave", {"s": int(ceil(battle.countdown)), "gold": bonus})
		_wave_btn.scale = Vector2.ONE
	elif battle.wave_index >= battle.waves.size() - 1:
		_wave_btn.text = Loc.t("hud.final_wave")
	else:
		_wave_btn.text = Loc.t("hud.wave_incoming")


# ------------------------------------------------------------ selection panel

func on_selection_changed() -> void:
	refresh_stats()
	var t: Tower = battle.selected
	if t == null:
		if _panel != null:
			_panel.queue_free()
			_panel = null
		_panel_for = null
		battle.hover_upgrade_range = 0.0
		return
	_panel_for = t
	_rebuild_panel()
	if Controls.uses_focus():
		_focus_panel.call_deferred()


func _focus_panel() -> void:
	if _panel == null:
		return
	var first := _find_button(_panel)
	if first != null:
		first.grab_focus()


func _find_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and not c.disabled and c.focus_mode != Control.FOCUS_NONE:
			return c
		var inner := _find_button(c)
		if inner != null:
			return inner
	return null


func _rebuild_panel() -> void:
	var had_focus := _panel != null and _panel.get_viewport().gui_get_focus_owner() != null and _panel.is_ancestor_of(_panel.get_viewport().gui_get_focus_owner())
	if _panel != null:
		_panel.queue_free()
	var t := _panel_for
	_panel_level = t.level_key
	_panel = UiKit.panel("CardPanel")
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_panel)
	var v := UiKit.vbox(6)
	_panel.add_child(v)
	var head := UiKit.hbox(8)
	var nm := UiKit.label(t.display_name(), "HeadingLabel", 24)
	head.add_child(nm)
	var tier := UiKit.label(Loc.t("panel.tier", {"n": t.tier()}), "SmallLabel", 15)
	head.add_child(tier)
	v.add_child(head)
	var desc_key := str(t.stats.get("desc", t.def.get("role", "")))
	var desc := UiKit.label(Loc.t(desc_key), "SmallLabel", 14)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	v.add_child(desc)
	v.add_child(_stats_row(t.stats, t.tower_id))
	var opts: Array = t.next_options()
	if opts.is_empty():
		var mx := UiKit.label(Loc.t("panel.max"), "", 18, HORIZONTAL_ALIGNMENT_CENTER)
		mx.add_theme_color_override("font_color", Palette.MOSS_DARK)
		v.add_child(mx)
	else:
		if opts.size() >= 2:
			var hint := UiKit.label(Loc.t("panel.choose_branch"), "SmallLabel", 14, HORIZONTAL_ALIGNMENT_CENTER)
			v.add_child(hint)
		var row := UiKit.hbox(8, BoxContainer.ALIGNMENT_CENTER)
		v.add_child(row)
		for key in opts:
			row.add_child(_upgrade_button(t, str(key), opts.size()))
	var bottom := UiKit.hbox(8, BoxContainer.ALIGNMENT_CENTER)
	var sell := UiKit.button(Loc.t("panel.sell", {"gold": t.sell_value()}), battle.sell.bind(t), "PaperButton", Vector2(150, 44))
	sell.add_theme_font_size_override("font_size", 18)
	sell.click_sound = ""
	bottom.add_child(sell)
	var close := UiKit.button(Loc.t("common.close"), battle.deselect, "PaperButton", Vector2(110, 44))
	close.add_theme_font_size_override("font_size", 18)
	bottom.add_child(close)
	v.add_child(bottom)
	_panel.reset_size()
	_position_panel()
	UiKit.pop_in(_panel)
	if had_focus or Controls.uses_focus():
		_focus_panel.call_deferred()


func _stats_row(s: Dictionary, tower_id: String) -> Control:
	var parts: Array = []
	parts.append(Loc.t("stat.damage", {"v": int(s.get("damage", 0))}))
	parts.append(Loc.t("stat.range", {"v": int(s.get("range", 0))}))
	parts.append(Loc.t("stat.rate", {"v": "%.1f" % (1.0 / maxf(0.05, float(s.get("interval", 1.0))))}))
	if s.has("slow"):
		parts.append(Loc.t("stat.slow", {"v": int(float(s.slow.pct) * 100)}))
	if s.has("pierce"):
		parts.append(Loc.t("stat.pierce", {"v": int(s.pierce)}))
	if s.has("splash"):
		parts.append(Loc.t("stat.splash", {"v": int(s.splash)}))
	if not bool(s.get("air", true)):
		parts.append(Loc.t("stat.ground_only"))
	var l := UiKit.label("  ·  ".join(parts), "", 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_color_override("font_color", Palette.INK_SOFT)
	return l


func _upgrade_button(t: Tower, key: String, count: int) -> GameButton:
	var st := GameData.tower_stats(t.tower_id, key)
	var cost := int(st.get("cost", 0))
	var b := GameButton.new()
	b.theme_type_variation = "PaperButton"
	b.click_sound = ""
	b.set_meta("cost", cost)
	var branch := key.substr(0, 1) if key.length() == 2 else ""
	var col := Palette.BRANCH_A if branch == "a" else (Palette.BRANCH_B if branch == "b" else Palette.MOSS_LIGHT)
	for state_name in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var base: StyleBox = b.get_theme_stylebox(state_name, "PaperButton")
		if base is StyleBoxFlat and state_name != "focus":
			var sb := (base as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb.bg_color = col.lerp(Palette.CREAM, 0.55 if state_name == "normal" else 0.3)
			sb.content_margin_left = 8
			sb.content_margin_right = 8
			b.add_theme_stylebox_override(state_name, sb)
	var w := 152.0 if count >= 2 else 312.0
	b.custom_minimum_size = Vector2(w, 150 if count >= 2 else 82)
	var v := UiKit.vbox(0, BoxContainer.ALIGNMENT_CENTER)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 4
	v.offset_bottom = -6
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	if count >= 2:
		var ic := UiKit.icon(GameData.tower_tex(str(st.get("sprite", ""))), 52)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var nm := UiKit.label(Loc.t(str(st.get("name", ""))), "", 16, HORIZONTAL_ALIGNMENT_CENTER)
		nm.add_theme_font_override("font", UiTheme.bold_font)
		v.add_child(nm)
		var d := UiKit.label(Loc.t(str(st.get("desc", ""))), "SmallLabel", 12, HORIZONTAL_ALIGNMENT_CENTER)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(w - 16, 0)
		d.add_theme_color_override("font_color", Palette.INK)
		v.add_child(d)
	else:
		var h := UiKit.hbox(8, BoxContainer.ALIGNMENT_CENTER)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := UiKit.icon(GameData.tower_tex(str(st.get("sprite", ""))), 46)
		h.add_child(ic)
		var tv := UiKit.vbox(0)
		var up_name := Loc.t(str(st.get("name", ""))) if st.has("name") else Loc.t("panel.upgrade")
		var nm := UiKit.label(up_name, "", 18)
		nm.add_theme_font_override("font", UiTheme.bold_font)
		tv.add_child(nm)
		var dl := UiKit.label(Loc.t(str(st.get("desc", "panel.upgrade_desc"))), "SmallLabel", 13)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(170, 0)
		tv.add_child(dl)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tv)
		v.add_child(h)
	var ch := UiKit.hbox(4, BoxContainer.ALIGNMENT_CENTER)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(UiKit.icon(GameData.tex("ui/icon_coin.png"), 20))
	var cl := UiKit.label(str(cost), "HudLabel", 19)
	cl.name = "Cost"
	ch.add_child(cl)
	if count >= 2:
		v.add_child(ch)
	else:
		(v.get_child(0) as Control).add_child(ch)
	b.set_meta("cost_label", cl)
	for c in v.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := float(st.get("range", 0))
	b.mouse_entered.connect(func() -> void: battle.hover_upgrade_range = rng)
	b.focus_entered.connect(func() -> void: battle.hover_upgrade_range = rng)
	b.mouse_exited.connect(func() -> void: battle.hover_upgrade_range = 0.0)
	b.pressed.connect(func() -> void:
		battle.try_upgrade(t, key))
	return b


func _update_panel_affordability() -> void:
	_walk_cost(_panel)


func _walk_cost(n: Node) -> void:
	for c in n.get_children():
		if c is GameButton and c.has_meta("cost"):
			var ok: bool = battle.gold >= int(c.get_meta("cost"))
			var cl: Label = c.get_meta("cost_label")
			cl.add_theme_color_override("font_color", Palette.INK if ok else Palette.CORAL_DARK)
			c.modulate = Color.WHITE if ok else Color(0.85, 0.82, 0.78)
		_walk_cost(c)


func _position_panel() -> void:
	if _panel == null or not is_instance_valid(_panel_for):
		return
	var p: Vector2 = battle.to_screen(_panel_for.position)
	var vs := _root.get_viewport_rect().size
	var sz := _panel.size
	var x := p.x + 56.0
	if x + sz.x > vs.x - 10.0:
		x = p.x - 56.0 - sz.x
	var y := clampf(p.y - sz.y * 0.5, 78.0, vs.y - sz.y - 8.0)
	_panel.position = Vector2(x, y).round()


# ------------------------------------------------------------ build ring

func open_ring(c: Vector2i) -> void:
	close_ring()
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ring)
	var center: Vector2 = battle.to_screen(battle.cell_center(c))
	var vs := _root.get_viewport_rect().size
	center.x = clampf(center.x, 96.0, vs.x - 96.0)
	center.y = clampf(center.y, 150.0, vs.y - 150.0)
	_ring.position = center
	var dirs := [Vector2(0, -86), Vector2(86, 0), Vector2(0, 86), Vector2(-86, 0)]
	_ring_buttons.clear()
	for i in GameData.tower_order.size():
		var tid := str(GameData.tower_order[i])
		var st := GameData.tower_stats(tid, "1")
		var b := GameButton.new()
		b.theme_type_variation = "RoundButton"
		b.custom_minimum_size = Vector2(84, 84)
		b.size = Vector2(84, 84)
		b.position = dirs[i % 4] - Vector2(42, 42)
		b.click_sound = ""
		var ic := UiKit.icon(GameData.tower_tex(str(st.get("sprite", ""))), 52)
		ic.position = Vector2(16, 4)
		ic.size = Vector2(52, 52)
		b.add_child(ic)
		var cost := UiKit.label(str(int(st.get("cost", 0))), "HudLabel", 18, HORIZONTAL_ALIGNMENT_CENTER)
		cost.position = Vector2(0, 54)
		cost.size = Vector2(84, 24)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ok: bool = battle.gold >= int(st.get("cost", 0))
		cost.add_theme_color_override("font_color", Color("8a560c") if ok else Palette.CORAL_DARK)
		if not ok:
			b.modulate = Color(0.8, 0.76, 0.7)
		b.add_child(cost)
		b.pressed.connect(func() -> void:
			var cell: Vector2i = battle.ring_cell
			battle.close_ring()
			battle.try_build(cell, tid))
		b.mouse_entered.connect(func() -> void: battle.ring_tower = tid)
		b.focus_entered.connect(func() -> void: battle.ring_tower = tid)
		_ring.add_child(b)
		_ring_buttons.append(b)
		b.scale = Vector2(0.3, 0.3)
		b.pivot_offset = Vector2(42, 42)
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.22).set_delay(i * 0.03).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Up/right/down/left map straight to the four buttons for gamepads.
	for i in _ring_buttons.size():
		var b: Control = _ring_buttons[i]
		b.focus_neighbor_top = b.get_path_to(_ring_buttons[0])
		b.focus_neighbor_right = b.get_path_to(_ring_buttons[1 % _ring_buttons.size()])
		b.focus_neighbor_bottom = b.get_path_to(_ring_buttons[2 % _ring_buttons.size()])
		b.focus_neighbor_left = b.get_path_to(_ring_buttons[3 % _ring_buttons.size()])
	if Controls.uses_focus():
		(_ring_buttons[0] as Control).grab_focus.call_deferred()


func close_ring() -> void:
	if _ring != null:
		_ring.queue_free()
		_ring = null
	_ring_buttons.clear()


# ------------------------------------------------------------ feedback

func toast(text: String, color: Color = Palette.CREAM) -> void:
	if _toasts.get_child_count() >= 3:
		_toasts.get_child(0).queue_free()
	var pill := UiKit.panel("InkPanel")
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := UiKit.label(text, "", 18, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_color", color)
	pill.add_child(l)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(pill)
	pill.modulate.a = 0.0
	var tw := pill.create_tween()
	tw.tween_property(pill, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.6)
	tw.tween_property(pill, "modulate:a", 0.0, 0.4)
	tw.tween_callback(pill.queue_free)


func shake_gold() -> void:
	var tw := create_tween()
	_gold_lbl.add_theme_color_override("font_color", Palette.DANGER)
	for k in 4:
		tw.tween_property(_gold_icon, "rotation", 0.3 if k % 2 == 0 else -0.3, 0.05)
	tw.tween_property(_gold_icon, "rotation", 0.0, 0.05)
	tw.tween_callback(func() -> void: _gold_lbl.add_theme_color_override("font_color", Color("9a6410")))


func flash_damage() -> void:
	_vignette.modulate.a = 0.85
	var tw := create_tween()
	tw.tween_property(_vignette, "modulate:a", 0.0, 0.6)
	_lives_lbl.pivot_offset = _lives_lbl.size / 2.0
	_lives_lbl.scale = Vector2(1.5, 1.5)
	var tw2 := create_tween()
	tw2.tween_property(_lives_lbl, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_combo(n: int, _pos: Vector2) -> void:
	_combo_lbl.text = Loc.t("hud.combo", {"n": n})
	var col := Palette.CREAM
	if n >= 20:
		col = Palette.CORAL_LIGHT
	elif n >= 10:
		col = Palette.AMBER_LIGHT
	_combo_lbl.add_theme_color_override("font_color", col)
	_combo_lbl.modulate.a = 1.0
	_combo_lbl.scale = Vector2(1.35, 1.35)
	_combo_lbl.rotation = randf_range(-0.06, 0.06)
	var tw := _combo_lbl.create_tween()
	tw.tween_property(_combo_lbl, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(_combo_lbl, "modulate:a", 0.0, 0.4)


func end_combo(n: int) -> void:
	if n >= 12:
		toast(Loc.t("hud.combo_end", {"n": n}), Palette.AMBER_LIGHT)


func show_wave_banner(index: int, boss: bool) -> void:
	if _banner != null:
		_banner.queue_free()
	_banner = Control.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_root.add_child(_banner)
	var ribbon := UiKit.panel("PillPanel")
	ribbon.self_modulate = Palette.CORAL_LIGHT if boss else Palette.CREAM
	var v := UiKit.vbox(0, BoxContainer.ALIGNMENT_CENTER)
	ribbon.add_child(v)
	var title := UiKit.label(Loc.t("hud.wave_banner", {"n": index + 1, "total": battle.waves.size()}), "HeadingLabel", 40, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(title)
	if boss:
		var sub := UiKit.label(Loc.t("hud.boss_wave"), "", 20, HORIZONTAL_ALIGNMENT_CENTER)
		sub.add_theme_font_override("font", UiTheme.bold_font)
		v.add_child(sub)
	elif index == battle.waves.size() - 1:
		v.add_child(UiKit.label(Loc.t("hud.last_wave"), "", 20, HORIZONTAL_ALIGNMENT_CENTER))
	ribbon.custom_minimum_size = Vector2(360, 0)
	_banner.add_child(ribbon)
	ribbon.reset_size()
	ribbon.position = Vector2(-ribbon.size.x / 2.0, -200)
	ribbon.pivot_offset = ribbon.size / 2.0
	ribbon.scale = Vector2(0.6, 0.6)
	ribbon.modulate.a = 0.0
	var tw := ribbon.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ribbon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ribbon, "modulate:a", 1.0, 0.2)
	tw.chain().tween_interval(1.3)
	tw.chain().tween_property(ribbon, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(_banner.queue_free)
	refresh_stats()


# ------------------------------------------------------------ pause & results

func open_pause() -> void:
	if _modal != null or battle.state == "won" or battle.state == "lost":
		return
	battle.set_paused(true)
	battle.close_ring()
	Sound.play("click")
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_modal)
	_modal.add_child(UiKit.dim(0.5))
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(440, 0)
	_modal.add_child(UiKit.center(panel))
	var v := UiKit.vbox(12)
	panel.add_child(v)
	v.add_child(UiKit.label(Loc.t("pause.title"), "HeadingLabel", 38, HORIZONTAL_ALIGNMENT_CENTER))
	var lvl := UiKit.label(Loc.t(str(battle.level.get("name", ""))) + "  ·  " + Loc.t("hud.wave_short", {"n": maxi(1, battle.wave_index + 1), "total": battle.waves.size()}), "SmallLabel", 17, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(lvl)
	var buttons: Array = []
	buttons.append(UiKit.button(Loc.t("pause.resume"), close_pause, "CoralButton", Vector2(360, 58)))
	buttons.append(UiKit.button(Loc.t("pause.restart"), _restart, "", Vector2(360, 52)))
	buttons.append(UiKit.button(Loc.t("menu.settings"), _pause_settings, "", Vector2(360, 52)))
	buttons.append(UiKit.button(Loc.t("menu.help"), _pause_help, "", Vector2(360, 52)))
	buttons.append(UiKit.button(Loc.t("pause.quit"), _quit, "PaperButton", Vector2(360, 52)))
	for b in buttons:
		v.add_child(b)
	UiKit.chain_focus(buttons)
	UiKit.pop_in(panel)
	if Controls.uses_focus():
		(buttons[0] as Control).grab_focus.call_deferred()
	_modal.set_meta("first", buttons[0])


func close_pause() -> void:
	if _modal == null:
		return
	_modal.queue_free()
	_modal = null
	battle.set_paused(false)


func _pause_settings() -> void:
	_modal.visible = false
	get_tree().root.get_node("Main").open_settings(_restore_pause)


func _pause_help() -> void:
	_modal.visible = false
	get_tree().root.get_node("Main").open_help(_restore_pause)


func _restore_pause() -> void:
	if _modal == null:
		return
	_modal.visible = true
	battle.fx.refresh_quality()
	if Controls.uses_focus():
		(_modal.get_meta("first") as Control).grab_focus()


func _restart() -> void:
	get_tree().root.get_node("Main").go("battle", {"level": battle.level_index})


func _quit() -> void:
	get_tree().root.get_node("Main").go("map_select")


func _next_level() -> void:
	get_tree().root.get_node("Main").go("battle", {"level": battle.level_index + 1})


func _unhandled_input(event: InputEvent) -> void:
	if _modal == null or not _modal.visible:
		return
	if get_tree().root.get_node("Main").has_modal():
		return
	if battle.state == "won" or battle.state == "lost":
		if event.is_action_pressed("ui_accept") and _modal.get_viewport().gui_get_focus_owner() == null:
			(_modal.get_meta("first") as Control).grab_focus()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("mg_pause") or event.is_action_pressed("mg_menu"):
		close_pause()
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept")) and _modal.get_viewport().gui_get_focus_owner() == null:
		(_modal.get_meta("first") as Control).grab_focus()
		get_viewport().set_input_as_handled()


func show_result(won: bool, stars: int, score: int, is_best: bool) -> void:
	close_ring()
	if _modal != null:
		_modal.queue_free()
	if _coach != null:
		_coach.queue_free()
		_coach = null
	await get_tree().create_timer(0.9).timeout
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_modal)
	_modal.add_child(UiKit.dim(0.45))
	if won:
		var motes := AmbientMotes.new()
		motes.amount = 70
		motes.set_anchors_preset(Control.PRESET_FULL_RECT)
		_modal.add_child(motes)
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(560, 0)
	_modal.add_child(UiKit.center(panel))
	var v := UiKit.vbox(10)
	panel.add_child(v)
	var title := UiKit.label(Loc.t("result.win") if won else Loc.t("result.lose"), "HeadingLabel", 44, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", Palette.MOSS_DARK if won else Palette.CORAL_DARK)
	v.add_child(title)
	v.add_child(UiKit.label(Loc.t(str(battle.level.get("name", ""))), "SmallLabel", 18, HORIZONTAL_ALIGNMENT_CENTER))
	var sr := StarRow.new()
	sr.star_size = 62
	sr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(sr)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grid)
	var rows := [
		[Loc.t("result.lives"), "%d / %d" % [battle.lives, battle.max_lives]],
		[Loc.t("result.waves"), "%d / %d" % [battle.wave_index + 1 if won else battle.wave_index, battle.waves.size()]],
		[Loc.t("result.kills"), str(battle.kills)],
		[Loc.t("result.combo"), str(battle.best_combo)],
		[Loc.t("result.score"), str(score)],
	]
	for r in rows:
		grid.add_child(UiKit.label(r[0], "", 20))
		var val := UiKit.label(r[1], "HudLabel", 22, HORIZONTAL_ALIGNMENT_RIGHT)
		grid.add_child(val)
	if is_best:
		var badge := UiKit.label(Loc.t("result.best"), "CreamLabel", 22, HORIZONTAL_ALIGNMENT_CENTER)
		badge.add_theme_color_override("font_color", Palette.AMBER_LIGHT)
		v.add_child(badge)
	if won:
		var hint_key := "result.star_hint_3" if stars >= 3 else "result.star_hint"
		v.add_child(UiKit.label(Loc.t(hint_key), "SmallLabel", 15, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UiKit.hbox(10, BoxContainer.ALIGNMENT_CENTER)
	v.add_child(row)
	var buttons: Array = []
	if won and battle.level_index + 1 < GameData.level_count():
		buttons.append(UiKit.button(Loc.t("result.next"), _next_level, "CoralButton", Vector2(170, 56)))
	buttons.append(UiKit.button(Loc.t("result.retry"), _restart, "" if won else "CoralButton", Vector2(150, 56)))
	buttons.append(UiKit.button(Loc.t("result.maps"), _quit, "PaperButton", Vector2(150, 56)))
	for b in buttons:
		row.add_child(b)
	for i in buttons.size():
		var b: Control = buttons[i]
		b.focus_neighbor_left = b.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		b.focus_neighbor_right = b.get_path_to(buttons[(i + 1) % buttons.size()])
	_modal.set_meta("first", buttons[0])
	UiKit.pop_in(panel)
	if Controls.uses_focus():
		(buttons[0] as Control).grab_focus.call_deferred()
	if won:
		sr.reveal(stars, 0.4)
	Sound.play_music("title", 2.0)
