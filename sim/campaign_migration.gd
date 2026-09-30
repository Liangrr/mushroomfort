class_name CampaignMigration
extends RefCounted

## Total, deterministic migration from the immutable P16 v1 save shape to v2.
## Migration adds progression defaults and rewrites nested anchor integrity links.

const CampaignCodec := preload("res://sim/campaign_codec.gd")
const CampaignHash := preload("res://sim/campaign_hash.gd")
const CampaignProgression := preload("res://sim/campaign_progression.gd")
const CombatContentBindingScript := preload("res://sim/combat_content_binding.gd")
const LegacyHashScript := preload("res://sim/campaign_legacy_hash.gd")

const V1_HERO_KEYS := [
	"hero_id", "operator_def_id", "recruitment_index", "recruited_after_resolution_index",
	"recruit_source", "source_id", "name_version", "custom_callsign", "life_status", "death",
]
const V1_RESOLUTION_KEYS := [
	"schema_version", "resolution_index", "campaign_uid", "attempt_id", "stage_id",
	"outcome_hash", "result", "terminal_reason", "terminal_tick", "stars_before", "stars_after",
	"rewards_granted", "created_hero_ids", "dead_hero_ids", "marks_before", "marks_after",
	"strategic_body_hash_before", "strategic_body_hash_after",
]
const V2_RESOLUTION_KEYS := [
	"schema_version", "resolution_index", "campaign_uid", "attempt_id", "stage_id",
	"outcome_hash", "result", "terminal_reason", "terminal_tick", "stars_before", "stars_after",
	"rewards_granted", "created_hero_ids", "dead_hero_ids", "xp_awards",
	"marks_before", "marks_after", "strategic_body_hash_before", "strategic_body_hash_after",
]
const ANCHOR_KEYS := [
	"resolution_index", "save_revision_after", "before_core", "after_core",
	"strategic_body_hash_before", "strategic_body_hash_after",
]


static func migrate_v1_data(data: Variant, context: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return _reject(&"invalid_v1_data")
	var migrated: Dictionary = (data as Dictionary).duplicate(true)
	if not _legacy_integrity_is_valid(migrated):
		return _reject(&"invalid_v1_integrity")
	var combat_rules_sha256 := CombatContentBindingScript.LEGACY_ZERO_SHA256
	if not _migrate_core(migrated, combat_rules_sha256):
		return _reject(&"invalid_v1_data")
	var resolution: Variant = migrated.get("last_resolution")
	if resolution != null:
		var migrated_resolution := _migrate_resolution(resolution)
		if migrated_resolution.is_empty():
			return _reject(&"invalid_v1_resolution")
		migrated["last_resolution"] = migrated_resolution
	var anchor: Variant = migrated.get("resolution_anchor")
	if anchor != null:
		if typeof(anchor) != TYPE_DICTIONARY:
			return _reject(&"invalid_v1_anchor")
		var migrated_anchor: Dictionary = (anchor as Dictionary).duplicate(true)
		if not _migrate_core(
			migrated_anchor.get("before_core", null), combat_rules_sha256,
		):
			return _reject(&"invalid_v1_anchor")
		if not _migrate_core(
			migrated_anchor.get("after_core", null), combat_rules_sha256,
		):
			return _reject(&"invalid_v1_anchor")
		var before_hash := CampaignHash.of_core_snapshot(migrated_anchor["before_core"], context)
		var after_hash := CampaignHash.of_core_snapshot(migrated_anchor["after_core"], context)
		if not before_hash["accepted"] or not after_hash["accepted"]:
			return _reject(&"invalid_v1_anchor")
		migrated_anchor["strategic_body_hash_before"] = before_hash["hex"]
		migrated_anchor["strategic_body_hash_after"] = after_hash["hex"]
		migrated["resolution_anchor"] = migrated_anchor
		if migrated["last_resolution"] != null:
			migrated["last_resolution"]["strategic_body_hash_before"] = before_hash["hex"]
			migrated["last_resolution"]["strategic_body_hash_after"] = after_hash["hex"]
	var ordered := {}
	for key: String in CampaignCodec.DATA_KEYS:
		ordered[key] = migrated[key]
	return {"accepted": true, "error_code": &"", "value": ordered}


static func _legacy_integrity_is_valid(data: Dictionary) -> bool:
	var anchor: Variant = data.get("resolution_anchor")
	var resolution: Variant = data.get("last_resolution")
	if anchor == null or resolution == null:
		return anchor == null and resolution == null
	if typeof(anchor) != TYPE_DICTIONARY or not _exact_keys(anchor, ANCHOR_KEYS):
		return false
	if typeof(resolution) != TYPE_DICTIONARY or not _exact_keys(resolution, V1_RESOLUTION_KEYS):
		return false
	var anchor_row := anchor as Dictionary
	var resolution_row := resolution as Dictionary
	var before_hash := LegacyHashScript.of_core_snapshot(anchor_row["before_core"])
	var after_hash := LegacyHashScript.of_core_snapshot(anchor_row["after_core"])
	if not before_hash["accepted"] or not after_hash["accepted"]:
		return false
	if String(anchor_row["strategic_body_hash_before"]) != String(before_hash["hex"]):
		return false
	if String(anchor_row["strategic_body_hash_after"]) != String(after_hash["hex"]):
		return false
	return (
		resolution_row["strategic_body_hash_before"]
		== anchor_row["strategic_body_hash_before"]
		and resolution_row["strategic_body_hash_after"]
		== anchor_row["strategic_body_hash_after"]
	)


static func _migrate_core(value: Variant, combat_rules_sha256: String) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var core := value as Dictionary
	if not core.has("heroes") or typeof(core["heroes"]) != TYPE_ARRAY:
		return false
	var migrated: Array = []
	for raw: Variant in core["heroes"]:
		if typeof(raw) != TYPE_DICTIONARY or not _exact_keys(raw, V1_HERO_KEYS):
			return false
		var row := CampaignProgression.add_initial_fields(raw)
		if row.is_empty():
			return false
		migrated.append(row)
	core["heroes"] = migrated
	core["combat_rules_sha256"] = combat_rules_sha256
	core["promotion_receipts"] = []
	core["promotion_proofs"] = []
	if not core.has("resolution_anchor"):
		var ordered := {}
		for key: String in CampaignCodec.CORE_KEYS:
			ordered[key] = core[key]
		core.clear()
		core.merge(ordered)
	return true


static func _migrate_resolution(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _exact_keys(value, V1_RESOLUTION_KEYS):
		return {}
	var source := value as Dictionary
	var result := {}
	for key: String in V2_RESOLUTION_KEYS:
		if key == "schema_version":
			result[key] = 2
		elif key == "xp_awards":
			result[key] = []
		else:
			result[key] = source[key]
	return result


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	var actual: Array = value.keys()
	for index: int in expected.size():
		if actual[index] != expected[index]:
			return false
	return true


static func _reject(error_code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": error_code}
