extends RefCounted
## Single authority for authoring controls. Only validated values reach consumers.
const CATEGORIES: Array[StringName] = [&"UI", &"GAMEPLAY", &"AUDIO", &"PLAYER", &"ENEMIES", &"ENVIRONMENT"]
const DEFINITIONS := [
	["ui.text_scale", "UI", "float", 1.0, 0.85, 1.2, 0.05, "NEXT_STAGE", "COSMETIC", "scale"],
	["gameplay.start_gold", "GAMEPLAY", "int", 300.0, 200.0, 800.0, 25.0, "NEXT_STAGE", "GAMEPLAY", "gold"],
	["gameplay.reward_scale", "GAMEPLAY", "float", 1.0, 0.5, 2.0, 0.1, "NEXT_STAGE", "GAMEPLAY", "scale"],
	["gameplay.town_health", "GAMEPLAY", "int", 20.0, 5.0, 20.0, 1.0, "NEXT_STAGE", "GAMEPLAY", "health"],
	["audio.music_pitch_multiplier", "AUDIO", "float", 1.0, 0.85, 1.15, 0.05, "NEXT_STAGE", "COSMETIC", "scale"],
	["audio.sfx_pitch", "AUDIO", "float", 1.0, 0.8, 1.2, 0.05, "NEXT_ACTION", "COSMETIC", "scale"],
	["player.attack_multiplier", "PLAYER", "float", 1.0, 0.5, 2.0, 0.1, "NEXT_STAGE", "GAMEPLAY", "scale"],
	["player.attack_speed_multiplier", "PLAYER", "float", 1.0, 0.5, 2.0, 0.1, "NEXT_STAGE", "GAMEPLAY", "scale"],
	["player.range_bonus", "PLAYER", "int", 0.0, 0.0, 2.0, 1.0, "NEXT_STAGE", "GAMEPLAY", "tiles"],
	["player.visual_scale", "PLAYER", "float", 1.0, 0.75, 1.25, 0.05, "LIVE", "COSMETIC", "scale"],
	["enemies.health_multiplier", "ENEMIES", "float", 1.0, 0.5, 2.0, 0.1, "NEXT_STAGE", "GAMEPLAY", "scale"],
	["enemies.movement_speed_multiplier", "ENEMIES", "float", 1.0, 0.5, 1.5, 0.1, "NEXT_STAGE", "GAMEPLAY", "scale"],
	["enemies.visual_scale", "ENEMIES", "float", 1.0, 0.8, 1.25, 0.05, "LIVE", "COSMETIC", "scale"],
	["environment.zoom", "ENVIRONMENT", "float", 1.0, 0.7, 1.5, 0.1, "NEXT_STAGE", "COSMETIC", "scale"],
	["environment.effect_opacity", "ENVIRONMENT", "float", 1.0, 0.4, 1.0, 0.1, "LIVE", "COSMETIC", "scale"],
]

class Descriptor extends RefCounted:
	var id: StringName
	var category: StringName
	var value_type: StringName
	var default_value: Variant
	var minimum: float
	var maximum: float
	var step: float
	var apply_mode: StringName
	var integrity: StringName
	var unit: StringName
	var label_key: String
	var description_key: String

	func _init(row: Array) -> void:
		id = StringName(row[0])
		category = StringName(row[1])
		value_type = StringName(row[2])
		default_value = int(row[3]) if value_type == &"int" else float(row[3])
		minimum = float(row[4])
		maximum = float(row[5])
		step = float(row[6])
		apply_mode = StringName(row[7])
		integrity = StringName(row[8])
		unit = StringName(row[9])
		label_key = "tuning.control." + String(id) + ".label"
		description_key = "tuning.control." + String(id) + ".description"

var descriptors: Array[Descriptor] = []
var _by_id: Dictionary = {}

func _init() -> void:
	for row: Array in DEFINITIONS:
		var item := Descriptor.new(row)
		assert(not _by_id.has(item.id))
		assert(CATEGORIES.has(item.category))
		assert(item.value_type in [&"int", &"float"])
		assert(item.apply_mode in [&"LIVE", &"NEXT_STAGE", &"NEXT_ACTION"])
		assert(item.integrity in [&"COSMETIC", &"GAMEPLAY"])
		assert(is_finite(item.minimum) and is_finite(item.maximum) and is_finite(item.step) and is_finite(float(item.default_value)))
		assert(item.minimum <= item.maximum and item.minimum <= float(item.default_value) and float(item.default_value) <= item.maximum and item.step > 0)
		assert(item.value_type != &"int" or (item.step == floorf(item.step) and item.minimum == floorf(item.minimum) and item.maximum == floorf(item.maximum)))
		descriptors.append(item)
		_by_id[item.id] = item
		assert(equal(validate(item.id, item.default_value).value, item.default_value))

func descriptor(id: StringName) -> Descriptor:
	return _by_id.get(id)

func defaults() -> Dictionary:
	var values: Dictionary = {}
	for item: Descriptor in descriptors:
		values[item.id] = item.default_value
	return values

func validate(id: StringName, candidate: Variant) -> Dictionary:
	var item := descriptor(id)
	if item == null or not typeof(candidate) in [TYPE_INT, TYPE_FLOAT]:
		return {"ok": false}
	var number := float(candidate)
	if not is_finite(number) or number < item.minimum or number > item.maximum:
		return {"ok": false}
	var ticks := (number - item.minimum) / item.step
	if not is_finite(ticks) or absf(ticks - roundf(ticks)) > 0.0000001:
		return {"ok": false}
	return {"ok": true, "value": int(roundf(number)) if item.value_type == &"int" else snappedf(number, 0.000001)}

func validate_patch(patch: Dictionary) -> Dictionary:
	if patch.size() > 128:
		return {"ok": false, "values": {}}
	var result: Dictionary = {}
	for raw_id: Variant in patch:
		if not typeof(raw_id) in [TYPE_STRING, TYPE_STRING_NAME]:
			return {"ok": false, "values": {}}
		var id := StringName(raw_id)
		var checked := validate(id, patch[raw_id])
		if not checked.ok:
			return {"ok": false, "values": {}}
		result[id] = checked.value
	return {"ok": true, "values": result}

static func equal(a: Variant, b: Variant) -> bool:
	return is_equal_approx(float(a), float(b))
