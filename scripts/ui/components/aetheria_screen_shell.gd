class_name AetheriaScreenShell
extends Control

signal layout_mode_changed(mode: StringName)

const MODES: Array[StringName] = [
	&"regular_landscape", &"compact_landscape", &"portrait",
]
const LANDSCAPE_REFERENCE := Vector2(1280.0, 720.0)
const PORTRAIT_REFERENCE := Vector2(720.0, 1280.0)
const MAX_CONTENT_SCALE := 2.0
const MIN_CONTENT_SCALE := 0.72
const DIALOG_TEXT_GUTTER := 28

@export var preferred_size: Vector2:
	get:
		return _preferred_size
	set(value):
		set_preferred_size(value)

@export var full_safe_area: bool:
	get:
		return _full_safe_area
	set(value):
		set_full_safe_area(value)

var _preferred_size := Vector2(720.0, 520.0)
var _layout_mode: StringName = &"regular_landscape"
var _content_scale := 1.0
var _dialog_scroll: ScrollContainer = null
var _full_safe_area := false

@onready var _safe_margin: MarginContainer = $SafeMargin
@onready var _center: CenterContainer = $SafeMargin/Center
@onready var _reading_frame: Control = $SafeMargin/Center/ReadingFrame
@onready var _reading_plate: PanelContainer = $SafeMargin/Center/ReadingFrame/ReadingPlate
@onready var _content_margin: MarginContainer = $SafeMargin/Center/ReadingFrame/ReadingPlate/ContentMargin
@onready var _content_host: MarginContainer = $SafeMargin/Center/ReadingFrame/ReadingPlate/ContentMargin/ContentHost


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	_reading_plate.minimum_size_changed.connect(_apply_reading_geometry)
	relayout(Vector2i(size))


func set_preferred_size(value: Vector2) -> bool:
	if value.x <= 0.0 or value.y <= 0.0:
		return false
	_preferred_size = value
	if is_node_ready():
		relayout(Vector2i(size))
	return true


func set_full_safe_area(value: bool) -> void:
	_full_safe_area = value
	if is_node_ready():
		relayout(Vector2i(size))


func content_host() -> Control:
	return _content_host


func add_dialog_scroll(scroll: ScrollContainer) -> MarginContainer:
	if scroll == null or scroll.get_parent() != null or _dialog_scroll != null:
		return null
	_dialog_scroll = scroll
	var panel_style := _reading_plate.get_theme_stylebox(&"panel").duplicate() as StyleBox
	panel_style.content_margin_right = 0.0
	_reading_plate.add_theme_stylebox_override(&"panel", panel_style)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_host.add_child(scroll)
	_content_margin.add_theme_constant_override(&"margin_right", 0)
	var gutter := MarginContainer.new()
	gutter.name = "%sContentGutter" % scroll.name
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override(&"margin_right", DIALOG_TEXT_GUTTER)
	scroll.add_child(gutter)
	return gutter


func reading_plate() -> Control:
	return _reading_plate


func layout_mode() -> StringName:
	return _layout_mode


func content_scale() -> float:
	return _content_scale


func relayout(viewport: Vector2i) -> void:
	if not is_node_ready() or viewport.x <= 0 or viewport.y <= 0:
		return
	var next_mode := _mode_for(viewport)
	var compact := next_mode != &"regular_landscape"
	var inset := 18 if compact else 28
	var padding := 18 if next_mode == &"portrait" else (22 if compact else 28)
	_set_margins(_safe_margin, inset)
	_set_margins(_content_margin, padding)
	if _dialog_scroll != null:
		_content_margin.add_theme_constant_override(&"margin_right", 0)
	var available := Vector2(
		maxi(1, viewport.x - inset * 2),
		maxi(1, viewport.y - inset * 2),
	)
	if _full_safe_area:
		_content_scale = 1.0
		_reading_plate.custom_minimum_size = available
		_reading_plate.position = Vector2.ZERO
		_reading_plate.size = available
		_reading_plate.scale = Vector2.ONE
		_reading_frame.custom_minimum_size = available
	else:
		var plate_size := Vector2(
			minf(_preferred_size.x, available.x),
			minf(_preferred_size.y, available.y),
		)
		var reference := PORTRAIT_REFERENCE if next_mode == &"portrait" else LANDSCAPE_REFERENCE
		var viewport_scale := minf(float(viewport.x) / reference.x, float(viewport.y) / reference.y)
		var fit_scale := minf(available.x / _preferred_size.x, available.y / _preferred_size.y)
		_content_scale = clampf(minf(viewport_scale, fit_scale), MIN_CONTENT_SCALE, MAX_CONTENT_SCALE)
		_reading_plate.custom_minimum_size = plate_size
		_apply_reading_geometry()
	if next_mode != _layout_mode:
		_layout_mode = next_mode
		layout_mode_changed.emit(_layout_mode)


func _mode_for(viewport: Vector2i) -> StringName:
	var aspect := float(viewport.x) / maxf(1.0, float(viewport.y))
	if viewport.y > viewport.x or aspect < 0.9:
		return &"portrait"
	if viewport.x < 1100 or viewport.y < 680:
		return &"compact_landscape"
	return &"regular_landscape"


func _set_margins(container: MarginContainer, value: int) -> void:
	for side: StringName in [
		&"margin_left", &"margin_top", &"margin_right", &"margin_bottom",
	]:
		container.add_theme_constant_override(side, value)


func _apply_reading_geometry() -> void:
	if _full_safe_area:
		return
	var plate_size := _reading_plate.get_combined_minimum_size()
	_reading_plate.position = Vector2.ZERO
	_reading_plate.size = plate_size
	_reading_plate.pivot_offset = Vector2.ZERO
	_reading_plate.scale = Vector2.ONE * _content_scale
	_reading_frame.custom_minimum_size = plate_size * _content_scale


func _on_resized() -> void:
	relayout(Vector2i(size))
