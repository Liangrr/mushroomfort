class_name CampaignPromotion
extends RefCounted

## Deterministic strategic promotion transaction. The command is normalized once,
## exact retries resolve before revision checks, and every rejection leaves the
## caller-owned campaign Dictionary untouched.

const CampaignCodecType := preload("res://sim/campaign_codec.gd")
const CampaignHashType := preload("res://sim/campaign_hash.gd")
const CampaignProgressionType := preload("res://sim/campaign_progression.gd")
const CanonicalJsonType := preload("res://sim/canonical_json.gd")
const COMMAND_KEYS := [
	"version",
	"verb",
	"command_id",
	"hero_id",
	"advanced_class_id",
	"expected_save_revision",
]
const REPLAY_ROW_KEYS := ["seq", "verb", "args"]
const REPLAY_ARG_KEYS := [
	"version",
	"command_id",
	"hero_id",
	"advanced_class_id",
	"expected_save_revision",
]
const RECEIPT_KEYS := CampaignCodecType.PROMOTION_RECEIPT_KEYS
const U63_MAX := 9_223_372_036_854_775_807


static func execute(data: Dictionary, context: Dictionary, raw_command: Variant) -> Dictionary:
	var normalized := normalize_command(raw_command)
	if not normalized["accepted"]:
		return normalized
	var command: Dictionary = normalized["value"]
	var stored := _receipt_by_command_id(data["promotion_receipts"], command["command_id"])
	if not stored.is_empty():
		if command != _command_from_receipt(stored):
			return _reject(&"command_id_conflict")
		return _accepted(stored)
	var expected_id := command_id(
		String(data["campaign_uid"]),
		int(command["expected_save_revision"]),
		String(command["hero_id"]),
		String(command["advanced_class_id"]),
	)
	if command["command_id"] != expected_id:
		return _reject(&"invalid_argument_type")
	if int(command["expected_save_revision"]) != int(data["save_revision"]):
		return _reject(&"stale_revision")
	var hero := _hero_by_id(data["heroes"], String(command["hero_id"]))
	if hero.is_empty():
		return _reject(&"unknown_hero")
	var eligibility := (
		CampaignProgressionType
		. promotion_eligibility(
			hero,
			context["promotion_rules"],
		)
	)
	if not eligibility["accepted"]:
		return eligibility
	var choice := (
		CampaignProgressionType
		. promotion_choice(
			context["promotion_rules"],
			String(command["advanced_class_id"]),
		)
	)
	if choice.is_empty():
		return _reject(&"invalid_choice")
	if int(data["save_revision"]) >= U63_MAX:
		return _reject(&"xp_overflow")
	var before_hash := CampaignHashType.of_data(data, context)
	if not before_hash["accepted"]:
		return _reject(&"invalid_argument_type")
	var before_snapshot := _proof_snapshot(data)

	var working: Dictionary = data.duplicate(true)
	var working_hero := _hero_by_id(working["heroes"], String(command["hero_id"]))
	var prior_operator_def_id := String(working_hero["operator_def_id"])
	CampaignProgressionType.apply_promotion(working_hero, choice)
	working["save_revision"] = int(working["save_revision"]) + 1
	var receipt := _receipt(
		command,
		prior_operator_def_id,
		String(choice["operator_def_id"]),
		String(before_hash["hex"]),
		int(working["save_revision"]),
	)
	working["promotion_receipts"].append(receipt)
	var after_hash := CampaignHashType.of_normalized_data(working, false)
	receipt["after_strategic_hash"] = String(after_hash["hex"])
	var after_snapshot := _proof_snapshot(working)
	(
		working["promotion_proofs"]
		. append(
			{
				"command_id": command["command_id"],
				"before_data": before_snapshot,
				"after_data": after_snapshot,
			}
		)
	)
	var canonical := CampaignCodecType.normalize_data(working, context)
	if not canonical["accepted"]:
		return _reject(&"invalid_argument_type")
	data.clear()
	data.merge((canonical["value"] as Dictionary).duplicate(true), true)
	return _accepted(data["promotion_receipts"][-1])


static func normalize_command(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _reject(&"invalid_argument_type")
	var command := value as Dictionary
	if not _exact_keys(command, COMMAND_KEYS):
		return _reject(&"invalid_argument_type")
	for key: String in ["version", "expected_save_revision"]:
		if typeof(command[key]) != TYPE_INT:
			return _reject(&"invalid_argument_type")
	for key: String in ["verb", "command_id", "hero_id", "advanced_class_id"]:
		if not _is_ascii_string(command[key]):
			return _reject(&"invalid_argument_type")
	if (
		int(command["version"]) != 1
		or command["verb"] != "promote_hero"
		or int(command["expected_save_revision"]) < 1
		or int(command["expected_save_revision"]) > U63_MAX
		or not _is_hex(String(command["hero_id"]), 16)
	):
		return _reject(&"invalid_argument_type")
	var ordered := {}
	for key: String in COMMAND_KEYS:
		ordered[key] = (
			int(command[key])
			if key in ["version", "expected_save_revision"]
			else String(command[key])
		)
	return _accept(ordered)


static func command_id(
	campaign_uid: String,
	expected_save_revision: int,
	hero_id: String,
	advanced_class_id: String,
) -> String:
	return (
		"promote:%s:%d:%s:%s"
		% [
			campaign_uid,
			expected_save_revision,
			hero_id,
			advanced_class_id,
		]
	)


static func replay_row(seq: int, command: Dictionary) -> Dictionary:
	var normalized := normalize_command(command)
	if not normalized["accepted"] or seq < 1:
		return {}
	var value: Dictionary = normalized["value"]
	var args := {}
	for key: String in REPLAY_ARG_KEYS:
		args[key] = value[key]
	return {"seq": seq, "verb": "promote_hero", "args": args}


static func encode_replay_rows(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return _reject(&"invalid_argument_type")
	var rows: Array[Dictionary] = []
	var expected_seq := 1
	for item: Variant in value:
		if typeof(item) != TYPE_DICTIONARY:
			return _reject(&"invalid_argument_type")
		var row := item as Dictionary
		if (
			not _exact_keys(row, REPLAY_ROW_KEYS)
			or typeof(row["seq"]) != TYPE_INT
			or int(row["seq"]) != expected_seq
			or row["verb"] != "promote_hero"
			or typeof(row["args"]) != TYPE_DICTIONARY
			or not _exact_keys(row["args"], REPLAY_ARG_KEYS)
		):
			return _reject(&"invalid_argument_type")
		var args := row["args"] as Dictionary
		var command := {
			"version": args["version"],
			"verb": "promote_hero",
			"command_id": args["command_id"],
			"hero_id": args["hero_id"],
			"advanced_class_id": args["advanced_class_id"],
			"expected_save_revision": args["expected_save_revision"],
		}
		var normalized := normalize_command(command)
		if not normalized["accepted"]:
			return normalized
		rows.append(replay_row(expected_seq, normalized["value"]))
		expected_seq += 1
	var text := CanonicalJsonType.text(rows)
	return {
		"accepted": true,
		"error_code": &"",
		"value": rows,
		"text": text,
		"bytes": text.to_utf8_buffer(),
		"sha256": CanonicalJsonType.sha256_text(text),
	}


static func replay_result(result: Dictionary, state: Variant) -> Dictionary:
	var receipt_bytes: Array[int] = []
	if bool(result.get("accepted", false)):
		for byte: int in result["receipt_bytes"]:
			receipt_bytes.append(byte)
	return {
		"accepted": bool(result.get("accepted", false)),
		"error_code": String(result.get("error_code", &"")),
		"receipt_bytes": receipt_bytes,
		"save_revision": int(state.save_revision()),
		"strategic_hash": String(state.strategic_hash()["hex"]),
	}


static func _receipt(
	command: Dictionary,
	prior_operator_def_id: String,
	new_operator_def_id: String,
	before_hash: String,
	new_revision: int,
) -> Dictionary:
	return {
		"version": 1,
		"command_id": command["command_id"],
		"verb": "promote_hero",
		"hero_id": command["hero_id"],
		"prior_class_id": "mage_apprentice",
		"new_class_id": command["advanced_class_id"],
		"prior_operator_def_id": prior_operator_def_id,
		"new_operator_def_id": new_operator_def_id,
		"prior_save_revision": command["expected_save_revision"],
		"new_save_revision": new_revision,
		"before_strategic_hash": before_hash,
		"after_strategic_hash": "0000000000000000",
	}


static func _accepted(receipt: Dictionary) -> Dictionary:
	var canonical := {}
	for key: String in RECEIPT_KEYS:
		canonical[key] = receipt[key]
	return {
		"accepted": true,
		"error_code": &"",
		"receipt": canonical,
		"receipt_bytes": CanonicalJsonType.text(canonical).to_utf8_buffer(),
	}


static func _command_from_receipt(receipt: Dictionary) -> Dictionary:
	return {
		"version": receipt["version"],
		"verb": receipt["verb"],
		"command_id": receipt["command_id"],
		"hero_id": receipt["hero_id"],
		"advanced_class_id": receipt["new_class_id"],
		"expected_save_revision": receipt["prior_save_revision"],
	}


static func _receipt_by_command_id(rows: Array, command_id_value: String) -> Dictionary:
	for receipt: Dictionary in rows:
		if receipt["command_id"] == command_id_value:
			return receipt
	return {}


static func _hero_by_id(rows: Array, hero_id: String) -> Dictionary:
	for hero: Dictionary in rows:
		if hero["hero_id"] == hero_id:
			return hero
	return {}


static func _proof_snapshot(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result["promotion_proofs"] = []
	if result["resolution_anchor"] != null:
		result["resolution_anchor"]["before_core"]["promotion_proofs"] = []
		result["resolution_anchor"]["after_core"]["promotion_proofs"] = []
	return result


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	var actual: Array = value.keys()
	for index: int in expected.size():
		if actual[index] != expected[index]:
			return false
	return true


static func _is_ascii_string(value: Variant) -> bool:
	if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return false
	var text := String(value)
	if text.is_empty():
		return false
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


static func _accept(value: Variant) -> Dictionary:
	return {"accepted": true, "error_code": &"", "value": value}


static func _reject(error_code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": error_code}
