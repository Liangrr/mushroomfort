class_name CampaignPromotionReceiptCodec
extends RefCounted

const U63_MAX := 9_223_372_036_854_775_807
const RECEIPT_KEYS := [
	"version", "command_id", "verb", "hero_id", "prior_class_id", "new_class_id",
	"prior_operator_def_id", "new_operator_def_id", "prior_save_revision",
	"new_save_revision", "before_strategic_hash", "after_strategic_hash",
]


static func normalize(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return _reject(&"invalid_promotion_receipts")
	var rows: Array[Dictionary] = []
	var command_ids := {}
	var hero_ids := {}
	var previous_revision := 0
	for item: Variant in value:
		if typeof(item) != TYPE_DICTIONARY:
			return _reject(&"invalid_promotion_receipt")
		var receipt := item as Dictionary
		if not _exact_keys(receipt, RECEIPT_KEYS):
			return _reject(&"invalid_promotion_receipt")
		for key: String in ["version", "prior_save_revision", "new_save_revision"]:
			if typeof(receipt[key]) != TYPE_INT:
				return _reject(&"invalid_promotion_receipt")
		if int(receipt["version"]) != 1:
			return _reject(&"invalid_promotion_receipt")
		var prior_revision := int(receipt["prior_save_revision"])
		var new_revision := int(receipt["new_save_revision"])
		if (
			prior_revision < 1 or prior_revision >= U63_MAX
			or new_revision != prior_revision + 1
			or prior_revision <= previous_revision
		):
			return _reject(&"invalid_promotion_receipt")
		for key: String in [
			"command_id", "prior_class_id", "new_class_id",
			"prior_operator_def_id", "new_operator_def_id",
		]:
			if not _is_ascii_string(receipt[key]):
				return _reject(&"invalid_promotion_receipt")
		if receipt["verb"] != "promote_hero":
			return _reject(&"invalid_promotion_receipt")
		var hero_id := String(receipt["hero_id"])
		var command_id := String(receipt["command_id"])
		if (
			not _is_hex(hero_id, 16)
			or not _is_hex(String(receipt["before_strategic_hash"]), 16)
			or not _is_hex(String(receipt["after_strategic_hash"]), 16)
			or command_ids.has(command_id) or hero_ids.has(hero_id)
		):
			return _reject(&"invalid_promotion_receipt")
		command_ids[command_id] = true
		hero_ids[hero_id] = true
		previous_revision = prior_revision
		var ordered := {}
		for key: String in RECEIPT_KEYS:
			ordered[key] = (
				int(receipt[key])
				if key in ["version", "prior_save_revision", "new_save_revision"]
				else String(receipt[key])
			)
		rows.append(ordered)
	return {"accepted": true, "error_code": &"", "value": rows}


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


static func _reject(error_code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": error_code}
