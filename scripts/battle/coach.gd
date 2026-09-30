extends PanelContainer
## Short, skippable first-play guide on map 1. Each step advances on the
## matching player action; finishing or skipping is remembered in the save.

var battle: BattleScene
var hud  # BattleHud
var _step := 0
var _text: Label
var _dots: Label
var _next: GameButton
var _skip: GameButton

const STEPS := ["path", "build", "upgrade", "start"]


func _ready() -> void:
	theme_type_variation = "CardPanel"
	position = Vector2(14, 82)
	custom_minimum_size = Vector2(420, 0)
	var v := UiKit.vbox(8)
	add_child(v)
	var head := UiKit.hbox(8)
	var title := UiKit.label(Loc.t("tutorial.title"), "HeadingLabel", 22)
	head.add_child(title)
	_dots = UiKit.label("", "SmallLabel", 16)
	head.add_child(_dots)
	v.add_child(head)
	_text = UiKit.label("", "", 17)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(396, 0)
	v.add_child(_text)
	var row := UiKit.hbox(8, BoxContainer.ALIGNMENT_END)
	_skip = UiKit.button(Loc.t("tutorial.skip"), _finish, "PaperButton", Vector2(0, 40))
	_skip.add_theme_font_size_override("font_size", 16)
	_skip.focus_mode = Control.FOCUS_NONE
	_next = UiKit.button(Loc.t("tutorial.next"), _advance, "", Vector2(0, 40))
	_next.add_theme_font_size_override("font_size", 16)
	_next.focus_mode = Control.FOCUS_NONE
	row.add_child(_skip)
	row.add_child(_next)
	v.add_child(row)
	battle.tower_built.connect(func(_t: Tower) -> void: _on_event("build"))
	battle.tower_selected.connect(func(t: Tower) -> void:
		if t != null:
			_on_event("upgrade"))
	battle.tower_upgraded.connect(func(_t: Tower) -> void: _on_event("upgrade"))
	battle.wave_started.connect(func(_i: int) -> void: _on_event("start"))
	Controls.device_changed.connect(func(_d: String) -> void: _show())
	_show()
	UiKit.pop_in(self, 0.6)


func _device_suffix() -> String:
	match Controls.device:
		"gamepad": return "_pad"
		"touch": return "_touch"
		"keyboard": return "_key"
	return "_mouse"


func _show() -> void:
	var key := "tutorial.%s" % STEPS[_step]
	var dev_key := key + _device_suffix()
	_text.text = Loc.t(dev_key) if Loc.has_key(dev_key) else Loc.t(key)
	_dots.text = "%d/%d" % [_step + 1, STEPS.size()]
	# Steps 0 and 2 can be acknowledged; 1 and 3 need the action (but 2 also advances on action).
	_next.visible = STEPS[_step] == "path" or STEPS[_step] == "upgrade"
	_next.text = Loc.t("tutorial.next")


func _on_event(kind: String) -> void:
	if STEPS[_step] == kind:
		_advance()
	elif kind == "start":
		_finish()


func _advance() -> void:
	_step += 1
	if _step >= STEPS.size():
		_finish()
		return
	Sound.play("coin", 1.3)
	_show()
	pivot_offset = size / 2.0
	scale = Vector2(1.04, 1.04)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)


func _finish() -> void:
	Save.set_tutorial_done(true)
	if hud != null and _step >= STEPS.size() - 1:
		hud.toast(Loc.t("tutorial.done"), Palette.LIME)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
