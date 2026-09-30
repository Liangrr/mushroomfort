extends Control
## How-to-play modal: controls for each device plus a compact tower & enemy codex.

signal closed

var _close_btn: GameButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.dim())
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(1120, 600)
	add_child(UiKit.center(panel))
	var v := UiKit.vbox(10)
	panel.add_child(v)
	v.add_child(UiKit.label(Loc.t("help.title"), "HeadingLabel", 34, HORIZONTAL_ALIGNMENT_CENTER))
	var cols := UiKit.hbox(28)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)

	var left := UiKit.vbox(6)
	left.custom_minimum_size = Vector2(470, 0)
	cols.add_child(left)
	left.add_child(UiKit.label(Loc.t("help.controls"), "HeadingLabel", 24))
	for key in ["help.mouse", "help.keyboard", "help.gamepad", "help.touch"]:
		var l := UiKit.label(Loc.t(key), "", 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(470, 0)
		left.add_child(l)
	var tip := UiKit.label(Loc.t("help.tip"), "SmallLabel", 16)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(470, 0)
	left.add_child(tip)

	var right := UiKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UiKit.label(Loc.t("help.towers"), "HeadingLabel", 24))
	for tid in GameData.tower_order:
		var def: Dictionary = GameData.towers[tid]
		var row := UiKit.hbox(10)
		row.add_child(UiKit.icon(GameData.tower_tex(str(def.levels["1"].sprite)), 46))
		var txt := UiKit.vbox(0)
		var nm := UiKit.label(Loc.t(str(def.name)), "", 18)
		nm.add_theme_font_override("font", UiTheme.bold_font)
		txt.add_child(nm)
		var rl := UiKit.label(Loc.t(str(def.role)), "SmallLabel", 15)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.custom_minimum_size = Vector2(520, 0)
		txt.add_child(rl)
		row.add_child(txt)
		right.add_child(row)
	right.add_child(UiKit.label(Loc.t("help.enemies"), "HeadingLabel", 24))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	right.add_child(grid)
	for eid in GameData.enemies:
		var e: Dictionary = GameData.enemies[eid]
		if e.get("hidden_in_codex", false):
			continue
		var row := UiKit.hbox(6)
		row.add_child(UiKit.icon(GameData.enemy_tex(str(e.sprite)), 36))
		var txt := UiKit.vbox(-4)
		var nm := UiKit.label(Loc.t(str(e.name)), "", 16)
		nm.add_theme_font_override("font", UiTheme.bold_font)
		txt.add_child(nm)
		txt.add_child(UiKit.label(Loc.t(str(e.desc)), "SmallLabel", 13))
		row.add_child(txt)
		row.custom_minimum_size = Vector2(186, 0)
		grid.add_child(row)

	_close_btn = UiKit.button(Loc.t("common.close"), _close, "CoralButton", Vector2(240, 54))
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_close_btn)
	UiKit.pop_in(panel)
	if Controls.uses_focus():
		_close_btn.grab_focus.call_deferred()


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("mg_menu"):
		get_viewport().set_input_as_handled()
		Sound.play("click")
		_close()


func _gui_input(_event: InputEvent) -> void:
	accept_event()
