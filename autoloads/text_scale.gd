extends Node

signal scale_changed(value: float)

const ViewPreferencesType := preload("res://scripts/view/view_preferences.gd")

const MIN_SCALE := 0.80
const MAX_SCALE := 1.50
const STEP := 0.05
const DEFAULT_SCALE := 1.0
const CONTROL_BASES_META := &"_protos_text_scale_font_bases"
const CONTROL_ACTIVE_META := &"_protos_text_scale_active_font_properties"
const CONTROL_CONNECTED_META := &"_protos_text_scale_connected"
const FONT_SIZE_PREFIX := "theme_override_font_sizes/"

var _scale := DEFAULT_SCALE
var _applying := false
var _project_theme: Theme = null
var _theme_bases: Dictionary = {}
var _theme_refs: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_project_theme = ThemeDB.get_project_theme()
	var stored_scale := ViewPreferencesType.text_scale()
	_scale = sanitize(stored_scale)
	ProjectSettings.set_setting("accessibility/text_scale", _scale)
	get_tree().node_added.connect(_on_node_added)
	_apply_all(DEFAULT_SCALE)
	_rescan.call_deferred()


func value() -> float:
	return _scale


func percent() -> int:
	return roundi(_scale * 100.0)


func set_scale(value: float) -> bool:
	var sanitized := sanitize(value)
	if is_equal_approx(sanitized, _scale):
		_rescan()
		return false
	var previous_scale := _scale
	_scale = sanitized
	ProjectSettings.set_setting("accessibility/text_scale", _scale)
	_apply_all(previous_scale)
	scale_changed.emit(_scale)
	return true


func sanitize(value: float) -> float:
	if not is_finite(value):
		return DEFAULT_SCALE
	var stepped := roundf(value / STEP) * STEP
	return clampf(stepped, MIN_SCALE, MAX_SCALE)


func _apply_all(previous_scale: float) -> void:
	if _applying:
		return
	_applying = true
	_prune_theme_tracking()
	var visited_themes: Dictionary = {}
	_scale_theme(_project_theme, previous_scale, visited_themes)
	var scene_tree := get_tree()
	if scene_tree != null:
		_prepare_branch(scene_tree.root, previous_scale, visited_themes)
	_applying = false


func _rescan() -> void:
	if not is_inside_tree():
		return
	_apply_all(_scale)


func _prepare_branch(node: Node, previous_scale: float, visited_themes: Dictionary) -> void:
	if node is Control:
		_prepare_control(node as Control, previous_scale, visited_themes)
	for child: Node in node.get_children():
		_prepare_branch(child, previous_scale, visited_themes)


func _on_node_added(node: Node) -> void:
	if node is Control:
		_prepare_control_deferred.call_deferred(node as Control)


func _prepare_control_deferred(candidate: Variant) -> void:
	if not is_instance_valid(candidate) or not candidate is Control:
		return
	var control := candidate as Control
	if not control.is_inside_tree():
		return
	if _applying:
		_prepare_control_deferred.call_deferred(control)
		return
	_applying = true
	_prepare_control(control, _scale, {})
	_applying = false


func _prepare_control(control: Control, previous_scale: float, visited_themes: Dictionary) -> void:
	if control == null or not is_instance_valid(control):
		return
	if not bool(control.get_meta(CONTROL_CONNECTED_META, false)):
		control.theme_changed.connect(_on_control_theme_changed.bind(control))
		control.set_meta(CONTROL_CONNECTED_META, true)
	if control.theme != null:
		_scale_theme(control.theme, previous_scale, visited_themes)
	_scale_control_overrides(control, previous_scale)


func _on_control_theme_changed(control: Control) -> void:
	if _applying or control == null or not is_instance_valid(control):
		return
	_prepare_control_deferred.call_deferred(control)


func _scale_control_overrides(control: Control, previous_scale: float) -> void:
	var bases: Dictionary = control.get_meta(CONTROL_BASES_META, {}).duplicate()
	var active: Array[StringName] = []
	for property: Dictionary in control.get_property_list():
		var property_name := StringName(property.get("name", &""))
		if not String(property_name).begins_with(FONT_SIZE_PREFIX):
			continue
		var item_name := StringName(String(property_name).trim_prefix(FONT_SIZE_PREFIX))
		if not control.has_theme_font_size_override(item_name):
			continue
		var current_value: Variant = control.get(property_name)
		if typeof(current_value) != TYPE_INT:
			continue
		active.append(property_name)
		var current := int(current_value)
		var base := current
		if bases.has(property_name):
			var stored_base := int(bases[property_name])
			var expected_current := maxi(1, roundi(float(stored_base) * previous_scale))
			base = stored_base if current == expected_current else current
		bases[property_name] = base
		var scaled := maxi(1, roundi(float(base) * _scale))
		if current != scaled:
			control.set(property_name, scaled)
	var previous_active: Array = control.get_meta(CONTROL_ACTIVE_META, []) as Array
	for property_name: Variant in previous_active:
		if StringName(property_name) not in active:
			bases.erase(StringName(property_name))
	control.set_meta(CONTROL_BASES_META, bases)
	control.set_meta(CONTROL_ACTIVE_META, active)


func _scale_theme(theme: Theme, previous_scale: float, visited_themes: Dictionary) -> void:
	if theme == null:
		return
	var instance_id := theme.get_instance_id()
	if visited_themes.has(instance_id):
		return
	visited_themes[instance_id] = true
	var bases: Dictionary = _theme_bases.get(instance_id, {}).duplicate(true)
	var default_base := theme.default_font_size
	if bases.has(&"__default"):
		var stored_default := int(bases[&"__default"])
		var expected_default := maxi(1, roundi(float(stored_default) * previous_scale))
		default_base = stored_default if theme.default_font_size == expected_default else theme.default_font_size
	bases[&"__default"] = default_base
	var scaled_default := maxi(1, roundi(float(default_base) * _scale))
	if theme.default_font_size != scaled_default:
		theme.default_font_size = scaled_default
	for type_name: StringName in theme.get_type_list():
		for item_name: StringName in theme.get_font_size_list(type_name):
			var key := StringName("%s/%s" % [type_name, item_name])
			var current := theme.get_font_size(item_name, type_name)
			var base := current
			if bases.has(key):
				var stored_base := int(bases[key])
				var expected_current := maxi(1, roundi(float(stored_base) * previous_scale))
				base = stored_base if current == expected_current else current
			bases[key] = base
			var scaled := maxi(1, roundi(float(base) * _scale))
			if current != scaled:
				theme.set_font_size(item_name, type_name, scaled)
	_theme_bases[instance_id] = bases
	_theme_refs[instance_id] = weakref(theme)


func _prune_theme_tracking() -> void:
	for instance_id: Variant in _theme_refs.keys():
		var reference := _theme_refs.get(instance_id) as WeakRef
		if reference == null or reference.get_ref() == null:
			_theme_refs.erase(instance_id)
			_theme_bases.erase(instance_id)
