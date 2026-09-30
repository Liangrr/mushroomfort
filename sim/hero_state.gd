class_name HeroState
extends RefCounted

## Immutable view over one whole-document-validated CampaignSave HeroState row.
## Construction is intentionally internal to CampaignState/RosterState.

var _row: Dictionary = {}


static func from_normalized_row(row: Dictionary) -> HeroState:
	var state := HeroState.new()
	state._row = row.duplicate(true)
	return state


func hero_id() -> String:
	return String(_row["hero_id"])


func operator_def_id() -> StringName:
	return StringName(_row["operator_def_id"])


func acquisition_operator_def_id() -> StringName:
	return StringName(_row["acquisition_operator_def_id"])


func first_class_id() -> StringName:
	return StringName(_row["first_class_id"])


func advanced_class_id() -> Variant:
	var value: Variant = _row["advanced_class_id"]
	return StringName(value) if value != null else null


func progression_rules_version() -> int:
	return int(_row["progression_rules_version"])


func xp() -> int:
	return int(_row["xp"])


func identity_portrait_id() -> StringName:
	return StringName(_row["identity_portrait_id"])


func recruitment_index() -> int:
	return int(_row["recruitment_index"])


func recruited_after_resolution_index() -> int:
	return int(_row["recruited_after_resolution_index"])


func recruit_source() -> StringName:
	return StringName(_row["recruit_source"])


func source_id() -> String:
	return String(_row["source_id"])


func name_version() -> int:
	return int(_row["name_version"])


func custom_callsign() -> Variant:
	return _row["custom_callsign"]


func life_status() -> StringName:
	return StringName(_row["life_status"])


func death() -> Variant:
	var value: Variant = _row["death"]
	return value.duplicate(true) if value != null else null


func default_name() -> Dictionary:
	var parsed := HeroIdentity.parse_u64_hex(hero_id())
	if not parsed["accepted"]:
		return parsed
	return HeroNames.default_name(int(parsed["bits"]), name_version())


func display_callsign() -> Dictionary:
	if custom_callsign() != null:
		return {
			"accepted": true,
			"error_code": &"",
			"value": String(custom_callsign()),
		}
	return default_name()


func is_ready() -> bool:
	return life_status() == &"ready"


func to_row() -> Dictionary:
	return _row.duplicate(true)
