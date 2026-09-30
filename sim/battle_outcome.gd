class_name BattleOutcome
extends RefCounted

## Immutable view over one fully validated terminal P16 BattleOutcome row.

var _data: Dictionary = {}
var _text := ""
var _sha256 := ""


static func from_data(value: Variant) -> Dictionary:
	var encoded := CampaignCodec.encode_outcome(value)
	if not encoded["accepted"]:
		return _reject(encoded["error_code"])
	var outcome := BattleOutcome.new()
	outcome._data = (encoded["value"] as Dictionary).duplicate(true)
	outcome._text = String(encoded["text"])
	outcome._sha256 = String(encoded["sha256"])
	return {"accepted": true, "error_code": &"", "value": outcome}


func schema_version() -> int:
	return int(_data["schema_version"])


func campaign_uid() -> String:
	return String(_data["campaign_uid"])


func attempt_id() -> int:
	return int(_data["attempt_id"])


func stage_id() -> StringName:
	return StringName(_data["stage_id"])


func manifest_hash() -> String:
	return String(_data["manifest_hash"])


func result() -> StringName:
	return StringName(_data["result"])


func terminal_reason() -> StringName:
	return StringName(_data["terminal_reason"])


func stars() -> int:
	return int(_data["stars"])


func terminal_tick() -> int:
	return int(_data["terminal_tick"])


func model_state_hash() -> String:
	return String(_data["model_state_hash"])


func heroes() -> Array[Dictionary]:
	var result_rows: Array[Dictionary] = []
	for row: Dictionary in _data["heroes"]:
		result_rows.append(row.duplicate(true))
	return result_rows


func outcome_hash() -> String:
	return String(_data["outcome_hash"])


func data_copy() -> Dictionary:
	return _data.duplicate(true)


func canonical_text() -> String:
	return _text


func canonical_sha256() -> String:
	return _sha256


static func _reject(code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": code, "value": null}
