class_name BattleTicket
extends RefCounted

## Canonical immutable attempt snapshot. This contract owns plain data only;

const SCHEMA_VERSION := 1
const U32_MAX := 4_294_967_295
const U63_MAX := 9_223_372_036_854_775_807
const CanonicalJsonScript := preload("res://sim/canonical_json.gd")
const TargetPolicyDefScript := preload("res://data/target_policy_def.gd")
const DamageRulesScript := preload("res://sim/damage_rules.gd")
const KEYS := [
	"schema_version", "campaign_uid", "attempt_id", "stage_id", "seed",
	"expected_save_revision", "strategic_hash", "squad", "ticket_hash",
]
const ROW_KEYS := [
	"slot_index", "battle_id", "hero_id", "class_id", "operator_def_id",
	"operator_content_sha256", "combat_spec", "target_policy_spec", "skill_spec",
	"visual_spec",
]
const COMBAT_KEYS := [
	"dp_cost", "block", "hp", "atk", "defense", "resistance_permille",
	"attack_damage_kind", "atk_interval_ticks", "placement",
	"range_cells", "dp_generation_interval_ticks", "splash_dim",
]
const SKILL_KEYS := ["skill_id", "skill_content_sha256", "payload"]
const TARGET_POLICY_KEYS := [
	"policy_id", "policy_content_sha256", "owner_kind", "candidate_domain",
	"aerial_rule", "primary_rank",
]
const VISUAL_KEYS := ["sprite_id", "portrait_asset_id"]


static func normalize(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _exact_keys(value, KEYS):
		return _reject(&"invalid_ticket_schema")
	if value["schema_version"] != SCHEMA_VERSION:
		return _reject(&"invalid_ticket_version")
	if not _is_hex(String(value["campaign_uid"]), 16):
		return _reject(&"invalid_ticket_identity")
	if not _in_range(value["attempt_id"], 1, U63_MAX):
		return _reject(&"invalid_ticket_identity")
	if not _ascii(String(value["stage_id"])):
		return _reject(&"invalid_ticket_identity")
	if not _in_range(value["seed"], -U63_MAX - 1, U63_MAX):
		return _reject(&"invalid_ticket_counter")
	if not _in_range(value["expected_save_revision"], 1, U63_MAX):
		return _reject(&"invalid_ticket_counter")
	if not _is_hex(String(value["strategic_hash"]), 16):
		return _reject(&"invalid_ticket_hash")
	var squad := _normalize_squad(value["squad"])
	if not squad["accepted"]:
		return squad
	var ordered := {
		"schema_version": SCHEMA_VERSION,
		"campaign_uid": String(value["campaign_uid"]),
		"attempt_id": int(value["attempt_id"]),
		"stage_id": String(value["stage_id"]),
		"seed": int(value["seed"]),
		"expected_save_revision": int(value["expected_save_revision"]),
		"strategic_hash": String(value["strategic_hash"]),
		"squad": squad["value"],
	}
	var expected_hash := CanonicalJsonScript.sha256_hex(ordered)
	if String(value["ticket_hash"]) != expected_hash:
		return _reject(&"ticket_hash_mismatch")
	ordered["ticket_hash"] = expected_hash
	return _accept(ordered)


static func seal(value_without_hash: Dictionary) -> Dictionary:
	var candidate: Dictionary = value_without_hash.duplicate(true)
	candidate["ticket_hash"] = CanonicalJsonScript.sha256_hex(candidate)
	return normalize(candidate)


static func _normalize_squad(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
		return _reject(&"invalid_ticket_squad")
	var out: Array[Dictionary] = []
	var hero_ids := {}
	var battle_ids := {}
	for index: int in (value as Array).size():
		var raw: Variant = value[index]
		if typeof(raw) != TYPE_DICTIONARY or not _exact_keys(raw, ROW_KEYS):
			return _reject(&"invalid_ticket_row")
		if raw["slot_index"] != index:
			return _reject(&"noncanonical_ticket_order")
		for key: String in ["battle_id", "hero_id"]:
			if not _is_hex(String(raw[key]), 16):
				return _reject(&"invalid_ticket_row")
		for key: String in ["class_id", "operator_def_id"]:
			if not _ascii(String(raw[key])):
				return _reject(&"invalid_ticket_row")
		if not _is_hex(String(raw["operator_content_sha256"]), 64):
			return _reject(&"invalid_ticket_row")
		if hero_ids.has(raw["hero_id"]) or battle_ids.has(raw["battle_id"]):
			return _reject(&"duplicate_ticket_identity")
		hero_ids[raw["hero_id"]] = true
		battle_ids[raw["battle_id"]] = true
		var combat := _normalize_combat(raw["combat_spec"])
		var target_policy := _normalize_target_policy(raw["target_policy_spec"])
		var skill := _normalize_skill(raw["skill_spec"])
		var visual := _normalize_visual(raw["visual_spec"])
		for result: Dictionary in [combat, target_policy, skill, visual]:
			if not result["accepted"]:
				return result
		out.append({
			"slot_index": index,
			"battle_id": String(raw["battle_id"]),
			"hero_id": String(raw["hero_id"]),
			"class_id": String(raw["class_id"]),
			"operator_def_id": String(raw["operator_def_id"]),
			"operator_content_sha256": String(raw["operator_content_sha256"]),
			"combat_spec": combat["value"],
			"target_policy_spec": target_policy["value"],
			"skill_spec": skill["value"],
			"visual_spec": visual["value"],
		})
	return _accept(out)


static func _normalize_combat(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _exact_keys(value, COMBAT_KEYS):
		return _reject(&"invalid_ticket_combat")
	for key: String in [
		"dp_cost", "block", "hp", "atk", "defense", "resistance_permille",
		"attack_damage_kind", "atk_interval_ticks", "placement",
		"dp_generation_interval_ticks", "splash_dim",
	]:
		if not _in_range(value[key], 0, U32_MAX):
			return _reject(&"invalid_ticket_combat")
	if value["hp"] == 0 or value["atk_interval_ticks"] == 0:
		return _reject(&"invalid_ticket_combat")
	if not DamageRulesScript.authored_values_valid(
		int(value["attack_damage_kind"]),
		int(value["defense"]),
		int(value["resistance_permille"]),
	):
		return _reject(&"invalid_ticket_combat")
	if typeof(value["range_cells"]) != TYPE_ARRAY or (value["range_cells"] as Array).is_empty():
		return _reject(&"invalid_ticket_combat")
	var cells: Array[Dictionary] = []
	var previous := ""
	for raw: Variant in value["range_cells"]:
		if typeof(raw) != TYPE_DICTIONARY or not _exact_keys(raw, ["x", "y"]):
			return _reject(&"invalid_ticket_range")
		if not _in_range(raw["x"], -32, 32) or not _in_range(raw["y"], -32, 32):
			return _reject(&"invalid_ticket_range")
		var key := "%+03d:%+03d" % [int(raw["x"]), int(raw["y"])]
		if not previous.is_empty() and key <= previous:
			return _reject(&"noncanonical_ticket_range")
		previous = key
		cells.append({"x": int(raw["x"]), "y": int(raw["y"])})
	var ordered := {}
	for key: String in COMBAT_KEYS:
		ordered[key] = cells if key == "range_cells" else int(value[key])
	return _accept(ordered)


static func _normalize_target_policy(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _exact_keys(value, TARGET_POLICY_KEYS):
		return _reject(&"invalid_ticket_target_policy")
	if (
		typeof(value["policy_id"]) != TYPE_STRING
		or typeof(value["policy_content_sha256"]) != TYPE_STRING
		or not _ascii(String(value["policy_id"]))
		or not _is_hex(String(value["policy_content_sha256"]), 64)
		or value["owner_kind"] != TargetPolicyDefScript.OwnerKind.OPERATOR
		or not _in_range(
			value["candidate_domain"], 0, TargetPolicyDefScript.CandidateDomain.size() - 1,
		)
		or not _in_range(value["aerial_rule"], 0, TargetPolicyDefScript.AerialRule.size() - 1)
		or not _in_range(value["primary_rank"], 0, TargetPolicyDefScript.RankKey.size() - 1)
	):
		return _reject(&"invalid_ticket_target_policy")
	var ordered := {}
	for key: String in TARGET_POLICY_KEYS:
		ordered[key] = (
			String(value[key])
			if key in ["policy_id", "policy_content_sha256"]
			else int(value[key])
		)
	return _accept(ordered)


static func _normalize_skill(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _exact_keys(value, SKILL_KEYS):
		return _reject(&"invalid_ticket_skill")
	if not _ascii(String(value["skill_id"]), true):
		return _reject(&"invalid_ticket_skill")
	if not _is_hex(String(value["skill_content_sha256"]), 64):
		return _reject(&"invalid_ticket_skill")
	var payload := _canonical_payload(value["payload"])
	if not payload["accepted"] or typeof(payload["value"]) != TYPE_DICTIONARY:
		return _reject(&"invalid_ticket_skill")
	return _accept({
		"skill_id": String(value["skill_id"]),
		"skill_content_sha256": String(value["skill_content_sha256"]),
		"payload": payload["value"],
	})


static func _normalize_visual(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _exact_keys(value, VISUAL_KEYS):
		return _reject(&"invalid_ticket_visual")
	if not _ascii(String(value["sprite_id"])) or not _ascii(String(value["portrait_asset_id"])):
		return _reject(&"invalid_ticket_visual")
	return _accept({
		"sprite_id": String(value["sprite_id"]),
		"portrait_asset_id": String(value["portrait_asset_id"]),
	})


static func _canonical_payload(value: Variant) -> Dictionary:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return _accept(value)
		TYPE_ARRAY:
			var array: Array = []
			for item: Variant in value:
				var normalized := _canonical_payload(item)
				if not normalized["accepted"]:
					return normalized
				array.append(normalized["value"])
			return _accept(array)
		TYPE_DICTIONARY:
			var names: Array[String] = []
			for raw_key: Variant in value:
				if typeof(raw_key) != TYPE_STRING or not _ascii(String(raw_key)):
					return _reject(&"invalid_ticket_payload")
				names.append(String(raw_key))
			names.sort()
			var dictionary := {}
			for key: String in names:
				var normalized := _canonical_payload(value[key])
				if not normalized["accepted"]:
					return normalized
				dictionary[key] = normalized["value"]
			return _accept(dictionary)
		_:
			return _reject(&"invalid_ticket_payload")


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	return value.keys() == expected


static func _in_range(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= minimum and int(value) <= maximum


static func _ascii(value: String, allow_empty: bool = false) -> bool:
	if value.is_empty():
		return allow_empty
	for character: String in value:
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


static func _accept(value: Variant) -> Dictionary:
	return {"accepted": true, "error_code": &"", "value": value}


static func _reject(error_code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": error_code}
