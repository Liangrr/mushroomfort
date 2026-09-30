extends Node
## Build metadata shown in-game and embedded into the Web export.
const PATH := "res://data/version.json"
var info: Dictionary = {
	"version": "0.1.0",
	"commit": "development",
	"build": "local",
	"branch": "main",
	"built_at": "",
	"built_at_bj": "",
	"channel": "web",
}
func _ready() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key: String in info:
			if parsed.has(key):
				info[key] = str(parsed[key])
func short() -> String:
	return "v%s" % str(info.get("version", "0.1.0"))
func commit() -> String:
	return str(info.get("commit", "development"))
func build() -> String:
	return str(info.get("build", "local"))
func display() -> String:
	return "%s · %s · %s" % [short(), str(info.get("channel", "web")).to_upper(), commit()]
func details() -> String:
	var built_at := str(info.get("built_at_bj", ""))
	if built_at.is_empty():
		built_at = str(info.get("built_at", ""))
	return "%s\nBuild %s · 北京时间 %s" % [display(), build(), built_at]
