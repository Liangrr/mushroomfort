extends Control
## Settings modal: volumes, effects quality, screen shake, language.

signal closed

var _focusables: Array = []
var _fx_btn: GameButton
var _shake_btn: GameButton
var _lang_zh: GameButton
var _lang_en: GameButton
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.dim())
	_panel = UiKit.panel()
	_panel.custom_minimum_size = Vector2(620, 0)
	var center := UiKit.center(_panel)
	add_child(center)
	var v := UiKit.vbox(14)
	_panel.add_child(v)
	v.add_child(UiKit.label(Loc.t("settings.title"), "HeadingLabel", 36, HORIZONTAL_ALIGNMENT_CENTER))
	_slider_row(v, "settings.master", "master")
	_slider_row(v, "settings.music", "music")
	_slider_row(v, "settings.sfx", "sfx")
	_fx_btn = _toggle_row(v, "settings.fx", _toggle_fx)
	_shake_btn = _toggle_row(v, "settings.shake", _toggle_shake)
	var lang_row := UiKit.hbox(12)
	var ll := UiKit.label(Loc.t("settings.language"), "", 22)
	ll.custom_minimum_size = Vector2(190, 0)
	lang_row.add_child(ll)
	_lang_zh = UiKit.button("中文", _set_lang.bind("zh"), "PaperButton", Vector2(150, 48))
	_lang_en = UiKit.button("English", _set_lang.bind("en"), "PaperButton", Vector2(150, 48))
	lang_row.add_child(_lang_zh)
	lang_row.add_child(_lang_en)
	v.add_child(lang_row)
	_focusables.append(_lang_zh)
	var close := UiKit.button(Loc.t("common.close"), _close, "CoralButton", Vector2(240, 56))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)
	_focusables.append(close)
	UiKit.chain_focus(_focusables)
	_lang_en.focus_neighbor_top = _lang_en.get_path_to(_focusables[_focusables.size() - 3])
	_lang_en.focus_neighbor_bottom = _lang_en.get_path_to(close)
	_refresh()
	UiKit.pop_in(_panel)
	if Controls.uses_focus():
		_focusables[0].grab_focus.call_deferred()


func _slider_row(parent: Control, key: String, setting: String) -> void:
	var row := UiKit.hbox(12)
	var l := UiKit.label(Loc.t(key), "", 22)
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = float(Save.get_setting(setting)) * 100.0
	s.custom_minimum_size = Vector2(290, 36)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	var value_label := UiKit.label("%d%%" % int(s.value), "", 20)
	value_label.custom_minimum_size = Vector2(64, 0)
	s.value_changed.connect(func(val: float) -> void:
		value_label.text = "%d%%" % int(val)
		Save.set_setting(setting, val / 100.0)
		Sound.play("hover"))
	row.add_child(s)
	row.add_child(value_label)
	parent.add_child(row)
	_focusables.append(s)


func _toggle_row(parent: Control, key: String, cb: Callable) -> GameButton:
	var row := UiKit.hbox(12)
	var l := UiKit.label(Loc.t(key), "", 22)
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var b := UiKit.button("", cb, "PaperButton", Vector2(312, 48))
	row.add_child(b)
	parent.add_child(row)
	_focusables.append(b)
	return b


func _refresh() -> void:
	_fx_btn.text = Loc.t("settings.fx_high") if bool(Save.get_setting("fx_high")) else Loc.t("settings.fx_low")
	_shake_btn.text = Loc.t("common.on") if bool(Save.get_setting("shake")) else Loc.t("common.off")
	_lang_zh.modulate = Color.WHITE if Loc.lang == "zh" else Color(1, 1, 1, 0.55)
	_lang_en.modulate = Color.WHITE if Loc.lang == "en" else Color(1, 1, 1, 0.55)


func _toggle_fx() -> void:
	Save.set_setting("fx_high", not bool(Save.get_setting("fx_high")))
	_refresh()


func _toggle_shake() -> void:
	Save.set_setting("shake", not bool(Save.get_setting("shake")))
	_refresh()


func _set_lang(code: String) -> void:
	Loc.set_lang(code)
	# Rebuild so every label picks up the new language.
	var focus_lang := code
	var fresh: Node = (load(get_script().resource_path) as GDScript).new()
	fresh.closed.connect(func() -> void: closed.emit())
	get_parent().add_child(fresh)
	queue_free()
	if Controls.uses_focus():
		(func() -> void:
			var btn: Control = fresh._lang_zh if focus_lang == "zh" else fresh._lang_en
			btn.grab_focus()).call_deferred()


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("mg_menu"):
		get_viewport().set_input_as_handled()
		Sound.play("click")
		_close()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		if get_viewport().gui_get_focus_owner() == null:
			_focusables[0].grab_focus()
			get_viewport().set_input_as_handled()


func _gui_input(_event: InputEvent) -> void:
	accept_event()
