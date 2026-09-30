extends Node
## Root of the game: swaps screens with a paper-fade transition and hosts
## global modal panels (settings, help).

const TitleScreen := preload("res://scripts/screens/title_screen.gd")
const MapSelect := preload("res://scripts/screens/map_select.gd")
const Battle := preload("res://scripts/battle/battle.gd")
const SettingsPanel := preload("res://scripts/screens/settings_panel.gd")
const HelpPanel := preload("res://scripts/screens/help_panel.gd")

var current: Node
var _fade: ColorRect
var _modals: CanvasLayer
var _busy := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("22301c"))
	_modals = CanvasLayer.new()
	_modals.layer = 60
	add_child(_modals)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color("1d2616")
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)
	get_viewport().size_changed.connect(_fit_screen)
	_show(_make("title", {}))
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.5)


func go(screen: String, args: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.28)
	await tw.finished
	close_modals()
	if current != null:
		current.queue_free()
		current = null
	await get_tree().process_frame
	_show(_make(screen, args))
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.35)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _make(screen: String, args: Dictionary) -> Node:
	match screen:
		"map_select":
			return MapSelect.new()
		"battle":
			var b := Battle.new()
			b.level_index = int(args.get("level", 0))
			return b
	return TitleScreen.new()


func _show(node: Node) -> void:
	current = node
	add_child(node)
	move_child(node, 0)
	_fit_screen()


## Screen roots are Controls under a plain Node, so give them the visible
## viewport rect explicitly (anchors alone resolve against a zero rect here).
func _fit_screen() -> void:
	if current is Control:
		_fit(current as Control)
	if _fade != null:
		_fit(_fade)
	for m in _modals.get_children():
		if m is Control:
			_fit(m as Control)


func _fit(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = Vector2.ZERO
	c.size = get_viewport().get_visible_rect().size


func open_settings(on_close: Callable = Callable()) -> Control:
	var panel: Control = SettingsPanel.new()
	panel.closed.connect(func() -> void:
		if on_close.is_valid():
			on_close.call())
	_modals.add_child(panel)
	_fit(panel)
	return panel


func open_help(on_close: Callable = Callable()) -> Control:
	var panel: Control = HelpPanel.new()
	panel.closed.connect(func() -> void:
		if on_close.is_valid():
			on_close.call())
	_modals.add_child(panel)
	_fit(panel)
	return panel


func has_modal() -> bool:
	return _modals.get_child_count() > 0


func close_modals() -> void:
	for c in _modals.get_children():
		c.queue_free()


static func instance(from: Node) -> Node:
	return from.get_tree().root.get_node_or_null("Main")
