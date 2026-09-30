class_name MissionLeaderboardService
extends Node

## Offline-first mission leaderboard. Authoritative mission completion records
## locally before this service attempts any network work.

signal state_changed

const SCHEMA_VERSION := 1
const SCORE_VERSION := 1
const DISPLAY_LIMIT := 10
const LOCAL_LIMIT := 50
const LOCAL_GROUPS := ["normal", "hard", "practice", "legacy"]
const PENDING_LIMIT := 100
const API_PATH := "/api/leaderboard"
const DEFAULT_SAVE_PATH := "user://leaderboard.json"
const DEFAULT_PLAYER_NAME := "STORYKEEPER"
const MAX_PLAYER_NAME_LENGTH := 16
const MAX_KILLS := 500
const MAX_LEAKS := 100
const MAX_SCORE := 4_000_000

var save_path := DEFAULT_SAVE_PATH
var entries: Array[Dictionary] = []
var status: StringName = &"idle"
var last_operation: StringName = &""
var submitted_entry: Dictionary = {}

var _data: Dictionary = {}
var _http: HTTPRequest = null
var _base_url := ""
var _allow_headless_requests := false
var _active_submission_id := ""
var _latest_submission_id := ""
var _clearing_player_data := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "LeaderboardRequest"
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_data = _load_data()
	_base_url = _resolve_base_url()
	_allow_headless_requests = bool(ProjectSettings.get_setting(
		"leaderboard/enable_in_headless", false,
	))
	status = &"idle" if _can_request() else &"offline"
	if pending_count() > 0:
		_data["pending_submissions"] = []


func player_name() -> String:
	return String(_data.get("player_name", DEFAULT_PLAYER_NAME))


func set_player_name(candidate: String) -> String:
	var normalized := normalize_player_name(candidate)
	if normalized == player_name():
		return normalized
	_data["player_name"] = normalized
	_save_data()
	state_changed.emit()
	return normalized


func local_entries(limit: int = DISPLAY_LIMIT) -> Array[Dictionary]:
	return _local_entries_filtered("", limit)


func local_entries_for_mode(hard: bool, limit: int = DISPLAY_LIMIT) -> Array[Dictionary]:
	return local_entries_for_group("hard" if hard else "normal", limit)


func local_entries_for_group(group: String, limit: int = DISPLAY_LIMIT) -> Array[Dictionary]:
	if group not in LOCAL_GROUPS:
		return []
	return _local_entries_filtered(group, limit)


func _local_entries_filtered(group: String, limit: int) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var maximum := clampi(limit, 0, LOCAL_LIMIT)
	for stored: Dictionary in _data.get("local_scores", []):
		if records.size() >= maximum:
			break
		if not group.is_empty() and String(stored.get("ranking_group", "legacy")) != group:
			continue
		var record := stored.duplicate(true)
		record["rank"] = records.size() + 1
		records.append(record)
	return records


func pending_count() -> int:
	return (_data.get("pending_submissions", []) as Array).size()


func latest_submission_id() -> String:
	return _latest_submission_id


## Freeze the local identity before writing so a failed write can be retried
## independently of an already committed campaign outcome.
func prepare_mission(result: Dictionary) -> Dictionary:
	if _clearing_player_data:
		return {}
	var record := _submission_from_result(result)
	if record.is_empty():
		return {}
	record["score"] = calculate_score(record)
	record["created_at"] = Time.get_datetime_string_from_system(true)
	return record


func record_mission(result: Dictionary) -> Dictionary:
	return store_record(prepare_mission(result))


func store_record(prepared: Dictionary) -> Dictionary:
	if _clearing_player_data:
		return {}
	var record := _sanitize_saved_record(prepared)
	if record.is_empty():
		return {}
	for existing: Dictionary in _data.get("local_scores", []):
		if existing["submission_id"] == record["submission_id"]:
			# An identity is immutable, including its timestamp and provenance.
			return existing.duplicate(true) if existing == record else {}
	var previous := _data
	_data = previous.duplicate(true)
	var local_scores: Array = _data.get("local_scores", [])
	local_scores.append(record)
	_data["local_scores"] = _bounded_local_scores(local_scores)
	_data["pending_submissions"] = []
	if not _save_data():
		_data = previous
		status = &"error"
		last_operation = &"local_save"
		state_changed.emit()
		return {}
	_latest_submission_id = String(record["submission_id"])
	status = &"offline"
	last_operation = &"local_save"
	state_changed.emit()
	return record.duplicate(true)


static func _bounded_local_scores(records: Array) -> Array:
	sort_entries(records)
	var kept: Array = []
	var counts: Dictionary = {}
	var seen: Dictionary = {}
	for record: Dictionary in records:
		var group := String(record.get("ranking_group", "legacy"))
		var identity := String(record.get("submission_id", ""))
		if seen.has(identity) or int(counts.get(group, 0)) >= LOCAL_LIMIT:
			continue
		seen[identity] = true
		counts[group] = int(counts.get(group, 0)) + 1
		kept.append(record)
	return kept


func sync() -> void:
	if _clearing_player_data:
		return
	if not _can_request():
		_set_state(&"offline", &"submit" if pending_count() > 0 else &"fetch")
		return
	if pending_count() > 0:
		_submit_next()
	else:
		_fetch_scores()


func prepare_for_player_data_clear() -> void:
	_clearing_player_data = true
	_cancel_active_request()


func finish_player_data_clear(succeeded: bool) -> void:
	_clearing_player_data = false
	_active_submission_id = ""
	_latest_submission_id = ""
	entries.clear()
	submitted_entry.clear()
	_data = _default_data() if succeeded else _load_data()
	status = &"idle" if _can_request() else &"offline"
	last_operation = &""
	state_changed.emit()


## Test seam used only from repository tests, which already run in disposable
## user:// directories through tools/run_godot_test.sh.
func configure_for_testing(test_save_path: String, test_base_url: String) -> void:
	_cancel_active_request()
	save_path = test_save_path
	_data = _load_data()
	entries.clear()
	submitted_entry.clear()
	_active_submission_id = ""
	_latest_submission_id = ""
	_base_url = test_base_url.strip_edges().trim_suffix("/")
	_allow_headless_requests = true
	status = &"idle" if _can_request() else &"offline"
	last_operation = &""
	state_changed.emit()


func clear_for_testing() -> void:
	_cancel_active_request()
	for suffix: String in ["", ".tmp", ".bak"]:
		var path := save_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_data = _default_data()
	entries.clear()
	submitted_entry.clear()
	_active_submission_id = ""
	_latest_submission_id = ""
	status = &"idle" if _can_request() else &"offline"
	last_operation = &""
	state_changed.emit()


func _submission_from_result(result: Dictionary) -> Dictionary:
	if typeof(result.get("stage_id")) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return {}
	var stage_id := String(result.get("stage_id", ""))
	if mission_number(stage_id) == 0 or not _score_components_valid(result):
		return {}
	if not _whole_number(result.get("result", -1)):
		return {}
	var outcome := int(result.get("result", -1))
	if outcome not in [BattleModel.Result.CLEAR, BattleModel.Result.DEFEAT]:
		return {}
	var submission: Dictionary = {
		"submission_id": _new_submission_id(),
		"name": player_name(),
		"stage_id": stage_id,
		"victory": outcome == BattleModel.Result.CLEAR,
		"stars": clampi(int(result.get("stars", 0)), 0, 3),
		"kills": clampi(int(result.get("kills", 0)), 0, MAX_KILLS),
		"leaks": clampi(int(result.get("leaks", 0)), 0, MAX_LEAKS),
		"score_version": SCORE_VERSION,
	}
	submission.merge(_run_fields(result), true)
	return submission


func _new_submission_id() -> String:
	var random_bytes := Crypto.new().generate_random_bytes(16)
	return "%d-%s" % [int(Time.get_unix_time_from_system()), random_bytes.hex_encode()]


func _fetch_scores() -> void:
	_cancel_active_request()
	_active_submission_id = ""
	_set_state(&"loading", &"fetch")
	var error := _http.request(
		_base_url + API_PATH + "?limit=%d" % DISPLAY_LIMIT,
		PackedStringArray(["Accept: application/json"]),
		HTTPClient.METHOD_GET,
	)
	if error != OK:
		_set_state(&"error", &"fetch")


func _submit_next() -> void:
	var pending: Array = _data.get("pending_submissions", [])
	if pending.is_empty():
		_fetch_scores()
		return
	_cancel_active_request()
	var submission := pending.front() as Dictionary
	_active_submission_id = String(submission.get("submission_id", ""))
	_set_state(&"loading", &"submit")
	var error := _http.request(
		_base_url + API_PATH,
		PackedStringArray(["Accept: application/json", "Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(submission),
	)
	if error != OK:
		_set_state(&"error", &"submit")


func _on_request_completed(
		result: int,
		response_code: int,
		_headers: PackedStringArray,
		body: PackedByteArray,
	) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_set_state(&"error", last_operation)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not (parsed as Dictionary).get("entries", []) is Array:
		_set_state(&"error", last_operation)
		return
	var response := parsed as Dictionary
	entries = _sanitize_public_entries(response.get("entries", []))
	var raw_submitted: Variant = response.get("entry", {})
	if raw_submitted is Dictionary:
		submitted_entry = (raw_submitted as Dictionary).duplicate(true)
	if last_operation == &"submit":
		var pending: Array = _data.get("pending_submissions", [])
		if (
			not pending.is_empty()
			and String((pending.front() as Dictionary).get("submission_id", ""))
			== _active_submission_id
		):
			pending.pop_front()
			_data["pending_submissions"] = pending
			_save_data()
		_active_submission_id = ""
		_set_state(&"ready", &"submit")
		if pending_count() > 0:
			call_deferred("_submit_next")
		return
	_set_state(&"ready", &"fetch")


func _sanitize_public_entries(raw_entries: Array) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	for raw: Variant in raw_entries:
		if not raw is Dictionary or sanitized.size() >= DISPLAY_LIMIT:
			continue
		var row := raw as Dictionary
		var stage_id := String(row.get("stage_id", ""))
		if mission_number(stage_id) == 0:
			continue
		sanitized.append({
			"rank": clampi(int(row.get("rank", sanitized.size() + 1)), 1, 1000),
			"name": normalize_player_name(String(row.get("name", DEFAULT_PLAYER_NAME))),
			"score": clampi(int(row.get("score", 0)), 0, MAX_SCORE),
			"stage_id": stage_id,
			"victory": bool(row.get("victory", false)),
			"stars": clampi(int(row.get("stars", 0)), 0, 3),
			"created_at": String(row.get("created_at", "")),
		})
	return sanitized


func _resolve_base_url() -> String:
	if OS.has_feature("web"):
		var origin: Variant = JavaScriptBridge.eval("window.location.origin", true)
		if origin is String and (
			String(origin).begins_with("https://")
			or String(origin).begins_with("http://")
		):
			return String(origin).trim_suffix("/")
	return String(ProjectSettings.get_setting(
		"leaderboard/api_base_url", "",
	)).strip_edges().trim_suffix("/")


func _can_request() -> bool:
	return false


func _cancel_active_request() -> void:
	if _http != null and _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()


func _set_state(next_status: StringName, operation: StringName) -> void:
	status = next_status
	last_operation = operation
	state_changed.emit()


func _load_data() -> Dictionary:
	for candidate: String in [save_path, save_path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		var parser := JSON.new()
		var parsed_ok := parser.parse(file.get_as_text()) == OK
		file.close()
		var parsed: Variant = parser.data if parsed_ok else null
		if parsed is Dictionary:
			var sanitized := _sanitize_data(parsed as Dictionary)
			if not sanitized.is_empty():
				return sanitized
	return _default_data()


func _sanitize_data(raw: Dictionary) -> Dictionary:
	if not _whole_number(raw.get("schema_version")) or int(raw.schema_version) != SCHEMA_VERSION:
		return {}
	var sanitized := _default_data()
	if raw.get("player_name") is String:
		sanitized["player_name"] = normalize_player_name(raw.player_name)
	var local_scores: Array = []
	var raw_local: Variant = raw.get("local_scores", [])
	if raw_local is Array:
		for value: Variant in raw_local:
			var record := _sanitize_saved_record(value)
			if not record.is_empty():
				local_scores.append(record)
	sanitized["local_scores"] = _bounded_local_scores(local_scores)
	sanitized["pending_submissions"] = []
	return sanitized


func _sanitize_saved_record(value: Variant) -> Dictionary:
	var submission := _sanitize_submission(value)
	if submission.is_empty():
		return {}
	var raw := value as Dictionary
	if not raw.get("created_at", "") is String:
		return {}
	var record := submission.duplicate(true)
	record["score"] = calculate_score(submission)
	record["created_at"] = String(raw.get("created_at", ""))
	return record


func _sanitize_submission(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var raw := value as Dictionary
	if not raw.get("submission_id") is String or not raw.get("stage_id") is String:
		return {}
	if not raw.get("name", DEFAULT_PLAYER_NAME) is String or typeof(raw.get("victory", false)) != TYPE_BOOL:
		return {}
	if not _whole_number(raw.get("score_version")) or not _score_components_valid(raw):
		return {}
	var submission_id := String(raw.get("submission_id", ""))
	var stage_id := String(raw.get("stage_id", ""))
	if (
		int(raw.get("score_version", 0)) != SCORE_VERSION
		or not _valid_submission_id(submission_id)
		or mission_number(stage_id) == 0
	):
		return {}
	var submission: Dictionary = {
		"submission_id": submission_id,
		"name": normalize_player_name(String(raw.get("name", DEFAULT_PLAYER_NAME))),
		"stage_id": stage_id,
		"victory": bool(raw.get("victory", false)),
		"stars": clampi(int(raw.get("stars", 0)), 0, 3),
		"kills": clampi(int(raw.get("kills", 0)), 0, MAX_KILLS),
		"leaks": clampi(int(raw.get("leaks", 0)), 0, MAX_LEAKS),
		"score_version": SCORE_VERSION,
	}
	submission.merge(_run_fields(raw), true)
	return submission


static func _run_fields(raw: Dictionary) -> Dictionary:
	# A missing mode/config marker cannot establish historical eligibility.
	# In particular v56 wrote Hard runs without a mode bit.
	var legacy: Dictionary = {"ranking_group": "legacy"}
	if not _whole_number(raw.get("run_metadata_version")) or int(raw.run_metadata_version) != 1:
		return legacy
	if typeof(raw.get("hard_mode")) != TYPE_BOOL or typeof(raw.get("tuning_ranked_eligible")) != TYPE_BOOL:
		return legacy
	var terminal: Variant = raw.get("terminal_tick")
	var rate: Variant = raw.get("ticks_per_second")
	if not _nonnegative_integer(terminal) or not _nonnegative_integer(rate) or int(rate) == 0:
		return legacy
	if not raw.get("run_config_hash") is String or not raw.get("tuning_config_hash") is String:
		return legacy
	var config_hash := String(raw.get("run_config_hash", ""))
	var tuning_hash := String(raw.get("tuning_config_hash", ""))
	for digest: String in [config_hash, tuning_hash]:
		if digest.length() != 64 or not digest.is_valid_hex_number(false):
			return legacy
	var raw_reasons: Variant = raw.get("tuning_reasons")
	if not raw_reasons is Array:
		return legacy
	var reasons: Array[String] = []
	for reason: Variant in raw_reasons:
		if not reason is String or String(reason).is_empty():
			return legacy
		if not reasons.has(reason):
			reasons.append(reason)
	reasons.sort()
	var eligible: bool = bool(raw.tuning_ranked_eligible) and reasons.is_empty()
	return {
		"run_metadata_version": 1,
		"hard_mode": bool(raw.hard_mode),
		"terminal_tick": int(terminal),
		"ticks_per_second": int(rate),
		"duration_seconds": float(terminal) / int(rate),
		"run_config_hash": config_hash.to_lower(),
		"tuning_config_hash": tuning_hash.to_lower(),
		"tuning_ranked_eligible": eligible,
		"tuning_reasons": reasons,
		"ranking_group": ("hard" if raw.hard_mode else "normal") if eligible else "practice",
	}


static func _nonnegative_integer(value: Variant) -> bool:
	return _whole_number(value) and float(value) >= 0


static func _whole_number(value: Variant) -> bool:
	# JSON reloads numbers as floats. Bound them to the exact integer range
	# before casts, so corrupt/overflowing values cannot acquire valid metadata.
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and absf(float(value)) <= 9_007_199_254_740_991.0 and float(value) == floorf(float(value))


static func _score_components_valid(value: Dictionary) -> bool:
	for field: String in ["stars", "kills", "leaks"]:
		if not _whole_number(value.get(field, 0)):
			return false
	return true


func _save_data() -> bool:
	if _clearing_player_data:
		return false
	var directory := ProjectSettings.globalize_path(save_path.get_base_dir())
	if (
		not DirAccess.dir_exists_absolute(directory)
		and DirAccess.make_dir_recursive_absolute(directory) != OK
	):
		return false
	var temporary_path := save_path + ".tmp"
	var backup_path := save_path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_data, "", true, true) + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false
	var save_absolute := ProjectSettings.globalize_path(save_path)
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_absolute)
	if FileAccess.file_exists(save_path):
		if DirAccess.rename_absolute(save_absolute, backup_absolute) != OK:
			DirAccess.remove_absolute(temporary_absolute)
			return false
	if DirAccess.rename_absolute(temporary_absolute, save_absolute) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_absolute, save_absolute)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_absolute)
	return true


func _default_data() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"player_name": DEFAULT_PLAYER_NAME,
		"local_scores": [],
		"pending_submissions": [],
	}


static func calculate_score(mission: Dictionary) -> int:
	return clampi(
		(2_000_000 if bool(mission.get("victory", false)) else 0)
		+ mission_number(String(mission.get("stage_id", ""))) * 100_000
		+ clampi(int(mission.get("stars", 0)), 0, 3) * 20_000
		+ clampi(int(mission.get("kills", 0)), 0, MAX_KILLS) * 50
		- clampi(int(mission.get("leaks", 0)), 0, MAX_LEAKS) * 500,
		0,
		MAX_SCORE,
	)


static func mission_number(stage_id: String) -> int:
	if not stage_id.begins_with("s") or stage_id.length() < 2:
		return 0
	var suffix := stage_id.substr(1)
	if not suffix.is_valid_int():
		return 0
	var value := int(suffix)
	return value if value >= 1 and value <= 10 and stage_id == "s%d" % value else 0


static func normalize_player_name(value: String) -> String:
	var normalized := ""
	var previous_space := false
	var previous_hyphen := false
	for index: int in value.length():
		var character := value.substr(index, 1).to_upper()
		if character == " ":
			if not normalized.is_empty() and not previous_space:
				normalized += character
			previous_space = true
			previous_hyphen = false
		elif character == "-":
			if not normalized.is_empty() and not previous_hyphen:
				normalized += character
			previous_space = false
			previous_hyphen = true
		elif character == "_" or "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".contains(character):
			normalized += character
			previous_space = false
			previous_hyphen = false
		if normalized.length() >= MAX_PLAYER_NAME_LENGTH:
			break
	normalized = normalized.strip_edges().trim_suffix("-")
	return DEFAULT_PLAYER_NAME if normalized.is_empty() else normalized


static func sort_entries(records: Array) -> void:
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := int(left.get("score", 0))
		var right_score := int(right.get("score", 0))
		if left_score != right_score:
			return left_score > right_score
		var left_time := String(left.get("created_at", ""))
		var right_time := String(right.get("created_at", ""))
		if left_time != right_time:
			return left_time < right_time
		return String(left.get("submission_id", "")) < String(right.get("submission_id", ""))
	)


static func _valid_submission_id(value: String) -> bool:
	if value.length() < 8 or value.length() > 96:
		return false
	for character: String in value:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":
			return false
	return true
