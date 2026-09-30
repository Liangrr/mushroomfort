class_name CampaignPromotionProofCodec
extends RefCounted

const PROOF_KEYS := ["command_id", "before_data", "after_data"]


static func normalize(value: Variant, snapshot_normalizer: Callable) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return _reject(&"invalid_promotion_proofs")
	var rows: Array[Dictionary] = []
	var command_ids := {}
	for item: Variant in value:
		if typeof(item) != TYPE_DICTIONARY:
			return _reject(&"invalid_promotion_proof")
		var proof := item as Dictionary
		if not _exact_keys(proof, PROOF_KEYS) or not _is_ascii(proof["command_id"]):
			return _reject(&"invalid_promotion_proof")
		var command_id := String(proof["command_id"])
		if command_ids.has(command_id):
			return _reject(&"invalid_promotion_proof")
		var before: Dictionary = snapshot_normalizer.call(proof["before_data"])
		var after: Dictionary = snapshot_normalizer.call(proof["after_data"])
		if not before.get("accepted", false) or not after.get("accepted", false):
			return _reject(&"invalid_promotion_proof")
		command_ids[command_id] = true
		rows.append({
			"command_id": command_id,
			"before_data": before["value"],
			"after_data": after["value"],
		})
	return {"accepted": true, "error_code": &"", "value": rows}


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	var actual: Array = value.keys()
	for index: int in expected.size():
		if actual[index] != expected[index]:
			return false
	return true


static func _is_ascii(value: Variant) -> bool:
	if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return false
	var text := String(value)
	if text.is_empty():
		return false
	for character: String in text:
		if character.unicode_at(0) > 127:
			return false
	return true


static func _reject(error_code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": error_code}
