class_name FablewoodLateEnemyVisuals
extends RefCounted
const AtlasLayout := preload("res://scripts/fablewood/atlas_layout.gd")
## Presentation-only adapter for the authored late-enemy directional atlases.
## It intentionally has no model writes: movement phase and facing are supplied
## by FablewoodWorld from the currently rendered path segment.

const ROOT := "res://assets/template/InvadersIlluminated"
const IDS := ["prismback", "harrier", "broodmother"]
const FACINGS := ["SE", "SW", "NW", "NE"]
const NOMINAL_CELL := Vector2i(384, 384)
const NOMINAL_ANCHOR := Vector2(192, 336)
const NOMINAL_COLUMNS := 8
const NOMINAL_FRAMES := 48
const NORMALIZED_DURATION := 2.0
const DISPLAY_EXPANSION := 1.5
# Fixed union-visible tops measured across all48 frames, per facing.
const VISIBLE_TOPS := {"prismback": {"NE": 96, "SE": 102, "NW": 96, "SW": 102}, "harrier": {"NE": 82, "SE": 95, "NW": 82, "SW": 95}, "broodmother": {"NE": 114, "SE": 114, "NW": 114, "SW": 114}}
const BASE_HEIGHTS := {&"prismback": 78.0, &"harrier": 64.0, &"broodmother": 70.0}
# One source-authentic 1.0s cycle at each enemy's untweaked movement speed.
const CYCLES_PER_TILE := {&"prismback": 1.0/0.38, &"harrier": 1.0/0.95, &"broodmother": 1.0/0.46}
const ALL_PATHS := [
	"res://assets/template/InvadersIlluminated/prismback/metadata.json",
	"res://assets/template/Audio/illuminated_enemy_shell_break.ogg",
	"res://assets/template/InvadersIlluminated/prismback/SE.webp",
	"res://assets/template/InvadersIlluminated/prismback/SW.webp",
	"res://assets/template/InvadersIlluminated/prismback/NW.webp",
	"res://assets/template/InvadersIlluminated/prismback/NE.webp",
	"res://assets/template/InvadersIlluminated/harrier/metadata.json",
	"res://assets/template/Audio/illuminated_enemy_harrier_dash.ogg",
	"res://assets/template/InvadersIlluminated/harrier/SE.webp",
	"res://assets/template/InvadersIlluminated/harrier/SW.webp",
	"res://assets/template/InvadersIlluminated/harrier/NW.webp",
	"res://assets/template/InvadersIlluminated/harrier/NE.webp",
	"res://assets/template/InvadersIlluminated/broodmother/metadata.json",
	"res://assets/template/Audio/illuminated_enemy_brood_spawn.ogg",
	"res://assets/template/InvadersIlluminated/broodmother/SE.webp",
	"res://assets/template/InvadersIlluminated/broodmother/SW.webp",
	"res://assets/template/InvadersIlluminated/broodmother/NW.webp",
	"res://assets/template/InvadersIlluminated/broodmother/NE.webp",
]

# Bound: at most 3 creatures × 4 directions × 48 AtlasTexture regions.
static var _frames: Dictionary = {}
static var _textures: Dictionary = {}
static var _descriptors: Dictionary = {}

static func is_late(kind: StringName) -> bool:
	return String(kind) in IDS

## Static, explicit paths keep every carrier and descriptor discoverable to
## export tooling even though a direction is selected at runtime.
static func all_paths() -> PackedStringArray:
	return PackedStringArray(ALL_PATHS)

static func sheet_path(kind: StringName, facing: StringName) -> String:
	return "%s/%s/%s.webp" % [ROOT, String(kind), String(facing)]

static func metadata_path(kind: StringName) -> String:
	return "%s/%s/metadata.json" % [ROOT, String(kind)]

static func facing_for_displacement(displacement: Vector2i) -> StringName:
	# This is the fixed isometric projection contract, not a left/right mirror.
	if displacement.x > 0:
		return &"SE"
	if displacement.y > 0:
		return &"SW"
	if displacement.x < 0:
		return &"NW"
	return &"NE"

static func has_art(kind: StringName) -> bool:
	if not is_late(kind):
		return false
	for facing: String in FACINGS:
		if not _resource_exists(sheet_path(kind, StringName(facing))):
			return false
	return true

static func dimensions(kind: StringName) -> Vector2:
	var descriptor := descriptor_for(kind)
	var cell: Vector2 = descriptor["cell"]
	var height := float(BASE_HEIGHTS.get(kind, 64.0)) * DISPLAY_EXPANSION
	return Vector2(height * cell.x / maxf(1.0, cell.y), height)

static func anchor(kind: StringName) -> Vector2:
	var descriptor := descriptor_for(kind)
	var cell: Vector2 = descriptor["cell"]
	var point: Vector2 = descriptor["anchor"]
	return Vector2(point.x / maxf(1.0, cell.x), point.y / maxf(1.0, cell.y))

static func normalized_phase_for_progress(progress_units: int, kind: StringName) -> float:
	var cycles := float(CYCLES_PER_TILE.get(kind, 1.0))
	return fposmod(float(progress_units) / float(Pathing.PROGRESS_SCALE) * cycles * NORMALIZED_DURATION, NORMALIZED_DURATION)

static func frame(kind: StringName, facing: StringName, normalized_phase: float) -> Texture2D:
	if not is_late(kind) or not FACINGS.has(String(facing)):
		return null
	var descriptor := descriptor_for(kind)
	var face: Dictionary = descriptor["faces"].get(String(facing), _default_face(descriptor))
	var frame_count := mini(NOMINAL_FRAMES, maxi(1, int(face["frames"])))
	var index := _frame_index(face, normalized_phase, frame_count)
	var key := "%s/%s" % [String(kind), String(facing)]
	if not _frames.has(key):
		var sheet := _sheet(kind, facing)
		if sheet == null:
			return null
		var sequence: Array[AtlasTexture] = []
		var cell: Vector2 = descriptor["cell"]
		var columns := maxi(1, int(face["columns"]))
		for item: int in frame_count:
			var texture := AtlasLayout.texture(sheet,sheet_path(kind,facing),item,cell,columns)
			sequence.append(texture)
		_frames[key] = sequence
	return (_frames[key] as Array)[index] as Texture2D

static func visible_height_ratio(kind:StringName,facing:StringName)->float:
	return (descriptor_for(kind)["anchor"].y-float(VISIBLE_TOPS[String(kind)][String(facing)]))/descriptor_for(kind)["cell"].y

## Exposed for native capture/PCK assertions. Runtime phase stays normalized to
## two seconds, while this reports the exact delivered source cycle length.
static func authored_cycle_duration(kind: StringName, facing: StringName) -> float:
	var descriptor := descriptor_for(kind)
	var face: Dictionary = descriptor["faces"].get(String(facing), _default_face(descriptor))
	return float(face["cycle_duration"])

static func descriptor_for(kind: StringName) -> Dictionary:
	if _descriptors.has(kind):
		return _descriptors[kind]
	var descriptor := _defaults()
	var path := metadata_path(kind)
	if not FileAccess.file_exists(path):
		# Do not cache absence: art workers can deliver descriptors during a session.
		return descriptor
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return descriptor
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return descriptor
	var metadata := parsed as Dictionary
	# Consume only the explicit, delivered metadata fields. Individual directions
	# retain the common authored contact point and cell, never inferred crops.
	descriptor["cell"] = _vector_value(metadata.get("cell", null), descriptor["cell"])
	descriptor["anchor"] = _vector_value(metadata.get("anchor", null), descriptor["anchor"])
	descriptor["frames"] = clampi(_positive_int(metadata.get("frames", descriptor["frames"]), int(descriptor["frames"])), 1, NOMINAL_FRAMES)
	descriptor["columns"] = maxi(1, _positive_int(metadata.get("columns", descriptor["columns"]), int(descriptor["columns"])))
	var directions: Dictionary = metadata.get("directions", {}) if metadata.get("directions", {}) is Dictionary else {}
	var per_face_durations: Dictionary = metadata.get("durations", {}) if metadata.get("durations", {}) is Dictionary else {}
	for raw_facing: String in FACINGS:
		var direction: Dictionary = directions.get(raw_facing, {}) if directions.get(raw_facing, {}) is Dictionary else {}
		var face := _default_face(descriptor)
		face["frames"] = clampi(_positive_int(direction.get("frame_count", face["frames"]), int(face["frames"])), 1, NOMINAL_FRAMES)
		var grid := _vector_value(direction.get("grid", null), Vector2(face["columns"], 1))
		face["columns"] = maxi(1, roundi(grid.x))
		var duration_per_frame := float(per_face_durations.get(raw_facing, direction.get("duration_per_frame_seconds", 0.0)))
		if duration_per_frame > 0.0:
			var frame_durations:=PackedFloat32Array()
			for _frame: int in int(face["frames"]):
				frame_durations.append(duration_per_frame)
			face["durations"] = frame_durations
		face["cycle_duration"] = float(direction.get("cycle_duration_seconds", duration_per_frame * int(face["frames"])))
		if float(face["cycle_duration"]) <= 0.0:
			face["cycle_duration"] = float(face["frames"]) / 24.0
		descriptor["faces"][raw_facing] = face
	_descriptors[kind] = descriptor
	return descriptor

static func _defaults() -> Dictionary:
	return {
		"cell": Vector2(NOMINAL_CELL),
		"anchor": NOMINAL_ANCHOR,
		"frames": NOMINAL_FRAMES,
		"columns": NOMINAL_COLUMNS,
		"faces": {},
	}

static func _default_face(descriptor: Dictionary) -> Dictionary:
	return {
		"frames": int(descriptor["frames"]),
		"columns": int(descriptor["columns"]),
		"durations": PackedFloat32Array(),
		"cycle_duration": float(descriptor["frames"]) / 24.0,
	}

static func _sheet(kind: StringName, facing: StringName) -> Texture2D:
	var key := "%s/%s" % [String(kind), String(facing)]
	if _textures.has(key):
		return _textures[key] as Texture2D
	var path := sheet_path(kind, facing)
	if not _resource_exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture != null:
		_textures[key] = texture
	return texture

static func _resource_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)

static func _frame_index(face: Dictionary, normalized_phase: float, frame_count: int) -> int:
	var ratio := fposmod(normalized_phase, NORMALIZED_DURATION) / NORMALIZED_DURATION
	var durations: PackedFloat32Array = face.get("durations",PackedFloat32Array())
	if durations.size() == frame_count:
		var total := 0.0
		for duration: float in durations:
			total += duration
		if total > 0.0:
			var cursor := ratio * total
			var elapsed := 0.0
			for i: int in durations.size():
				elapsed += durations[i]
				if cursor < elapsed:
					return i
	return mini(frame_count - 1, floori(ratio * frame_count))

static func _vector_value(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Vector2i:
		return Vector2(value as Vector2i)
	if value is Array and (value as Array).size() >= 2:
		var items := value as Array
		if (items[0] is int or items[0] is float) and (items[1] is int or items[1] is float):
			return Vector2(float(items[0]), float(items[1]))
	if value is Dictionary:
		var values := value as Dictionary
		if (values.get("x") is int or values.get("x") is float) and (values.get("y") is int or values.get("y") is float):
			return Vector2(float(values["x"]), float(values["y"]))
	return fallback

static func _positive_int(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		return maxi(1, int(value))
	return fallback

static func clear_cache() -> void:
	_frames.clear()
	_textures.clear()
	_descriptors.clear()
