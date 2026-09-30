extends Node
## Local persistence: settings and per-level best results (user://mushroom_garrison.cfg).

signal settings_changed

const PATH := "user://mushroom_garrison.cfg"
const DEFAULT_SETTINGS := {
	"master": 0.9,
	"music": 0.7,
	"sfx": 0.85,
	"fx_high": true,
	"shake": true,
	"language": "",
}

var _cfg := ConfigFile.new()


func _ready() -> void:
	var err := _cfg.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Save file unreadable (%s); starting fresh." % error_string(err))


func get_setting(key: String, fallback: Variant = null) -> Variant:
	var default_value: Variant = DEFAULT_SETTINGS.get(key, fallback)
	return _cfg.get_value("settings", key, default_value)


func set_setting(key: String, value: Variant) -> void:
	_cfg.set_value("settings", key, value)
	_flush()
	settings_changed.emit()


func level_record(level_id: String) -> Dictionary:
	return {
		"stars": int(_cfg.get_value("levels", level_id + ".stars", 0)),
		"lives": int(_cfg.get_value("levels", level_id + ".lives", 0)),
		"score": int(_cfg.get_value("levels", level_id + ".score", 0)),
		"cleared": bool(_cfg.get_value("levels", level_id + ".cleared", false)),
	}


## Stores a finished run; returns true if it beat the previous best score.
func submit_result(level_id: String, won: bool, stars: int, lives: int, score: int) -> bool:
	var rec := level_record(level_id)
	var is_best: bool = score > int(rec.get("score", 0))
	if won:
		_cfg.set_value("levels", level_id + ".cleared", true)
		_cfg.set_value("levels", level_id + ".stars", maxi(rec.stars, stars))
		_cfg.set_value("levels", level_id + ".lives", maxi(rec.lives, lives))
	if is_best:
		_cfg.set_value("levels", level_id + ".score", score)
	_flush()
	return is_best


func is_level_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	var order: Array = GameData.balance.get("level_order", [])
	if index - 1 >= order.size():
		return false
	return level_record(str(order[index - 1])).cleared


func tutorial_done() -> bool:
	return bool(_cfg.get_value("flags", "tutorial_done", false))


func set_tutorial_done(done: bool) -> void:
	_cfg.set_value("flags", "tutorial_done", done)
	_flush()


func reset_progress() -> void:
	if _cfg.has_section("levels"):
		_cfg.erase_section("levels")
	set_tutorial_done(false)


func _flush() -> void:
	var err := _cfg.save(PATH)
	if err != OK:
		push_warning("Could not write save: %s" % error_string(err))
