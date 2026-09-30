class_name StageArtTheme
extends Resource

## Presentation-only shared Act I world-art contract for S1-S3. Gameplay,
## campaign, save, replay, and music lanes never read this resource.

const REQUIRED_THEME_STAGE_IDS: Array[StringName] = [&"s1", &"s2", &"s3"]
const SHARED_THEME_ID: StringName = &"world.act1.alpine_shared"
const SHARED_SPAWN_PIVOT := Vector2i(32, 64)
const SHARED_CORE_PIVOT := Vector2i(32, 80)
const SHARED_IDS: Array[StringName] = [
	&"world.act1.ground",
	&"world.act1.route",
	&"world.act1.raised",
	&"world.act1.blocked",
	&"world.act1.spawn",
	&"world.act1.core",
	&"world.act1.panorama",
]
## Env prop pool — scattered on GROUND tiles by the grid builder.
const ENV_PROP_IDS: Array[StringName] = [
	&"world.act1.env.boulder",
	&"world.act1.env.barrel",
	&"world.act1.env.wall",
	&"world.act1.env.crate",
]
const TOPOLOGY := {
	&"s1":
	{
		"size": Vector2i(8, 5),
		"elevated": [Vector2i(2, 2), Vector2i(4, 2)],
		"blocked": [],
		"spawn": Vector2i(0, 1),
		"core": Vector2i(7, 3)
	},
	&"s2":
	{
		"size": Vector2i(10, 5),
		"elevated": [Vector2i(2, 0), Vector2i(6, 2)],
		"blocked": [Vector2i(3, 2), Vector2i(5, 2)],
		"spawn": Vector2i(0, 1),
		"core": Vector2i(9, 3)
	},
	&"s3":
	{
		"size": Vector2i(10, 6),
		"elevated": [Vector2i(5, 2)],
		"blocked": [Vector2i(2, 2), Vector2i(4, 2), Vector2i(2, 4), Vector2i(4, 4)],
		"spawn": Vector2i(0, 1),
		"core": Vector2i(9, 3)
	},
}

@export var stage_id: StringName = &""
@export var theme_id: StringName = &""
@export var ground_id: StringName = &""
@export var route_id: StringName = &""
@export var elevated_id: StringName = &""
@export var blocked_id: StringName = &""
@export var elevated_cells: Array[Vector2i] = []
@export var elevated_variant_ids: Array[StringName] = []
@export var blocked_cells: Array[Vector2i] = []
@export var blocked_variant_ids: Array[StringName] = []
@export var backdrop_panorama_id: StringName = &""
@export var surface_modulate: Color = Color.WHITE
@export var spawn_landmark_id: StringName = &""
@export var spawn_cell: Vector2i = Vector2i(-1, -1)
@export var spawn_pivot: Vector2i = Vector2i.ZERO
@export var spawn_offset: Vector2i = Vector2i.ZERO
@export var core_landmark_id: StringName = &""
@export var core_cell: Vector2i = Vector2i(-1, -1)
@export var core_pivot: Vector2i = Vector2i.ZERO
@export var core_offset: Vector2i = Vector2i.ZERO
@export var env_prop_cells: Array[Vector2i] = []
@export var env_prop_ids: Array[StringName] = []


static func expects_theme(stage: StageDef) -> bool:
	return stage != null and stage.id in REQUIRED_THEME_STAGE_IDS


static func resolve_for(stage: StageDef, resolver: Callable = Callable()) -> Dictionary:
	if stage == null or not expects_theme(stage):
		return {"required": false, "theme": null, "error": ""}
	var path := "res://data/presentation/%s_world_theme.tres" % stage.id
	var theme: StageArtTheme = null
	if resolver.is_valid():
		theme = resolver.call(path) as StageArtTheme
	elif ResourceLoader.exists(path):
		theme = load(path) as StageArtTheme
	if theme == null:
		return {
			"required": true,
			"theme": null,
			"error": "required stage art theme failed to load: %s" % path
		}
	var errors := theme.validation_errors(stage)
	for id: StringName in theme.required_manifest_ids():
		if Art.texture(id) == null or Art.size(id) == Vector2i.ZERO:
			errors.append("manifest asset missing or unsized: %s" % id)
	if not errors.is_empty():
		return {
			"required": true,
			"theme": null,
			"error": "required stage art theme is invalid: %s" % "; ".join(errors)
		}
	return {"required": true, "theme": theme, "error": ""}


static func load_for(stage: StageDef) -> StageArtTheme:
	var result := resolve_for(stage)
	if not String(result["error"]).is_empty():
		push_error("stage_art_theme: %s" % result["error"])
	return result["theme"] as StageArtTheme


func applies_to(stage: StageDef) -> bool:
	return stage != null and stage.id == stage_id


## BattleView validates the authored landscape theme first, then rotates this
## presentation copy with the same source dimensions as the portrait stage.
func clockwise_rotated_copy(source_size: Vector2i) -> StageArtTheme:
	var rotated := duplicate(true) as StageArtTheme
	rotated.elevated_cells = _rotated_cells(elevated_cells, source_size)
	rotated.blocked_cells = _rotated_cells(blocked_cells, source_size)
	rotated.env_prop_cells = _rotated_cells(env_prop_cells, source_size)
	rotated.spawn_cell = StageDef.rotate_cell_clockwise(spawn_cell, source_size)
	rotated.core_cell = StageDef.rotate_cell_clockwise(core_cell, source_size)
	return rotated


static func _rotated_cells(cells: Array[Vector2i], source_size: Vector2i) -> Array[Vector2i]:
	var rotated: Array[Vector2i] = []
	for cell: Vector2i in cells:
		rotated.append(StageDef.rotate_cell_clockwise(cell, source_size))
	return rotated


func tile_id(tile: StageDef.Tile, is_route: bool) -> StringName:
	if tile == StageDef.Tile.ELEVATED:
		return elevated_id
	if tile == StageDef.Tile.BLOCKED:
		return blocked_id
	if tile == StageDef.Tile.SPAWN or tile == StageDef.Tile.BASE:
		return ground_id
	if is_route:
		return route_id
	if tile == StageDef.Tile.GROUND:
		return ground_id
	return &""


func tile_id_at(cell: Vector2i, tile: StageDef.Tile, is_route: bool) -> StringName:
	if tile == StageDef.Tile.ELEVATED:
		var index := elevated_cells.find(cell)
		return elevated_variant_ids[index] if index >= 0 else elevated_id
	if tile == StageDef.Tile.BLOCKED:
		var index := blocked_cells.find(cell)
		return blocked_variant_ids[index] if index >= 0 else blocked_id
	return tile_id(tile, is_route)


func resolve_cell(cell: Vector2i, tile: StageDef.Tile, is_route: bool) -> Dictionary:
	var resolved_id := tile_id_at(cell, tile, is_route)
	if env_prop_cells.has(cell):
		resolved_id = ground_id
	return {"tile_id": resolved_id, "cadence_id": &""}


func required_manifest_ids() -> Array[StringName]:
	# The proto-isometric renderer owns terrain, backdrop, and obstacle textures
	# directly. Only the strategic endpoint landmarks remain manifest-backed.
	return [spawn_landmark_id, core_landmark_id]


func validation_errors(stage: StageDef) -> PackedStringArray:
	var errors := PackedStringArray()
	if not applies_to(stage):
		errors.append("theme stage_id does not match stage")
	if stage_id not in REQUIRED_THEME_STAGE_IDS:
		errors.append("theme stage_id is not in the required S1-S3 inventory")
	if theme_id != SHARED_THEME_ID:
		errors.append("theme_id is not the shared Act I alpine family")
	if surface_modulate != Color.WHITE:
		errors.append("shared Act I surface modulation must be Color.WHITE")
	# Generated endpoints retain ~600 px source frames but share a 64 px one-tile
	# display footprint. Each pivot is the bottom center of that displayed frame.
	if spawn_pivot != SHARED_SPAWN_PIVOT:
		errors.append("spawn pivot does not match 64x64 portal frame")
	if core_pivot != SHARED_CORE_PIVOT:
		errors.append("core pivot does not match 64x80 crystal frame")
	var actual_ids: Array[StringName] = [
		ground_id,
		route_id,
		elevated_id,
		blocked_id,
		spawn_landmark_id,
		core_landmark_id,
		backdrop_panorama_id
	]
	if actual_ids != SHARED_IDS:
		errors.append("logical role IDs do not match the shared Act I inventory")
	if elevated_cells.size() != elevated_variant_ids.size():
		errors.append("elevated cells and IDs must have matching lengths")
	if blocked_cells.size() != blocked_variant_ids.size():
		errors.append("blocked cells and IDs must have matching lengths")
	if env_prop_cells.size() != env_prop_ids.size():
		errors.append("environment prop cells and IDs must have matching lengths")
	for index: int in env_prop_ids.size():
		var prop_id := env_prop_ids[index]
		if prop_id not in ENV_PROP_IDS:
			errors.append("environment prop is not in the shared Act I pool: %s" % prop_id)
		var prop_cell := env_prop_cells[index]
		if stage != null and stage.tile_at(prop_cell) != StageDef.Tile.BLOCKED:
			errors.append("environment prop must occupy a blocked ground-base cell: %s" % prop_cell)
	for id: StringName in elevated_variant_ids:
		if id != elevated_id:
			errors.append("elevated variant is not the shared raised role: %s" % id)
	for id: StringName in blocked_variant_ids:
		if id != blocked_id:
			errors.append("blocked variant is not the shared blocked role: %s" % id)
	if not TOPOLOGY.has(stage_id):
		return errors
	var expected := _expected_topology(stage)
	if expected.is_empty():
		errors.append("stage grid size matches neither landscape nor portrait topology")
		return errors
	if elevated_cells != Array(expected["elevated"]):
		errors.append("elevated cells do not match the expected topology")
	if blocked_cells != Array(expected["blocked"]):
		errors.append("blocked cells do not match the expected topology")
	if spawn_cell != expected["spawn"]:
		errors.append("spawn endpoint does not match the expected topology")
	if core_cell != expected["core"]:
		errors.append("core endpoint does not match the expected topology")
	if stage != null:
		if stage.grid_size() != expected["size"]:
			errors.append("stage grid size does not match the expected topology")
		if stage.tile_at(spawn_cell) != StageDef.Tile.SPAWN:
			errors.append("spawn overlay cell is not SPAWN")
		if stage.tile_at(core_cell) != StageDef.Tile.BASE:
			errors.append("core overlay cell is not BASE")
		for cell: Vector2i in elevated_cells:
			if stage.tile_at(cell) != StageDef.Tile.ELEVATED:
				errors.append("expected elevated cell is not ELEVATED: %s" % cell)
		for cell: Vector2i in blocked_cells:
			if stage.tile_at(cell) != StageDef.Tile.BLOCKED:
				errors.append("expected blocked cell is not BLOCKED: %s" % cell)
	return errors


func _expected_topology(stage: StageDef) -> Dictionary:
	var authored: Dictionary = TOPOLOGY[stage_id]
	if stage == null or stage.grid_size() == authored["size"]:
		return authored
	var source_size: Vector2i = authored["size"]
	if stage.grid_size() != Vector2i(source_size.y, source_size.x):
		return {}
	var rotated_elevated: Array[Vector2i] = []
	for cell: Vector2i in authored["elevated"]:
		rotated_elevated.append(StageDef.rotate_cell_clockwise(cell, source_size))
	var rotated_blocked: Array[Vector2i] = []
	for cell: Vector2i in authored["blocked"]:
		rotated_blocked.append(StageDef.rotate_cell_clockwise(cell, source_size))
	return {
		"size": Vector2i(source_size.y, source_size.x),
		"elevated": rotated_elevated,
		"blocked": rotated_blocked,
		"spawn": StageDef.rotate_cell_clockwise(authored["spawn"], source_size),
		"core": StageDef.rotate_cell_clockwise(authored["core"], source_size),
	}
