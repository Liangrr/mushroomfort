class_name CampaignHeroCodec
extends RefCounted

const CampaignProgression := preload("res://sim/campaign_progression.gd")
const HeroIdentity := preload("res://sim/hero_identity.gd")
const HeroNames := preload("res://sim/hero_names.gd")
const SOURCE_VALUES := ["starter", "contract", "reward", "recovery"]
const LIFE_VALUES := ["ready", "dead"]
const TERMINAL_VALUES := ["clear", "leak_defeat", "base_defeat", "resign"]
const U32_MAX := 4_294_967_295
const U63_MAX := 9_223_372_036_854_775_807
const HERO_KEYS := [
	"hero_id", "acquisition_operator_def_id", "operator_def_id",
	"first_class_id", "advanced_class_id", "progression_rules_version", "xp",
	"identity_portrait_id", "recruitment_index", "recruited_after_resolution_index",
	"recruit_source", "source_id", "name_version", "custom_callsign",
	"life_status", "death",
]


static func normalize_heroes(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return _reject(&"invalid_heroes")
	var out: Array = []
	var ids := {}
	var indices := {}
	var previous_index := -1
	var previous_id := ""
	for row: Variant in value:
		if typeof(row) != TYPE_DICTIONARY or not _exact_keys(row, HERO_KEYS):
			return _reject(&"invalid_hero")
		if not _valid_identity_fields(row):
			return _reject(&"invalid_hero")
		var recruitment_index := int(row["recruitment_index"])
		if not _valid_history_fields(row, recruitment_index):
			return _reject(&"invalid_hero")
		var hero_id := String(row["hero_id"])
		if ids.has(hero_id) or indices.has(recruitment_index):
			return _reject(&"duplicate_hero")
		if recruitment_index < previous_index:
			return _reject(&"noncanonical_hero_order")
		if recruitment_index == previous_index and hero_id <= previous_id:
			return _reject(&"noncanonical_hero_order")
		previous_index = recruitment_index
		previous_id = hero_id
		ids[hero_id] = true
		indices[recruitment_index] = true
		var death: Variant = null
		if row["death"] != null:
			var normalized_death := _normalize_death(row["death"])
			if not normalized_death["accepted"]:
				return normalized_death
			death = normalized_death["value"]
		if (String(row["life_status"]) == "dead") != (death != null):
			return _reject(&"invalid_life_state")
		var ordered := {}
		for key: String in HERO_KEYS:
			match key:
				"death": ordered[key] = death
				"recruitment_index", "recruited_after_resolution_index":
					ordered[key] = int(row[key])
				"name_version", "progression_rules_version", "xp":
					ordered[key] = int(row[key])
				_: ordered[key] = row[key]
		out.append(ordered)
	return _accept(out)


static func valid_callsign(value: Variant) -> bool:
	if value == null:
		return true
	if typeof(value) != TYPE_STRING:
		return false
	var text := String(value)
	if text.is_empty() or text != _trim_callsign(text):
		return false
	var count := 0
	for character: String in text:
		var codepoint := character.unicode_at(0)
		if codepoint < 32 or (codepoint >= 127 and codepoint <= 159):
			return false
		count += 1
	return count <= 20


static func valid_title(value: Variant) -> bool:
	if value == null:
		return true
	if typeof(value) != TYPE_STRING:
		return false
	var text := String(value)
	if text.is_empty() or text != _trim_callsign(text):
		return false
	var count := 0
	for character: String in text:
		var codepoint := character.unicode_at(0)
		if codepoint < 32 or (codepoint >= 127 and codepoint <= 159):
			return false
		count += 1
	return count <= 24


static func display_callsign(hero: Dictionary) -> Dictionary:
	if hero["custom_callsign"] != null:
		return _accept(String(hero["custom_callsign"]))
	var parsed := HeroIdentity.parse_u64_hex(hero["hero_id"])
	if not parsed["accepted"]:
		return parsed
	return HeroNames.default_name(parsed["bits"], int(hero["name_version"]))


static func _valid_identity_fields(row: Dictionary) -> bool:
	for key: String in [
		"hero_id", "acquisition_operator_def_id", "operator_def_id",
		"first_class_id", "identity_portrait_id",
	]:
		if not _is_ascii(row[key], key == "hero_id"):
			return false
	if not _is_hex(String(row["hero_id"]), 16):
		return false
	if row["advanced_class_id"] != null and not _is_ascii(row["advanced_class_id"]):
		return false
	return CampaignProgression.projection_is_valid(row)


static func _valid_history_fields(row: Dictionary, recruitment_index: int) -> bool:
	return (
		_in_range(recruitment_index, 0, U63_MAX)
		and _in_range(row["recruited_after_resolution_index"], 0, U63_MAX)
		and _in_range(row["name_version"], 1, U32_MAX)
		and _in_range(row["progression_rules_version"], 1, U32_MAX)
		and _in_range(row["xp"], 0, U63_MAX)
		and SOURCE_VALUES.has(String(row["recruit_source"]))
		and _is_ascii(row["source_id"], true)
		and valid_callsign(row["custom_callsign"])
		and LIFE_VALUES.has(String(row["life_status"]))
	)


static func _normalize_death(value: Variant) -> Dictionary:
	var keys := ["resolution_index", "attempt_id", "stage_id", "terminal_reason", "terminal_tick"]
	if typeof(value) != TYPE_DICTIONARY or not _exact_keys(value, keys):
		return _reject(&"invalid_death")
	for key: String in ["resolution_index", "attempt_id"]:
		if not _in_range(value[key], 1, U63_MAX):
			return _reject(&"invalid_death")
	if not _in_range(value["terminal_tick"], 0, U63_MAX):
		return _reject(&"invalid_death")
	if not _is_ascii(value["stage_id"]) or not TERMINAL_VALUES.has(String(value["terminal_reason"])):
		return _reject(&"invalid_death")
	var ordered := {}
	for key: String in keys:
		ordered[key] = (
			int(value[key])
			if key in ["resolution_index", "attempt_id", "terminal_tick"]
			else value[key]
		)
	return _accept(ordered)


static func _trim_callsign(value: String) -> String:
	var first := 0
	var last := value.length()
	while first < last and value.substr(first, 1) in [" ", "\t"]:
		first += 1
	while last > first and value.substr(last - 1, 1) in [" ", "\t"]:
		last -= 1
	return value.substr(first, last - first)


static func _is_ascii(value: Variant, allow_empty: bool = false) -> bool:
	if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return false
	var text := String(value)
	if text.is_empty():
		return allow_empty
	for character: String in text:
		if character.unicode_at(0) > 127:
			return false
	return true


static func _is_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true


static func _in_range(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= minimum and int(value) <= maximum


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	var actual: Array = value.keys()
	for index: int in expected.size():
		if actual[index] != expected[index]:
			return false
	return true


static func _accept(value: Variant) -> Dictionary:
	return {"accepted": true, "error_code": &"", "value": value}


static func _reject(error_code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": error_code}
