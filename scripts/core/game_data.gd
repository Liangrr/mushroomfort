extends Node
## Loads the data-driven game definition from res://data/game/.
## towers.json, enemies.json, balance.json and levels/<id>.json are the only
## places gameplay numbers live, so adapting the game starts there.

const DATA_DIR := "res://data/game/"

var towers: Dictionary = {}      # tower_id -> definition (with "levels")
var tower_order: Array = []
var enemies: Dictionary = {}
var balance: Dictionary = {}
var levels: Array = []           # ordered level dictionaries

var _textures := {}


func _ready() -> void:
	reload()


func reload() -> void:
	var tower_file := _load_json(DATA_DIR + "towers.json")
	towers = tower_file.get("towers", {})
	tower_order = tower_file.get("order", towers.keys())
	enemies = _load_json(DATA_DIR + "enemies.json").get("enemies", {})
	balance = _load_json(DATA_DIR + "balance.json")
	levels.clear()
	for level_id in balance.get("level_order", []):
		var level := _load_json(DATA_DIR + "levels/%s.json" % level_id)
		if not level.is_empty():
			levels.append(level)


func tower_stats(tower_id: String, level_key: String) -> Dictionary:
	return towers.get(tower_id, {}).get("levels", {}).get(level_key, {})


func level_count() -> int:
	return levels.size()


func cell_size() -> float:
	return float(balance.get("grid", {}).get("cell", 64))


## Cached texture lookup for art under res://assets/mg/.
func tex(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var full := "res://assets/mg/%s" % path
	var texture: Texture2D = null
	if ResourceLoader.exists(full):
		texture = load(full) as Texture2D
	else:
		push_warning("Missing texture %s" % full)
	_textures[path] = texture
	return texture


func tower_tex(sprite: String) -> Texture2D:
	return tex("towers/%s.png" % sprite)


func enemy_tex(sprite: String) -> Texture2D:
	return tex("enemies/%s.png" % sprite)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing data file %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("JSON error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("Data file %s must contain an object" % path)
		return {}
	return json.data
