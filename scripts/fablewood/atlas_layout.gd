class_name FablewoodAtlasLayout
extends RefCounted
## Runtime layout adapter for optional losslessly packed 8x6 animation atlases.
##
## Before optimization, or if metadata is unavailable/invalid, `texture()` emits
## the original atlas cell exactly as legacy adapters did. After the explicit
## offline --apply, the same call maps to the compact cell and gives AtlasTexture
## a margin whose position restores the original coordinate origin and whose size
## restores the original logical dimensions. No source-sized texture is loaded.

const METADATA_PATH := "res://assets/template/atlas_layout.json"
const SCHEMA := 1
const FRAME_COUNT := 48
const DEFAULT_COLUMNS := 8

static var _loaded := false
static var _records: Dictionary = {}

static func clear_cache() -> void:
	_loaded = false
	_records.clear()

static func texture(atlas: Texture2D, source_path: String, frame: int, original_cell: Vector2, columns: int = DEFAULT_COLUMNS) -> AtlasTexture:
	var value := AtlasTexture.new()
	value.atlas = atlas
	value.filter_clip = true
	var record := record_for(source_path)
	if record.is_empty() or int(record.get("columns", 0)) != columns:
		value.region = original_region(frame, original_cell, columns)
		return value
	var packed_cell := _array_vector(record.get("packed_cell", null))
	var trim_offset := _array_vector(record.get("trim_offset", null))
	var recorded_original := _array_vector(record.get("original_cell", null))
	if packed_cell.x <= 0.0 or packed_cell.y <= 0.0 or trim_offset.x < 0.0 or trim_offset.y < 0.0:
		value.region = original_region(frame, original_cell, columns)
		return value
	# Reject stale/mismatched metadata rather than changing an atlas's logical
	# geometry. This also keeps future families safe if their source contract moves.
	if recorded_original != original_cell:
		value.region = original_region(frame, original_cell, columns)
		return value
	var index := posmod(frame, FRAME_COUNT)
	value.region = Rect2(Vector2(index % columns, floori(float(index) / columns)) * packed_cell, packed_cell)
	# Godot AtlasTexture reports region.size + margin.size as its logical size.
	# Godot maps a logical point to region.position + point - margin.position.
	# The positive trim offset therefore restores compact crop pixels to their
	# original source coordinates; margin.size fills removed right/bottom space.
	value.margin = Rect2(trim_offset, original_cell - packed_cell)
	return value

static func set_frame(value: AtlasTexture, source_path: String, frame: int, original_cell: Vector2, columns: int = DEFAULT_COLUMNS) -> void:
	var record := record_for(source_path)
	if record.is_empty() or int(record.get("columns", 0)) != columns:
		value.region = original_region(frame, original_cell, columns)
		value.margin = Rect2()
		return
	var packed_cell := _array_vector(record.get("packed_cell", null))
	var trim_offset := _array_vector(record.get("trim_offset", null))
	var recorded_original := _array_vector(record.get("original_cell", null))
	if packed_cell.x <= 0.0 or packed_cell.y <= 0.0 or trim_offset.x < 0.0 or trim_offset.y < 0.0 or recorded_original != original_cell:
		value.region = original_region(frame, original_cell, columns)
		value.margin = Rect2()
		return
	var index := posmod(frame, FRAME_COUNT)
	value.region = Rect2(Vector2(index % columns, floori(float(index) / columns)) * packed_cell, packed_cell)
	value.margin = Rect2(trim_offset, original_cell - packed_cell)

static func original_region(frame: int, original_cell: Vector2, columns: int = DEFAULT_COLUMNS) -> Rect2:
	var index := posmod(frame, FRAME_COUNT)
	return Rect2(Vector2(index % columns, floori(float(index) / columns)) * original_cell, original_cell)

static func record_for(source_path: String) -> Dictionary:
	_load_once()
	var normalized := _normalize_path(source_path)
	var record: Variant = _records.get(normalized, {})
	return record if record is Dictionary else {}

static func _load_once() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(METADATA_PATH):
		return
	var file := FileAccess.open(METADATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var document := parsed as Dictionary
	if int(document.get("schema", -1)) != SCHEMA or not bool(document.get("enabled", false)):
		return
	var atlases: Variant = document.get("atlases", {})
	if not atlases is Dictionary:
		return
	for raw_path: Variant in (atlases as Dictionary).keys():
		var raw_record: Variant = (atlases as Dictionary)[raw_path]
		if raw_path is String and raw_record is Dictionary:
			_records[_normalize_path(raw_path as String)] = raw_record as Dictionary

static func _normalize_path(path: String) -> String:
	if path.begins_with("res://"):
		return path.trim_prefix("res://")
	return path

static func _array_vector(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Vector2i:
		return Vector2(value as Vector2i)
	if value is Array:
		var values := value as Array
		if values.size() >= 2 and (values[0] is int or values[0] is float) and (values[1] is int or values[1] is float):
			return Vector2(float(values[0]), float(values[1]))
	return Vector2(-1.0, -1.0)
