class_name CampaignBattleTicket
extends RefCounted

## Immutable view over one fully validated P16 CampaignBattleTicket row.

var _data: Dictionary = {}
var _text := ""
var _sha256 := ""


static func from_data(value: Variant) -> Dictionary:
	var encoded := CampaignCodec.encode_ticket(value)
	if not encoded["accepted"]:
		return _reject(encoded["error_code"])
	var ticket := CampaignBattleTicket.new()
	ticket._data = (encoded["value"] as Dictionary).duplicate(true)
	ticket._text = String(encoded["text"])
	ticket._sha256 = String(encoded["sha256"])
	return {"accepted": true, "error_code": &"", "value": ticket}


func campaign_uid() -> String:
	return String(_data["campaign_uid"])


func attempt_id() -> int:
	return int(_data["attempt_id"])


func stage_id() -> StringName:
	return StringName(_data["stage_id"])


func manifest() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in _data["manifest"]:
		result.append(row.duplicate(true))
	return result


func manifest_hash() -> String:
	return String(_data["manifest_hash"])


func data_copy() -> Dictionary:
	return _data.duplicate(true)


func canonical_text() -> String:
	return _text


func canonical_sha256() -> String:
	return _sha256


static func _reject(code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": code, "value": null}
