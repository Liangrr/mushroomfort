extends RefCounted

## First half of the exact CampaignResolution getter contract. Kept in an
## inherited base solely to honor the project's 20-public-method file limit.

var _data: Dictionary = {}
var _text := ""
var _sha256 := ""


func schema_version() -> int:
	return int(_data["schema_version"])


func resolution_index() -> int:
	return int(_data["resolution_index"])


func campaign_uid() -> String:
	return String(_data["campaign_uid"])


func attempt_id() -> int:
	return int(_data["attempt_id"])


func stage_id() -> StringName:
	return StringName(_data["stage_id"])


func outcome_hash() -> String:
	return String(_data["outcome_hash"])


func result() -> StringName:
	return StringName(_data["result"])


func terminal_reason() -> StringName:
	return StringName(_data["terminal_reason"])


func terminal_tick() -> int:
	return int(_data["terminal_tick"])


func stars_before() -> int:
	return int(_data["stars_before"])
