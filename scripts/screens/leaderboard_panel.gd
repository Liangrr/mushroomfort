extends Control
## Online leaderboard modal. Offline mode shows a clear connection hint.

signal closed

var _list: VBoxContainer
var _title: Label
var _status: Label
var _tabs: HBoxContainer
var _close_btn: GameButton
var _active_level := "level_1"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.dim())
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(760, 560)
	add_child(UiKit.center(panel))
	var v := UiKit.vbox(12)
	panel.add_child(v)
	_title = UiKit.label("在线排行榜 / Online Leaderboard", "HeadingLabel", 30, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_title)
	_tabs = UiKit.hbox(8)
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_tabs)
	for i in GameData.level_count():
		var button := UiKit.button("地图 %d" % (i + 1), _select_level.bind("level_%d" % (i + 1)), "PaperButton", Vector2(150, 46))
		_tabs.add_child(button)
	_list = UiKit.vbox(5)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_list)
	_status = UiKit.label("正在读取… / Loading…", "SmallLabel", 16, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_status)
	_close_btn = UiKit.button(Loc.t("common.close"), _close, "CoralButton", Vector2(220, 54))
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_close_btn)
	CloudService.leaderboard_loaded.connect(_on_loaded)
	_select_level(_active_level)
	UiKit.pop_in(panel)
	if Controls.uses_focus():
		_close_btn.grab_focus.call_deferred()


func _select_level(level_id: String) -> void:
	_active_level = level_id
	_status.text = "正在读取… / Loading…"
	for child in _list.get_children():
		child.queue_free()
	CloudService.fetch_leaderboard(level_id, 20)


func _on_loaded(level_id: String, entries: Array) -> void:
	if level_id != _active_level:
		return
	for child in _list.get_children():
		child.queue_free()
	if entries.is_empty():
		_status.text = "暂无在线成绩，或当前处于离线模式。 / No online scores yet or offline mode."
		return
	_status.text = "最高分优先 / Highest score first"
	for i in entries.size():
		var row_data: Dictionary = entries[i]
		var row := UiKit.hbox(12)
		row.custom_minimum_size = Vector2(0, 34)
		row.add_child(UiKit.label("#%d" % (i + 1), "SmallLabel", 18))
		var name := str(row_data.get("nickname", "蘑菇守卫")).substr(0, 16)
		var name_label := UiKit.label(name, "", 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UiKit.label("%d 分" % int(row_data.get("score", 0)), "SmallLabel", 18))
		row.add_child(UiKit.label("★ %d" % int(row_data.get("stars", 0)), "SmallLabel", 16))
		_list.add_child(row)


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("mg_menu"):
		get_viewport().set_input_as_handled()
		_close()


func _gui_input(_event: InputEvent) -> void:
	accept_event()
