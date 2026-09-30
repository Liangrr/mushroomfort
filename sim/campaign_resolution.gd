class_name CampaignResolution
extends "res://sim/campaign_resolution_fields.gd"

## Immutable view over one fully validated P16 CampaignResolution receipt.


static func from_data(value: Variant) -> Dictionary:
	var encoded := CampaignCodec.encode_resolution(value)
	if not encoded["accepted"]:
		return _reject(encoded["error_code"])
	var receipt := CampaignResolution.new()
	receipt._data = (encoded["value"] as Dictionary).duplicate(true)
	receipt._text = String(encoded["text"])
	receipt._sha256 = String(encoded["sha256"])
	return {"accepted": true, "error_code": &"", "value": receipt}


func stars_after() -> int:
	return int(_data["stars_after"])


func rewards_granted() -> Array[Dictionary]:
	return _dictionary_rows("rewards_granted")


func created_hero_ids() -> Array[String]:
	return _string_rows("created_hero_ids")


func dead_hero_ids() -> Array[String]:
	return _string_rows("dead_hero_ids")


func marks_before() -> int:
	return int(_data["marks_before"])


func marks_after() -> int:
	return int(_data["marks_after"])


func strategic_body_hash_before() -> String:
	return String(_data["strategic_body_hash_before"])


func strategic_body_hash_after() -> String:
	return String(_data["strategic_body_hash_after"])


func data_copy() -> Dictionary:
	return _data.duplicate(true)


func canonical_text() -> String:
	return _text


func canonical_sha256() -> String:
	return _sha256


func _dictionary_rows(key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in _data[key]:
		result.append(row.duplicate(true))
	return result


func _string_rows(key: String) -> Array[String]:
	var result: Array[String] = []
	for value: String in _data[key]:
		result.append(value)
	return result


static func _reject(code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": code, "value": null}
