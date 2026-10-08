extends Node
## Free Supabase-backed cloud progress and leaderboard client.
## The game remains playable offline; network failures fall back to local Save.

signal cloud_loaded
signal cloud_saved
signal score_submitted(level_id: String, rank: int)
signal leaderboard_loaded(level_id: String, entries: Array)
signal request_failed(operation: String, message: String)

const CONFIG_PATH := "res://data/cloud.json"
const PLAYER_PATH := "user://mushroom_garrison_cloud.cfg"
const DEFAULT_NICKNAME := "蘑菇守卫"

var enabled := false
var rest_url := ""
var api_key := ""
var player_id := ""
var nickname := DEFAULT_NICKNAME


func _ready() -> void:
	_load_config()
	_load_player()
	if enabled:
		call_deferred("sync_progress")


func _load_config() -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var json: Variant = JSON.parse_string(file.get_as_text())
	if typeof(json) != TYPE_DICTIONARY:
		return
	enabled = bool(json.get("enabled", false))
	rest_url = str(json.get("rest_url", "")).trim_suffix("/")
	api_key = str(json.get("publishable_key", ""))
	if rest_url.is_empty() or api_key.is_empty():
		enabled = false


func _load_player() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PLAYER_PATH) == OK:
		player_id = str(cfg.get_value("player", "id", ""))
		nickname = str(cfg.get_value("player", "nickname", DEFAULT_NICKNAME))
	if player_id.is_empty():
		player_id = _new_player_id()
		_save_player()
	if nickname.strip_edges().is_empty():
		nickname = DEFAULT_NICKNAME


func _new_player_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x-%08x-%08x-%08x" % [
		int(Time.get_unix_time_from_system()),
		rng.randi(),
		rng.randi(),
		rng.randi()
	]


func _save_player() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "id", player_id)
	cfg.set_value("player", "nickname", nickname)
	cfg.save(PLAYER_PATH)


func is_available() -> bool:
	return enabled and not rest_url.is_empty() and not api_key.is_empty()


func get_player_id() -> String:
	return player_id


func set_nickname(value: String) -> void:
	var clean := value.strip_edges().substr(0, 16)
	nickname = clean if not clean.is_empty() else DEFAULT_NICKNAME
	_save_player()


func sync_progress() -> void:
	if not is_available():
		return
	var url := "%s/mushroom_cloud_saves?select=payload&player_id=eq.%s&limit=1" % [rest_url, player_id.uri_encode()]
	_request("sync_progress", HTTPClient.METHOD_GET, url, "", func(body: String, code: int) -> void:
		if code < 200 or code >= 300:
			_fail("sync_progress", "HTTP %d" % code)
			return
		var rows: Variant = JSON.parse_string(body)
		if typeof(rows) == TYPE_ARRAY and not rows.is_empty():
			var payload: Variant = rows[0].get("payload", {})
			if typeof(payload) == TYPE_DICTIONARY:
				Save.merge_cloud_snapshot(payload)
		cloud_loaded.emit()
	)


func save_progress() -> void:
	if not is_available():
		return
	var payload := Save.cloud_snapshot()
	var body := JSON.stringify({
		"player_id": player_id,
		"save_version": 1,
		"payload": payload,
		"updated_at": Time.get_datetime_string_from_system(true)
	})
	var headers := PackedStringArray(["Prefer: resolution=merge-duplicates"])
	_request("save_progress", HTTPClient.METHOD_POST, "%s/mushroom_cloud_saves" % rest_url, body, func(_response: String, code: int) -> void:
		if code < 200 or code >= 300:
			_fail("save_progress", "HTTP %d" % code)
			return
		cloud_saved.emit()
	, headers)


func submit_score(level_id: String, score: int, stars: int, lives: int) -> void:
	if not is_available() or score < 0:
		return
	var safe_level := level_id.uri_encode()
	var lookup := "%s/mushroom_leaderboard_scores?select=score&level_id=eq.%s&player_id=eq.%s&limit=1" % [rest_url, safe_level, player_id.uri_encode()]
	_request("score_lookup", HTTPClient.METHOD_GET, lookup, "", func(body: String, code: int) -> void:
		if code < 200 or code >= 300:
			_fail("score_lookup", "HTTP %d" % code)
			return
		var rows: Variant = JSON.parse_string(body)
		if typeof(rows) == TYPE_ARRAY and not rows.is_empty() and int(rows[0].get("score", 0)) >= score:
			return
		var record := {
			"level_id": level_id,
			"player_id": player_id,
			"nickname": nickname,
			"score": score,
			"stars": stars,
			"lives": lives,
			"game_version": str(GameVersion.info.get("version", "0.1.0"))
		}
		var headers := PackedStringArray(["Prefer: resolution=merge-duplicates"])
		_request("submit_score", HTTPClient.METHOD_POST, "%s/mushroom_leaderboard_scores" % rest_url, JSON.stringify(record), func(response: String, submit_code: int) -> void:
			if submit_code < 200 or submit_code >= 300:
				_fail("submit_score", "HTTP %d" % submit_code)
				return
			var rank: int = await _get_rank(level_id, score)
			score_submitted.emit(level_id, rank)
		, headers)
	)


func fetch_leaderboard(level_id: String, limit := 20) -> void:
	if not is_available():
		leaderboard_loaded.emit(level_id, [])
		return
	var url := "%s/mushroom_leaderboard_scores?select=nickname,score,stars,lives,game_version,updated_at&level_id=eq.%s&order=score.desc,updated_at.asc&limit=%d" % [rest_url, level_id.uri_encode(), clampi(limit, 1, 100)]
	_request("leaderboard", HTTPClient.METHOD_GET, url, "", func(body: String, code: int) -> void:
		if code < 200 or code >= 300:
			_fail("leaderboard", "HTTP %d" % code)
			leaderboard_loaded.emit(level_id, [])
			return
		var rows: Variant = JSON.parse_string(body)
		leaderboard_loaded.emit(level_id, rows if typeof(rows) == TYPE_ARRAY else [])
	)


func _get_rank(level_id: String, score: int) -> int:
	var url := "%s/mushroom_leaderboard_scores?select=id&level_id=eq.%s&score=gt.%d" % [rest_url, level_id.uri_encode(), score]
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	var err := request.request(url, _headers())
	if err != OK:
		request.queue_free()
		return 0
	var result: Array = await request.request_completed
	request.queue_free()
	if result.size() < 4 or int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return 0
	var rows: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	return (rows.size() + 1) if typeof(rows) == TYPE_ARRAY else 0


func _headers(extra := PackedStringArray()) -> PackedStringArray:
	var headers := PackedStringArray([
		"apikey: %s" % api_key,
		"Authorization: Bearer %s" % api_key,
		"Content-Type: application/json"
	])
	headers.append_array(extra)
	return headers


func _request(operation: String, method: HTTPClient.Method, url: String, body: String, callback: Callable, extra_headers := PackedStringArray()) -> void:
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(func(result: int, response_code: int, _headers_received: PackedStringArray, response_body: PackedByteArray) -> void:
		request.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS:
			_fail(operation, "网络不可用")
			return
		callback.call(response_body.get_string_from_utf8(), response_code)
	)
	var err := request.request(url, _headers(extra_headers), method, body)
	if err != OK:
		request.queue_free()
		_fail(operation, "请求无法启动")


func _fail(operation: String, message: String) -> void:
	request_failed.emit(operation, message)
