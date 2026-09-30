class_name BattleOutcomeV3
extends RefCounted

## Canonical terminal payload consumed by future strategic resolution. It binds
## every ticket member one-to-one without stepping or instantiating BattleModel.

const SCHEMA_VERSION := 1
const U32_MAX := 4_294_967_295
const U63_MAX := 9_223_372_036_854_775_807
const BattleTicketScript := preload("res://sim/battle_ticket.gd")
const CanonicalJsonScript := preload("res://sim/canonical_json.gd")
const RESULT_VALUES := ["clear", "defeat"]
const TERMINAL_VALUES := ["clear", "leak_defeat", "base_defeat", "resign"]
const KEYS := [
	"schema_version", "attempt_id", "ticket_hash", "result", "terminal_reason",
	"terminal_tick", "stars", "leaks", "kills", "rows", "outcome_hash",
]
const ROW_KEYS := [
	"slot_index", "battle_id", "hero_id", "class_id", "operator_def_id",
	"deployments", "retreats", "fell", "first_fall_tick",
]


static func normalize(value: Variant, ticket: Variant = null) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or value.keys() != KEYS:
		return _reject(&"invalid_outcome_schema")
	if value["schema_version"] != SCHEMA_VERSION:
		return _reject(&"invalid_outcome_version")
	if not _in_range(value["attempt_id"], 1, U63_MAX):
		return _reject(&"invalid_outcome_identity")
	if not _is_hex(String(value["ticket_hash"]), 64):
		return _reject(&"invalid_outcome_identity")
	if String(value["result"]) not in RESULT_VALUES:
		return _reject(&"invalid_outcome_terminal")
	if String(value["terminal_reason"]) not in TERMINAL_VALUES:
		return _reject(&"invalid_outcome_terminal")
	if not _in_range(value["terminal_tick"], 0, U63_MAX):
		return _reject(&"invalid_outcome_terminal")
	for key: String in ["stars", "leaks", "kills"]:
		if not _in_range(value[key], 0, U32_MAX):
			return _reject(&"invalid_outcome_counter")
	if int(value["stars"]) > 3:
		return _reject(&"invalid_outcome_counter")
	var cleared := String(value["result"]) == "clear"
	if cleared != (String(value["terminal_reason"]) == "clear"):
		return _reject(&"invalid_outcome_terminal")
	if cleared != (int(value["stars"]) >= 1):
		return _reject(&"invalid_outcome_terminal")
	var normalized_ticket: Variant = null
	if ticket != null:
		var ticket_result := BattleTicketScript.normalize(ticket)
		if not ticket_result["accepted"]:
			return _reject(&"invalid_outcome_ticket")
		normalized_ticket = ticket_result["value"]
		if (
			value["attempt_id"] != normalized_ticket["attempt_id"]
			or value["ticket_hash"] != normalized_ticket["ticket_hash"]
		):
			return _reject(&"outcome_ticket_mismatch")
	var rows := _normalize_rows(value["rows"], normalized_ticket, int(value["terminal_tick"]))
	if not rows["accepted"]:
		return rows
	var ordered := {
		"schema_version": SCHEMA_VERSION,
		"attempt_id": int(value["attempt_id"]),
		"ticket_hash": String(value["ticket_hash"]),
		"result": String(value["result"]),
		"terminal_reason": String(value["terminal_reason"]),
		"terminal_tick": int(value["terminal_tick"]),
		"stars": int(value["stars"]),
		"leaks": int(value["leaks"]),
		"kills": int(value["kills"]),
		"rows": rows["value"],
	}
	var expected_hash := CanonicalJsonScript.sha256_hex(ordered)
	if value["outcome_hash"] != expected_hash:
		return _reject(&"outcome_hash_mismatch")
	ordered["outcome_hash"] = expected_hash
	return _accept(ordered)


static func seal(value_without_hash: Dictionary, ticket: Dictionary) -> Dictionary:
	var candidate: Dictionary = value_without_hash.duplicate(true)
	candidate["outcome_hash"] = CanonicalJsonScript.sha256_hex(candidate)
	return normalize(candidate, ticket)


static func _normalize_rows(
	value: Variant,
	ticket: Variant,
	value_terminal_tick: int,
) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
		return _reject(&"invalid_outcome_rows")
	if ticket != null and (value as Array).size() != (ticket["squad"] as Array).size():
		return _reject(&"outcome_ticket_mismatch")
	var out: Array[Dictionary] = []
	var battle_ids := {}
	var hero_ids := {}
	for index: int in (value as Array).size():
		var raw: Variant = value[index]
		if typeof(raw) != TYPE_DICTIONARY or raw.keys() != ROW_KEYS:
			return _reject(&"invalid_outcome_row")
		if raw["slot_index"] != index:
			return _reject(&"noncanonical_outcome_order")
		for key: String in ["battle_id", "hero_id"]:
			if not _is_hex(String(raw[key]), 16):
				return _reject(&"invalid_outcome_row")
		for key: String in ["class_id", "operator_def_id"]:
			if not _ascii(String(raw[key])):
				return _reject(&"invalid_outcome_row")
		if battle_ids.has(raw["battle_id"]) or hero_ids.has(raw["hero_id"]):
			return _reject(&"duplicate_outcome_identity")
		battle_ids[raw["battle_id"]] = true
		hero_ids[raw["hero_id"]] = true
		for key: String in ["deployments", "retreats"]:
			if not _in_range(raw[key], 0, U32_MAX):
				return _reject(&"invalid_outcome_row")
		if typeof(raw["fell"]) != TYPE_BOOL:
			return _reject(&"invalid_outcome_row")
		if bool(raw["fell"]) != (raw["first_fall_tick"] != null):
			return _reject(&"invalid_outcome_row")
		if raw["first_fall_tick"] != null and not _in_range(
			raw["first_fall_tick"], 0, U63_MAX,
		):
			return _reject(&"invalid_outcome_row")
		if raw["first_fall_tick"] != null and raw["first_fall_tick"] > value_terminal_tick:
			return _reject(&"invalid_outcome_row")
		if ticket != null:
			var frozen: Dictionary = ticket["squad"][index]
			for key: String in [
				"slot_index", "battle_id", "hero_id", "class_id", "operator_def_id",
			]:
				if raw[key] != frozen[key]:
					return _reject(&"outcome_ticket_mismatch")
		out.append({
			"slot_index": index,
			"battle_id": String(raw["battle_id"]),
			"hero_id": String(raw["hero_id"]),
			"class_id": String(raw["class_id"]),
			"operator_def_id": String(raw["operator_def_id"]),
			"deployments": int(raw["deployments"]),
			"retreats": int(raw["retreats"]),
			"fell": bool(raw["fell"]),
			"first_fall_tick": (
				int(raw["first_fall_tick"]) if raw["first_fall_tick"] != null else null
			),
		})
	return _accept(out)


static func _in_range(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= minimum and int(value) <= maximum


static func _ascii(value: String) -> bool:
	if value.is_empty():
		return false
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
