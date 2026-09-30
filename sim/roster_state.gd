class_name RosterState
extends RefCounted

## Immutable ordered view over normalized CampaignSave hero rows. Allocation is
## a pure preview: no roster row or campaign counter is changed here.

const CampaignProgressionType := preload("res://sim/campaign_progression.gd")
const VALID_SOURCES := [&"starter", &"contract", &"reward", &"recovery"]

var _rows: Array[Dictionary] = []


static func from_normalized_rows(rows: Array) -> RosterState:
	var roster := RosterState.new()
	for row: Dictionary in rows:
		roster._rows.append(row.duplicate(true))
	return roster


func all() -> Array[HeroState]:
	var values: Array[HeroState] = []
	for row: Dictionary in _rows:
		values.append(HeroState.from_normalized_row(row))
	return values


func ready() -> Array[HeroState]:
	var values: Array[HeroState] = []
	for row: Dictionary in _rows:
		if row["life_status"] == "ready":
			values.append(HeroState.from_normalized_row(row))
	return values


func by_id(hero_id: String) -> HeroState:
	for row: Dictionary in _rows:
		if row["hero_id"] == hero_id:
			return HeroState.from_normalized_row(row)
	return null


func contains_id(hero_id: String) -> bool:
	return by_id(hero_id) != null


func owned_operator_def_ids() -> Array[StringName]:
	var values: Array[StringName] = []
	for row: Dictionary in _rows:
		var operator_id := StringName(row["operator_def_id"])
		if not values.has(operator_id):
			values.append(operator_id)
	return values


func rows_copy() -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for row: Dictionary in _rows:
		values.append(row.duplicate(true))
	return values


func plan_allocation(
	seed_value: int,
	generation: int,
	next_recruitment_index: int,
	operator_def_id: StringName,
	recruit_source: StringName,
	source_id: String,
	recruited_after_resolution_index: int,
	name_version: int = HeroNames.VERSION,
	is_taken_override: Callable = Callable(),
) -> Dictionary:
	if _rows.size() >= CampaignCodec.MAX_ROSTER:
		return _reject(&"roster_limit")
	if next_recruitment_index != _rows.size():
		return _reject(&"recruitment_counter_mismatch")
	if (
		generation < 1 or generation > CampaignCodec.U63_MAX
		or next_recruitment_index < 0
		or next_recruitment_index >= CampaignCodec.U63_MAX
		or not _is_ascii_id(String(operator_def_id))
		or not VALID_SOURCES.has(recruit_source)
		or recruited_after_resolution_index < 0
		or recruited_after_resolution_index > CampaignCodec.U63_MAX
		or name_version != HeroNames.VERSION
		or (recruit_source == &"starter" and not source_id.is_empty())
		or (recruit_source != &"starter" and not _is_ascii_id(source_id))
	):
		return _reject(&"invalid_allocation_request")
	var is_taken := func(candidate: String) -> bool:
		if contains_id(candidate):
			return true
		return (
			is_taken_override.is_valid()
			and bool(is_taken_override.call(candidate))
		)
	var allocated := HeroIdentity.allocate_hero_id(
		seed_value,
		generation,
		next_recruitment_index,
		is_taken,
	)
	if not allocated["accepted"]:
		return allocated
	var row := {
		"hero_id": allocated["hero_id"],
		"operator_def_id": String(operator_def_id),
		"recruitment_index": next_recruitment_index,
		"recruited_after_resolution_index": recruited_after_resolution_index,
		"recruit_source": String(recruit_source),
		"source_id": source_id,
		"name_version": name_version,
		"custom_callsign": null,
		"life_status": "ready",
		"death": null,
	}
	row = CampaignProgressionType.add_initial_fields(row)
	if row.is_empty():
		return _reject(&"unknown_operator")
	return {
		"accepted": true,
		"error_code": &"",
		"hero": HeroState.from_normalized_row(row),
		"row": row.duplicate(true),
		"next_recruitment_index": next_recruitment_index + 1,
		"collision_ordinal": allocated["collision_ordinal"],
	}


static func _is_ascii_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character: String in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			return false
	return true


static func _reject(error_code: StringName) -> Dictionary:
	return {
		"accepted": false,
		"error_code": error_code,
	}
