extends Node
## Pure parameter manager shared by preview and player builds. The Addon owns
## editing UI and drafts; this owner never reads or writes local files.
const Catalog = preload("res://scripts/fablewood/tuning_catalog.gd")
signal value_changed(id: StringName, requested: Variant, active: Variant)
signal stage_started(metadata: Dictionary)
var catalog := Catalog.new()
var _requested: Dictionary = {}
var _active: Dictionary = {}
var _stage_active := false
var _taint_reasons: Array[String] = []

func _init() -> void:
	_requested = catalog.defaults()
	_active = _requested.duplicate()

func value(id: StringName, fallback: Variant = null) -> Variant:
	var item = catalog.descriptor(id)
	if item == null:
		return fallback
	return _active.get(id, fallback) if item.apply_mode == &"NEXT_STAGE" else _requested.get(id, fallback)

func requested_value(id: StringName, fallback: Variant = null) -> Variant:
	return _requested.get(id, fallback)

func active_value(id: StringName, fallback: Variant = null) -> Variant:
	return _active.get(id, fallback)

func set_value(id: StringName, candidate: Variant) -> bool:
	return bool(apply_preview_patch({id: candidate}).ok)

func apply_preview_patch(patch: Dictionary) -> Dictionary:
	var checked: Dictionary = catalog.validate_patch(patch)
	if not checked.ok:
		return checked
	var changed: Array[StringName] = []
	# Validate first, commit the complete patch second, then notify consumers.
	# An observer of any notification always sees the full accepted transaction.
	for id: StringName in checked.values:
		if Catalog.equal(_requested[id], checked.values[id]):
			continue
		changed.append(id)
		_requested[id] = checked.values[id]
		if catalog.descriptor(id).apply_mode == &"LIVE":
			_active[id] = checked.values[id]
	changed.sort()
	for id: StringName in changed:
		var item = catalog.descriptor(id)
		if item.apply_mode == &"LIVE":
			_record_gameplay_deviation(item)
		value_changed.emit(id, _requested[id], _active[id])
	return {"ok": true, "changed": changed.size()}

func begin_stage() -> void:
	_stage_active = true
	_taint_reasons.clear()
	for item in catalog.descriptors:
		if item.apply_mode == &"NEXT_STAGE":
			_active[item.id] = _requested.get(item.id, item.default_value)
		_record_gameplay_deviation(item)
	stage_started.emit(run_metadata())

func acknowledge_action(id: StringName) -> bool:
	var item = catalog.descriptor(id)
	if item == null or item.apply_mode != &"NEXT_ACTION":
		return false
	var changed := not Catalog.equal(_active[id], _requested[id])
	_active[id] = _requested[id]
	_record_gameplay_deviation(item)
	if changed:
		value_changed.emit(id, _requested[id], _active[id])
	return true

func _record_gameplay_deviation(item: RefCounted) -> void:
	if _stage_active and item.integrity == &"GAMEPLAY" and not Catalog.equal(_active.get(item.id, item.default_value), item.default_value):
		var reason := String(item.id)
		if not _taint_reasons.has(reason):
			_taint_reasons.append(reason)
			_taint_reasons.sort()

func run_metadata() -> Dictionary:
	var config: Array[String] = ["fablewood-tuning"]
	for item in catalog.descriptors:
		if item.integrity == &"GAMEPLAY":
			config.append("%s=%.6f" % [item.id, float(_active.get(item.id, item.default_value))])
	config.sort()
	return {"tuning_ranked_eligible": _taint_reasons.is_empty(), "tuning_config_hash": "\n".join(config).sha256_text(), "tuning_reasons": _taint_reasons.duplicate()}

func is_tweaked() -> bool:
	return not _taint_reasons.is_empty()

func reset_value(id: StringName) -> bool:
	var item = catalog.descriptor(id)
	return set_value(id, item.default_value) if item != null else false

func reset_all() -> int:
	return int(apply_preview_patch(catalog.defaults()).get("changed", 0))

func delta_values() -> Dictionary:
	var delta: Dictionary = {}
	for item in catalog.descriptors:
		if not Catalog.equal(_requested.get(item.id, item.default_value), item.default_value):
			delta[item.id] = _requested[item.id]
	return delta
